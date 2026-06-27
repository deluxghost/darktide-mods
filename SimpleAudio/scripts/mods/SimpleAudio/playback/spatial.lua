local mod = get_mod("SimpleAudio")

local context = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/context")

local spatial = {}

local MAX_DISTANCE = 100
local DECAY = 0.01

local function listener_position_rotation()
	local player = Managers.player and Managers.player:local_player_safe(1)

	if not player then
		return Vector3.zero(), Quaternion.identity()
	end

	local listener_pose = Managers.state.camera:listener_pose(player.viewport_name)
	local listener_position = listener_pose and Matrix4x4.translation(listener_pose) or Vector3.zero()
	local listener_rotation = listener_pose and Matrix4x4.rotation(listener_pose) or Quaternion.identity()

	return listener_position, listener_rotation
end

spatial.mix = function(unit_or_position, decay, min_distance, max_distance, override_position, override_rotation)
	if not Managers.ui or Managers.ui:get_current_sub_state_name() ~= "GameplayStateRun" then
		return 100
	end

	local input_type = context.userdata_type(unit_or_position)

	if input_type ~= "Unit" and input_type ~= "Vector3" then
		return 100
	end

	local position = input_type == "Unit" and Unit.local_position(unit_or_position, 1) or unit_or_position
	local current_listener_position, current_listener_rotation

	if not override_position or not override_rotation then
		current_listener_position, current_listener_rotation = listener_position_rotation()
	end

	local listener_position = override_position or current_listener_position
	local listener_rotation = override_rotation or current_listener_rotation
	decay = decay or DECAY
	min_distance = min_distance or 0
	max_distance = max_distance or MAX_DISTANCE

	local distance = Vector3.distance(position, listener_position)
	local volume

	if distance < min_distance then
		volume = 100
	elseif distance > max_distance then
		volume = 0
	else
		local ratio = 1 - math.clamp((distance - min_distance) / (max_distance - min_distance), 0, 1)

		volume = math.clamp(100 * (ratio - (distance - min_distance) * decay), 0, 100)
	end

	local direction = position - listener_position
	local local_direction = Quaternion.rotate(Quaternion.inverse(listener_rotation), direction)
	local source_position = Vector3(
		Vector3.x(local_direction),
		Vector3.z(local_direction),
		Vector3.y(local_direction)
	)

	return volume, {
		listener_front_x = 0,
		listener_front_y = 0,
		listener_front_z = 1,
		listener_top_x = 0,
		listener_top_y = 1,
		listener_top_z = 0,
		listener_x = 0,
		listener_y = 0,
		listener_z = 0,
		source_x = Vector3.x(source_position),
		source_y = Vector3.y(source_position),
		source_z = Vector3.z(source_position),
	}
end

return spatial
