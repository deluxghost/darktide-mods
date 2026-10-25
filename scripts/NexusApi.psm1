Set-StrictMode -Version Latest

function New-NexusClient {
    param([Parameter(Mandatory)][securestring] $ApiKey)

    return @{
        apikey = [System.Net.NetworkCredential]::new('', $ApiKey).Password
        'User-Agent' = 'deluxghost/darktide-mods'
        Accept = 'application/json'
    }
}

function Get-NexusRetryDelay {
    param($Headers, [int] $Attempt)

    $reset = $Headers['Retry-After'] | Select-Object -First 1
    if ($reset) {
        $seconds = 0
        if ([int]::TryParse($reset, [ref] $seconds)) {
            return [Math]::Max(1, $seconds)
        }
    } else {
        # After the daily allowance, v1 still permits the hourly allowance.
        foreach ($period in @('Hourly', 'Daily')) {
            $remaining = $Headers["X-RL-$period-Remaining"] | Select-Object -First 1
            $resetAt = $Headers["X-RL-$period-Reset"] | Select-Object -First 1
            if ($null -eq $remaining) {
                continue
            }
            if ([long] $remaining -le 0 -and $resetAt) {
                $reset = $resetAt
            }
            break
        }
    }
    if (-not $reset) {
        return [Math]::Pow(2, $Attempt + 1)
    }
    $resetTime = [DateTimeOffset]::Parse($reset, [Globalization.CultureInfo]::InvariantCulture)
    return [Math]::Max(1, [Math]::Ceiling(($resetTime - [DateTimeOffset]::UtcNow).TotalSeconds))
}

function Invoke-NexusApi {
    param(
        [hashtable] $Client,
        [ValidateSet('GET', 'POST')][string] $Method,
        [string] $Path,
        [hashtable] $Body,
        [ValidateSet('v1', 'v3')][string] $Version = 'v3'
    )

    $maximumAttempts = 5
    for ($attempt = 0; $attempt -lt $maximumAttempts; $attempt++) {
        $arguments = @{
            Uri = "https://api.nexusmods.com/$Version$Path"
            Method = $Method
            Headers = $Client
            SkipHttpErrorCheck = $true
            TimeoutSec = 120
            MaximumRedirection = 0
            ErrorAction = 'Stop'
        }
        if ($null -ne $Body) {
            $arguments.ContentType = 'application/json; charset=utf-8'
            $arguments.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10 -Compress))
        }
        try {
            $response = Invoke-WebRequest @arguments
        }
        catch {
            throw "Nexus $Method $Path returned no usable response. The outcome may be unknown; no automatic retry was made."
        }
        if ([int] $response.StatusCode -ne 429) {
            break
        }
        if ($attempt -eq $maximumAttempts - 1) {
            throw "Nexus rate limit persisted after $maximumAttempts attempts: $Method $Path"
        }
        $seconds = Get-NexusRetryDelay $response.Headers $attempt
        Write-Host "Nexus rate limit reached; waiting $seconds seconds."
        Start-Sleep -Seconds $seconds
    }

    $expectedStatus = if ($Method -eq 'GET' -or $Path -like '*/finalise') { 200 } else { 201 }
    if ([int] $response.StatusCode -ne $expectedStatus) {
        $contentType = ($response.Headers['Content-Type'] | Select-Object -First 1)
        if ($contentType -match 'json') {
            $problemText = [Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
            $problem = ConvertFrom-Json -InputObject $problemText -AsHashtable
            throw "Nexus $Method $Path failed with HTTP $([int] $response.StatusCode): $($problem['title']) $($problem['detail']). No automatic write retry was made."
        }
        throw "Nexus $Method $Path failed with HTTP $([int] $response.StatusCode). No automatic write retry was made."
    }
    $text = [Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
    $document = ConvertFrom-Json -InputObject $text -AsHashtable
    if ($Version -eq 'v1') {
        return $document
    }
    if (-not $document.ContainsKey('data')) {
        throw "Nexus $Method $Path returned no data object."
    }
    return $document['data']
}

function Get-NexusStorageError {
    param($Response)

    $contentType = $Response.Headers['Content-Type'] | Select-Object -First 1
    $text = [Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray())
    $fields = [ordered]@{}
    if ($contentType -match 'xml') {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($text), $settings)
        try {
            $document = [Xml.XmlDocument]::new()
            $document.XmlResolver = $null
            $document.Load($reader)
        }
        finally {
            $reader.Dispose()
        }
        foreach ($name in @('Code', 'Message', 'RequestId')) {
            $node = $document.SelectSingleNode("/*[local-name()='Error']/*[local-name()='$name']")
            if ($null -ne $node) {
                $fields[$name] = $node.InnerText
            }
        }
    } elseif ($contentType -match 'json') {
        $problem = ConvertFrom-Json -InputObject $text -AsHashtable
        foreach ($name in @('code', 'message', 'title', 'detail', 'request_id')) {
            if ($problem[$name] -is [string]) {
                $fields[$name] = $problem[$name]
            }
        }
    }
    $details = foreach ($name in $fields.Keys) {
        # Storage errors may echo signed URLs; never log those or signature fields.
        $value = $fields[$name] -replace '(?i)https?://\S+', '[redacted URL]'
        $value = $value -replace '(?i)(X-Amz-(?:Credential|Security-Token|Signature)|AWSAccessKeyId|apikey|Authorization|Signature)\s*[=:]\s*\S+', '$1=[redacted]'
        $value = $value -replace '[\r\n\x00-\x1f]+', ' '
        '{0}={1}' -f $name, $value.Substring(0, [Math]::Min(1000, $value.Length))
    }
    return "ResponseContentType=$contentType; $($details -join '; ')"
}

