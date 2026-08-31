local mod = get_mod("Realms")
local ProfileUtils = require("scripts/utilities/profile_utils")
local ProfileSection = mod:io_dofile("Realms/scripts/mods/Realms/protocol/snapshot/profile")

local ProfileUpdate = {}

local MAX_ID_LENGTH = 128
local MAX_SEQUENCE = 2147483647
local DATA_FIELDS = {
	identity = true,
	profile = true,
	sequence = true,
}
local IDENTITY_FIELDS = {
	account_id = true,
	character_id = true,
	local_player_id = true,
}

local function has_only_fields(value, fields)
	for field in pairs(value) do
		if not fields[field] then
			return false
		end
	end

	return true
end

local function valid_id(value)
	return type(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH
end

local function valid_sequence(value)
	return type(value) == "number" and value % 1 == 0 and value >= 1 and value <= MAX_SEQUENCE
end

local function valid_identity(identity)
	return type(identity) == "table"
		and has_only_fields(identity, IDENTITY_FIELDS)
		and valid_id(identity.account_id)
		and valid_id(identity.character_id)
		and type(identity.local_player_id) == "number"
		and identity.local_player_id % 1 == 0
		and identity.local_player_id >= 1
end

function ProfileUpdate.valid_pending_data(data)
	return type(data) == "table"
		and table.size(data) == 2
		and valid_sequence(data.sequence)
		and type(data.local_player_id) == "number"
		and data.local_player_id % 1 == 0
		and data.local_player_id >= 1
end

function ProfileUpdate.valid_update_data(data)
	return type(data) == "table"
		and table.size(data) == 3
		and has_only_fields(data, DATA_FIELDS)
		and valid_sequence(data.sequence)
		and valid_identity(data.identity)
		and type(data.profile) == "table"
end

function ProfileUpdate.create(sequence, player, backend_profile_data)
	if not valid_sequence(sequence) or not player then
		return nil, nil, "Local profile update identity is unavailable"
	end

	backend_profile_data = ProfileUtils.process_backend_body(backend_profile_data)

	local profile = ProfileUtils.backend_profile_data_to_profile(backend_profile_data)
	local profile_section = ProfileSection.capture_profile(profile)
	local data = {
		identity = {
			account_id = player:account_id(),
			character_id = player:character_id(),
			local_player_id = player:local_player_id(),
		},
		profile = profile_section,
		sequence = sequence,
	}

	if not ProfileUpdate.valid_update_data(data) then
		return nil, nil, "Local profile update is invalid"
	end

	local validated_profile, validation_error = ProfileSection.validate(profile_section, {
		characterId = data.identity.character_id,
	})

	if not validated_profile then
		return nil, nil, validation_error
	end

	return data, profile
end

function ProfileUpdate.validate(data, expected_identity)
	if not ProfileUpdate.valid_update_data(data) then
		return nil, "Profile update envelope is invalid"
	end

	local identity = data.identity

	if identity.account_id ~= expected_identity.account_id
		or identity.character_id ~= expected_identity.character_id
		or identity.local_player_id ~= expected_identity.local_player_id
	then
		return nil, "Profile update identity does not match the connection"
	end

	local section, section_error = ProfileSection.validate(data.profile, {
		characterId = identity.character_id,
	})

	if not section then
		return nil, section_error
	end

	local decoded, profile = pcall(
		ProfileUtils.unpack_profile,
		ProfileUtils.combine_network_chunks(section.profile_chunks)
	)

	if not decoded or type(profile) ~= "table" then
		return nil, "Profile update data could not be decoded"
	end

	return {
		local_player_id = identity.local_player_id,
		profile = profile,
		profile_chunks = section.profile_chunks,
		sequence = data.sequence,
	}
end

return ProfileUpdate
