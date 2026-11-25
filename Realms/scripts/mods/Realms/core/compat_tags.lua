local CompatTags = {}

local MAX_TAG_SIZE = 64
local MAX_KICK_DETAILS_SIZE = 480
local MAX_KICK_DETAILS_TAGS = 12
local MAX_ENCODED_TAG_SIZE = 4 * math.ceil(MAX_TAG_SIZE / 3)
local tags_by_mod = {}

local function valid_tag(tag)
	return type(tag) == "string"
		and #tag > 0
		and #tag <= MAX_TAG_SIZE
		and not string.find(tag, "\n", 1, true)
		and not string.find(tag, "\r", 1, true)
end

function CompatTags.set(owner_mod, tag)
	if type(owner_mod) ~= "table" or type(owner_mod.get_name) ~= "function" then
		return false, "Compatibility tag owner must be a DMF mod"
	end

	local name = owner_mod:get_name()

	if type(name) ~= "string" or name == "" or get_mod(name) ~= owner_mod then
		return false, "Compatibility tag owner must be a DMF mod"
	end
	if tag == nil or tag == "" then
		tags_by_mod[name] = nil

		return true
	end
	if not valid_tag(tag) then
		return false, "Compatibility tag must be a string of at most 64 bytes without line breaks"
	end

	tags_by_mod[name] = tag

	return true
end

function CompatTags.current()
	local seen = {}
	local tags = {}

	for _, tag in pairs(tags_by_mod) do
		if not seen[tag] then
			seen[tag] = true
			tags[#tags + 1] = tag
		end
	end

	table.sort(tags)

	return tags
end

function CompatTags.missing(supported)
	local tags = CompatTags.current()
	local missing = {}

	for i = 1, #tags do
		local tag = tags[i]

		if not supported[tag] then
			missing[#missing + 1] = tag
		end
	end

	return missing
end

function CompatTags.encode(tags)
	local encoded = {}

	for i = 1, #tags do
		encoded[i] = string.encode_base64(tags[i])
	end

	return table.concat(encoded, ".")
end

function CompatTags.decode(encoded)
	if type(encoded) ~= "string" then
		return nil
	end

	local tags = {}

	for part in string.gmatch(encoded, "[^.]+") do
		if #part > MAX_ENCODED_TAG_SIZE then
			return nil
		end

		local tag = string.decode_base64(part)

		if not valid_tag(tag) then
			return nil
		end

		tags[#tags + 1] = tag
	end

	if CompatTags.encode(tags) ~= encoded then
		return nil
	end

	return tags
end

function CompatTags.encode_kick_details(tags)
	local encoded = {}
	local size = #tostring(#tags) + 1

	for i = 1, math.min(#tags, MAX_KICK_DETAILS_TAGS) do
		local part = string.encode_base64(tags[i])

		size = size + #part + (i > 1 and 1 or 0)

		if size > MAX_KICK_DETAILS_SIZE then
			break
		end

		encoded[i] = part
	end

	return tostring(#tags - #encoded) .. ":" .. table.concat(encoded, ".")
end

function CompatTags.decode_kick_details(details)
	if type(details) ~= "string" or #details > MAX_KICK_DETAILS_SIZE then
		return nil
	end

	local omitted, encoded = string.match(details, "^(%d+):(.*)$")
	local tags = CompatTags.decode(encoded)

	if not tags or #tags == 0 or #tags > MAX_KICK_DETAILS_TAGS or #omitted > 9 then
		return nil
	end

	return { tags = tags, omitted = tonumber(omitted) }
end

return CompatTags
