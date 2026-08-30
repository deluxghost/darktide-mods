local StatsSection = {}

local FORMAT = "persistent_stats_v1"
local MAX_STATS = 2048
local FIELDS = {
	format = true,
	values = true,
	version = true,
}

local function has_only_fields(value)
	for field in pairs(value) do
		if not FIELDS[field] then
			return false
		end
	end

	return true
end

local function valid_number(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

function StatsSection.capture(context)
	local stats_manager = Managers.stats
	local stats_user = stats_manager._users[context.local_player_id]

	if not stats_user or stats_manager:user_state(context.local_player_id) ~= stats_manager.user_states.idle then
		return nil, "Official local player stats are unavailable"
	end

	local values = {}
	local count = 0

	for stat_name, definition in pairs(stats_manager._definitions) do
		if definition.flags.backend then
			local value = rawget(stats_user.data, stat_name)

			if value ~= nil then
				if not valid_number(value) then
					return nil, "Official local player stats contain a non-numeric value"
				end

				count = count + 1

				if count > MAX_STATS then
					return nil, "Official local player stats exceed the Realms limit"
				end

				values[stat_name] = value
			end
		end
	end

	return {
		format = FORMAT,
		values = values,
		version = stats_manager:user_version(context.local_player_id),
	}
end

function StatsSection.validate(value)
	if type(value) ~= "table"
		or not has_only_fields(value)
		or value.format ~= FORMAT
		or type(value.values) ~= "table"
		or type(value.version) ~= "number"
		or value.version % 1 ~= 0
		or value.version < 0
		or value.version >= 32768
	then
		return nil, "Stats snapshot envelope is invalid"
	end

	local values = {}
	local count = 0

	for stat_name, stat_value in pairs(value.values) do
		local definition = Managers.stats._definitions[stat_name]

		if type(stat_name) ~= "string"
			or not definition
			or not definition.flags.backend
			or not valid_number(stat_value)
		then
			return nil, "Stats snapshot contains an unsupported field"
		end

		count = count + 1

		if count > MAX_STATS then
			return nil, "Stats snapshot exceeds the Realms limit"
		end

		values[stat_name] = stat_value
	end

	return {
		stats_values = values,
		stats_version = value.version,
	}
end

function StatsSection.install(snapshot, stat_id, channel_id, local_player_id)
	Managers.stats:add_user(stat_id, nil, channel_id, local_player_id)

	local stats_user = Managers.stats._users[stat_id]

	if not stats_user then
		return false, "StatsManager did not create the Realms remote user"
	end

	for stat_name, value in pairs(snapshot.stats_values) do
		stats_user.data[stat_name] = value
	end

	if Managers.stats:user_version(stat_id) ~= snapshot.stats_version then
		return false, "Remote stats version does not match the submitted snapshot"
	end

	return true
end

StatsSection.max_encoded_size = 50000

return StatsSection
