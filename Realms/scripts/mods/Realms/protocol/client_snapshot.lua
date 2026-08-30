local mod = get_mod("Realms")
local ProfileSection = mod:io_dofile("Realms/scripts/mods/Realms/protocol/snapshot/profile")
local StatsSection = mod:io_dofile("Realms/scripts/mods/Realms/protocol/snapshot/stats")

local ClientSnapshot = {}

local SCHEMA_VERSION = 1
local MAX_ID_LENGTH = 128
local MAX_SNAPSHOT_SIZE = 98304
local ROOT_FIELDS = {
	identity = true,
	schemaVersion = true,
	sections = true,
}
local IDENTITY_FIELDS = {
	accountId = true,
	characterId = true,
	localPlayerId = true,
}
local SECTION_ORDER = {
	"profile",
	"stats",
}
local SECTION_SPECS = {
	profile = {
		module = ProfileSection,
		required = true,
	},
	stats = {
		module = StatsSection,
		required = true,
	},
}

local function has_only_fields(value, allowed_fields)
	for field in pairs(value) do
		if not allowed_fields[field] then
			return false
		end
	end

	return true
end

local function valid_id(value)
	return type(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH
end

local function validate_encoded_size(section_name, value, section_module)
	if #cjson.encode(value) > section_module.max_encoded_size then
		return false, section_name .. " snapshot section exceeds the protocol limit"
	end

	return true
end

local function capture_sections(context)
	local sections = {}

	for i = 1, #SECTION_ORDER do
		local section_name = SECTION_ORDER[i]
		local section_module = SECTION_SPECS[section_name].module
		local value, capture_error = section_module.capture(context)

		if value == nil then
			return nil, capture_error or section_name .. " snapshot capture failed"
		end

		local valid_size, size_error = validate_encoded_size(section_name, value, section_module)

		if not valid_size then
			return nil, size_error
		end

		sections[section_name] = value
	end

	return sections
end

function ClientSnapshot.capture()
	local sync_data = Managers.player:create_sync_data(Network.peer_id(), true)
	local local_player_ids = sync_data.local_player_id_array

	if not local_player_ids
		or #local_player_ids ~= 1
		or #sync_data.is_human_controlled_array ~= 1
		or #sync_data.account_id_array ~= 1
		or #sync_data.character_id_array ~= 1
		or #sync_data.profile_chunks_array ~= 1
		or not sync_data.is_human_controlled_array[1]
	then
		return nil, "Realms requires exactly one valid local client player"
	end

	local local_player_id = local_player_ids[1]
	local sections, sections_error = capture_sections({
		local_player_id = local_player_id,
		sync_data = sync_data,
	})

	if not sections then
		return nil, sections_error
	end

	local snapshot = {
		identity = {
			accountId = sync_data.account_id_array[1],
			characterId = sync_data.character_id_array[1],
			localPlayerId = local_player_id,
		},
		schemaVersion = SCHEMA_VERSION,
		sections = sections,
	}

	if #cjson.encode(snapshot) > MAX_SNAPSHOT_SIZE then
		return nil, "Official local player data exceeds the Realms snapshot limit"
	end

	return snapshot
end

local function validate_sections(sections, identity)
	if type(sections) ~= "table" then
		return nil, "Snapshot sections are invalid"
	end

	for section_name in pairs(sections) do
		if not SECTION_SPECS[section_name] then
			return nil, "Snapshot contains an unsupported section"
		end
	end

	local normalized = {}

	for i = 1, #SECTION_ORDER do
		local section_name = SECTION_ORDER[i]
		local spec = SECTION_SPECS[section_name]
		local section_module = spec.module
		local value = sections[section_name]

		if value == nil then
			if spec.required then
				return nil, "Snapshot is missing the " .. section_name .. " section"
			end
		else
			local valid_size, size_error = validate_encoded_size(section_name, value, section_module)

			if not valid_size then
				return nil, size_error
			end

			local section_data, validation_error = section_module.validate(value, identity)

			if not section_data then
				return nil, validation_error or section_name .. " snapshot validation failed"
			end

			for field, field_value in pairs(section_data) do
				if normalized[field] ~= nil then
					return nil, "Snapshot sections produced a duplicate field"
				end

				normalized[field] = field_value
			end
		end
	end

	return normalized
end

function ClientSnapshot.validate(snapshot, expected_identity)
	if type(snapshot) ~= "table"
		or not has_only_fields(snapshot, ROOT_FIELDS)
		or snapshot.schemaVersion ~= SCHEMA_VERSION
		or type(snapshot.identity) ~= "table"
		or not has_only_fields(snapshot.identity, IDENTITY_FIELDS)
	then
		return nil, "Snapshot envelope is invalid"
	end

	local identity = snapshot.identity

	if not valid_id(identity.accountId)
		or not valid_id(identity.characterId)
		or type(identity.localPlayerId) ~= "number"
		or identity.localPlayerId % 1 ~= 0
		or identity.localPlayerId < 1
		or identity.accountId ~= expected_identity.account_id
		or identity.characterId ~= expected_identity.character_id
		or identity.localPlayerId ~= expected_identity.local_player_id
	then
		return nil, "Snapshot identity does not match the connection"
	end

	return validate_sections(snapshot.sections, identity)
end

function ClientSnapshot.install_stats(snapshot, stat_id, channel_id, local_player_id)
	return StatsSection.install(snapshot, stat_id, channel_id, local_player_id)
end

return ClientSnapshot
