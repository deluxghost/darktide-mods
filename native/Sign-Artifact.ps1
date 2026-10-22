param(
    [Parameter(Mandatory)]
    [string] $Path,
    [string] $SigningConfig,
    [ValidateSet('Local', 'AzureCli')]
    [string] $SigningAuthentication = 'Local'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$Path = (Resolve-Path -LiteralPath $Path).Path
if ([System.IO.Path]::GetExtension($Path) -notin @('.dll', '.exe')) {
    throw "Only DLL and EXE build outputs can be signed: $Path"
}

if ([string]::IsNullOrWhiteSpace($SigningConfig)) {
    $SigningConfig = 'D:\ShareApps\etc\TrustedSigning\metadata.json'
}
$SigningConfig = (Resolve-Path -LiteralPath $SigningConfig).Path
$metadata = Get-Content -LiteralPath $SigningConfig -Raw | ConvertFrom-Json -AsHashtable
foreach ($name in @('Endpoint', 'CodeSigningAccountName', 'CertificateProfileName')) {
    if ([string]::IsNullOrWhiteSpace($metadata[$name])) {
        throw "Required signing configuration is missing: $name"
    }
}

Import-Module ArtifactSigning -RequiredVersion 0.1.20 -ErrorAction Stop
$arguments = @{
    Endpoint = $metadata.Endpoint
    CodeSigningAccountName = $metadata.CodeSigningAccountName
    CertificateProfileName = $metadata.CertificateProfileName
    Files = $Path
    FileDigest = 'SHA256'
    TimestampRfc3161 = 'http://timestamp.acs.microsoft.com'
    TimestampDigest = 'SHA256'
    ExcludeEnvironmentCredential = $SigningAuthentication -ne 'Local'
    ExcludeWorkloadIdentityCredential = $true
    ExcludeManagedIdentityCredential = $true
    ExcludeSharedTokenCacheCredential = $true
    ExcludeVisualStudioCredential = $true
    ExcludeVisualStudioCodeCredential = $true
    ExcludeAzureCliCredential = $SigningAuthentication -ne 'AzureCli'
    ExcludeAzurePowerShellCredential = $true
    ExcludeAzureDeveloperCliCredential = $true
    ExcludeInteractiveBrowserCredential = $true
}
$previousEnvironment = @{}
try {
    if ($SigningAuthentication -eq 'Local') {
        $credentialPath = Join-Path (Split-Path -Parent $SigningConfig) 'credentials.clixml'
        $credential = Import-Clixml -LiteralPath $credentialPath
        if ([string]::IsNullOrWhiteSpace($credential.TenantId) -or
            [string]::IsNullOrWhiteSpace($credential.ClientId) -or
            $credential.ClientSecret -isnot [System.Security.SecureString]) {
            throw "Local signing credentials are invalid: $credentialPath"
        }
        $signingEnvironment = @{
            AZURE_TENANT_ID = $credential.TenantId
            AZURE_CLIENT_ID = $credential.ClientId
            AZURE_CLIENT_SECRET = [System.Net.NetworkCredential]::new('', $credential.ClientSecret).Password
        }
        foreach ($name in $signingEnvironment.Keys) {
            $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $signingEnvironment[$name], 'Process')
        }
    }
    Invoke-ArtifactSigning @arguments
}
finally {
    foreach ($name in $previousEnvironment.Keys) {
        $previousValue = $previousEnvironment[$name]
        if ($null -eq $previousValue) {
            $previousValue = [NullString]::Value
        }
        [Environment]::SetEnvironmentVariable($name, $previousValue, 'Process')
    }
}

$signature = Get-AuthenticodeSignature -LiteralPath $Path
if ($signature.Status -ne 'Valid' -or $null -eq $signature.TimeStamperCertificate) {
    throw "Build output does not have a valid timestamped signature: $Path ($($signature.Status))"
}
Write-Host "Signed: $Path"
