local ProfileUtils = require("scripts/utilities/profile_utils")

local ProfileSection = {}

local FORMAT = "packed_profile_v1"
local MAX_CHUNKS = 256
local MAX_CHUNK_SIZE = 400
local MAX_PROFILE_SIZE = 65536
local FIELDS = {
	chunks = true,
	format = true,
}

local function has_only_fields(value)
	for field in pairs(value) do
		if not FIELDS[field] then
			return false
		end
	end

	return true
end

function ProfileSection.capture(context)
	local chunks = context.sync_data.profile_chunks_array[1]

	if type(chunks) ~= "table" or #chunks == 0 then
		return nil, "Official local player profile is unavailable"
	end

	return {
		chunks = chunks,
		format = FORMAT,
	}
end

function ProfileSection.validate(value, identity)
	if type(value) ~= "table" or not has_only_fields(value) or value.format ~= FORMAT then
		return nil, "Profile snapshot envelope is invalid"
	end

	local chunks = value.chunks

	if type(chunks) ~= "table" or #chunks == 0 or #chunks > MAX_CHUNKS then
		return nil, "Profile snapshot chunk count is invalid"
	end

	local total_size = 0

	for i = 1, #chunks do
		local chunk = chunks[i]

		if type(chunk) ~= "string" or #chunk == 0 or #chunk > MAX_CHUNK_SIZE then
			return nil, "Profile snapshot chunk is invalid"
		end

		total_size = total_size + #chunk
	end

	if total_size > MAX_PROFILE_SIZE then
		return nil, "Profile snapshot exceeds the protocol limit"
	end

	local decoded, profile = pcall(ProfileUtils.unpack_profile, ProfileUtils.combine_network_chunks(chunks))

	if not decoded or type(profile) ~= "table" or profile.character_id ~= identity.characterId then
		return nil, "Profile snapshot does not match the connection identity"
	end

	return {
		profile_chunks = table.clone(chunks),
	}
end

ProfileSection.max_encoded_size = 70000

return ProfileSection
