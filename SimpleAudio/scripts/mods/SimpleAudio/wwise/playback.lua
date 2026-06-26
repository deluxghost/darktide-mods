local mod = get_mod("SimpleAudio")

local context = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/context")

local playback = {}

local function current_wwise_world()
	local world = Managers.ui:world()

	return Managers.world:wwise_world(world)
end

local function trigger_resource_event(wwise_world, sound_name, unit_or_position_or_id, node_or_rotation_or_boolean)
	if unit_or_position_or_id == nil then
		return wwise_world:trigger_resource_event(sound_name)
	end

	local value_type = context.userdata_type(unit_or_position_or_id) or type(unit_or_position_or_id)

	if value_type == "number" then
		return wwise_world:trigger_resource_event(sound_name, unit_or_position_or_id)
	end

	if value_type == "boolean" or value_type == "Unit" or value_type == "Vector3" then
		if node_or_rotation_or_boolean == nil then
			return wwise_world:trigger_resource_event(sound_name, unit_or_position_or_id)
		end

		return wwise_world:trigger_resource_event(sound_name, unit_or_position_or_id, node_or_rotation_or_boolean)
	end

	error(string.format("Unsupported Wwise sound target: %s", tostring(value_type)))
end

local function source_id(wwise_world, unit_or_position_or_id, node_or_rotation_or_boolean)
	if not unit_or_position_or_id then
		local player_unit = Managers.player:local_player_safe(1).player_unit

		return wwise_world:make_auto_source(player_unit, node_or_rotation_or_boolean)
	end

	if type(unit_or_position_or_id) == "number" then
		return unit_or_position_or_id
	end

	if type(unit_or_position_or_id) ~= "userdata" then
		return nil
	end

	local value_type = context.userdata_type(unit_or_position_or_id)

	if value_type == "Unit" then
		return wwise_world:make_auto_source(unit_or_position_or_id, node_or_rotation_or_boolean)
	elseif value_type == "Vector3" then
		return wwise_world:make_manual_source(unit_or_position_or_id, node_or_rotation_or_boolean)
	end
end

local function external_event_name(sound_name)
	if string.starts_with(sound_name, "wwise/externals/") then
		return sound_name
	elseif string.starts_with(sound_name, "loc_") then
		return "wwise/externals/" .. sound_name
	end
end

playback.play = function(sound_name, unit_or_position_or_id, node_or_rotation_or_boolean)
	if type(sound_name) ~= "string" then
		error(string.format("Wwise sound name must be a string, got %s", type(sound_name)))
	end

	local wwise_world = current_wwise_world()

	if string.starts_with(sound_name, "wwise/events") then
		return trigger_resource_event(wwise_world, sound_name, unit_or_position_or_id, node_or_rotation_or_boolean)
	end

	local external_event = external_event_name(sound_name)

	if external_event then
		return wwise_world:trigger_resource_external_event(
			"wwise/events/vo/play_sfx_es_player_vo",
			"es_vo_prio_1",
			external_event,
			4,
			source_id(wwise_world, unit_or_position_or_id, node_or_rotation_or_boolean)
		)
	end

	error(string.format("Unsupported Wwise sound name: %s", sound_name))
end

return playback