function Send-NexusStorageRequest {
    param([hashtable] $Arguments)

    $uri = [uri] $Arguments.Uri
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -cne 'https') {
        throw 'Nexus returned an invalid storage URL.'
    }
    $Arguments.SkipHttpErrorCheck = $true
    $Arguments.TimeoutSec = 600
    $Arguments.MaximumRedirection = 0
    try {
        $response = Invoke-WebRequest @Arguments
    }
    catch {
        throw 'Storage upload returned no usable response. No automatic retry was made.'
    }
    if ([int] $response.StatusCode -ne 200) {
        $details = Get-NexusStorageError $response
        $query = [Web.HttpUtility]::ParseQueryString($uri.Query)
        $signedHeaders = $query['X-Amz-SignedHeaders']
        if ($signedHeaders -and $signedHeaders -cnotmatch '^[a-z0-9;-]+$') {
            throw 'Storage returned an invalid signed header list.'
        }
        throw "Storage upload failed with HTTP $([int] $response.StatusCode). Host=$($uri.DnsSafeHost); Method=$($Arguments.Method); ContentType=$($Arguments.ContentType); SignedHeaders=$signedHeaders; $details"
    }
    return $response
}

function Send-NexusMultipartUpload {
    param([hashtable] $Client, [System.IO.FileInfo] $File)

    $upload = Invoke-NexusApi $Client POST '/uploads/multipart' @{
        filename = $File.Name
        size_bytes = $File.Length
    }
    $partSize = [long] $upload.part_size_bytes
    if ($partSize -le 0 -or $partSize -gt [int]::MaxValue) {
        throw 'Nexus returned an unsupported multipart size.'
    }
    $urls = @($upload.part_presigned_urls)
    if ($urls.Count -ne [Math]::Ceiling($File.Length / [double] $partSize)) {
        throw 'Nexus returned an incorrect number of multipart URLs.'
    }
    $parts = [Collections.Generic.List[string]]::new()
    $stream = $File.OpenRead()
    try {
        for ($index = 0; $index -lt $urls.Count; $index++) {
            $length = [int] [Math]::Min($partSize, $File.Length - $stream.Position)
            $buffer = [byte[]]::new($length)
            $stream.ReadExactly($buffer, 0, $length)
            $response = Send-NexusStorageRequest @{
                Uri = $urls[$index]
                Method = 'PUT'
                Body = $buffer
                ContentType = 'application/octet-stream'
            }
            $etag = $response.Headers['ETag'] | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($etag)) {
                throw 'Storage did not return a multipart ETag.'
            }
            $escaped = [Security.SecurityElement]::Escape($etag)
            $parts.Add("<Part><PartNumber>$($index + 1)</PartNumber><ETag>$escaped</ETag></Part>")
        }
    }
    finally {
        $stream.Dispose()
    }
    $completion = Send-NexusStorageRequest @{
        Uri = $upload.complete_presigned_url
        Method = 'POST'
        Body = "<CompleteMultipartUpload>$($parts -join '')</CompleteMultipartUpload>"
        ContentType = 'application/xml'
    }
    $xml = [xml] [Text.Encoding]::UTF8.GetString($completion.RawContentStream.ToArray())
    if ($xml.DocumentElement.LocalName -cne 'CompleteMultipartUploadResult') {
        throw 'Storage did not confirm multipart completion.'
    }
    return $upload.id
}

function Send-NexusUpload {
    param([hashtable] $Client, [string] $Path)

    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    $singlePartLimit = 100MB
    if ($file.Length -gt $singlePartLimit) {
        $uploadId = Send-NexusMultipartUpload $Client $file
    } else {
        $stream = $file.OpenRead()
        try {
            $digest = [Security.Cryptography.MD5]::HashData($stream)
        }
        finally {
            $stream.Dispose()
        }
        $upload = Invoke-NexusApi $Client POST '/uploads' @{
            filename = $file.Name
            size_bytes = $file.Length
            md5 = [Convert]::ToHexString($digest).ToLowerInvariant()
        }
        $null = Send-NexusStorageRequest @{
            Uri = $upload.presigned_url
            Method = 'PUT'
            InFile = $file.FullName
            ContentType = 'application/octet-stream'
            Headers = @{
                'Content-Disposition' = "attachment; filename=`"$($file.Name)`""
                'Content-MD5' = [Convert]::ToBase64String($digest)
            }
        }
        $uploadId = $upload.id
    }
    $uploadId = [uri]::EscapeDataString($uploadId)
    $state = Invoke-NexusApi $Client POST "/uploads/$uploadId/finalise"
    $maximumPolls = 60
    for ($attempt = 0; $attempt -le $maximumPolls; $attempt++) {
        if ($state.state -ceq 'available') {
            return $uploadId
        }
        if ($state.state -cne 'created') {
            throw "Nexus returned an unknown upload state: $($state.state)"
        }
        if ($attempt -eq $maximumPolls) {
            break
        }
        Start-Sleep -Seconds 2
        $state = Invoke-NexusApi $Client GET "/uploads/$uploadId"
    }
    throw "Nexus upload processing did not finish: $uploadId"
}

Export-ModuleMember -Function New-NexusClient, Invoke-NexusApi, Send-NexusUpload
