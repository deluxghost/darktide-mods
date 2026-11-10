-- Shared formatting for /realms_status lines.
local StatusFormat = {}

function StatusFormat.bytes(value)
	if value >= 1048576 then
		return string.format("%.1fMB", value / 1048576)
	end
	if value >= 1024 then
		return string.format("%.1fKB", value / 1024)
	end

	return string.format("%dB", value)
end

return StatusFormat
