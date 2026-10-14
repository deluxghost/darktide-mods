local mod = get_mod("Mechanization")
local modules = {}

mod.load_module = function (path)
	if not modules[path] then
		modules[path] = assert(mod:io_dofile("Mechanization/scripts/mods/Mechanization/" .. path), "Missing module: " .. path)
	end
	return modules[path]
end

local Session = mod.load_module("session")
local ScriptCamera = require("scripts/foundation/utilities/script_camera")
local View = mod.load_module("camera")
local RiderPose = mod.load_module("players/rider_pose")
mod.session = Session
mod.load_module("ui/crosshair").install(Session)
mod.load_module("physics/minions").install(Session)
mod.load_module("players/protection").install(Session)
mod.load_module("players/movement").install(Session)

mod:command("mech", mod:localize("command_description"), function (index, extra)
	Session.command(index, extra, true)
end)
mod:register_hud_element({
	class_name = "HudElementVehicleStatus",
	filename = "Mechanization/scripts/mods/Mechanization/ui/HudElementVehicleStatus",
	use_hud_scale = true,
	visibility_groups = { "alive" },
})
mod.on_all_mods_loaded = Session.install
mod:hook_safe(CLASS.PositionLookupManager, "pre_update", function ()
	-- Position lookup also updates during loading, before the gameplay timer exists.
	if Managers.time:has_timer("gameplay") then
		Session.update(Managers.time:delta_time("gameplay"))
	end
end)
mod.on_unload = Session.stop
mod.on_setting_changed = function (id)
	if id == "enabled" then
		Session.settings_changed()
	end
end
mod.on_settings_reset = Session.settings_changed
mod.on_game_state_changed = function (status, state)
	if state == "StateGameplay" and status == "exit" then
		Session.cleanup()
		table.clear(Session.last_departures)
		Session.running = false
		Session.network.host_enabled = false
	end
end

mod:hook(CLASS.PlayerUnitInputExtension, "get", function (func, self, action)
	local unit = self._player.player_unit
	local interaction_input = action == "interact_pressed" or action == "interact_hold"
	if interaction_input and Session.interaction.blocks_input(unit) then
		return false
	end
	local _, occupant = Session.for_unit(unit)
	if not occupant then
		if Session.boarding.vehicle and (action == "interact_pressed" or action == "interact_hold") then
			return false
		end
		return func(self, action)
	end
	if action == "move" then
		return occupant.platform and func(self, action) or Vector3.zero()
	end
	if action == "look" or action == "look_raw" then
		return func(self, action)
	end
	if Session.personal_weapons(occupant) and not interaction_input then
		local movement = action == "jump" or action == "dodge" or action == "crouch" or action == "sprint"
		if occupant.platform or not movement then
			return func(self, action)
		end
	end
	return false
end)

mod:hook(CLASS.DefaultPlayerOrientation, "pre_update", function (func, self, main_t, main_dt, input, sensitivity, constraints)
	local vehicle, occupant = Session.for_unit(self._player.player_unit)
	if not vehicle or Session.personal_weapons(occupant) then
		return func(self, main_t, main_dt, input, sensitivity, constraints)
	end
	local min_pitch, max_pitch = self._min_pitch, self._max_pitch
	local camera = vehicle.type.camera
	self._min_pitch, self._max_pitch = camera.min_pitch, camera.max_pitch
	if occupant.seat.movement and camera.look_sensitivity then
		sensitivity = sensitivity * camera.look_sensitivity
	end
	func(self, main_t, main_dt, input, sensitivity, constraints)
	self._min_pitch, self._max_pitch = min_pitch, max_pitch
	local orientation = self._orientation
	local pitch = (orientation.pitch + math.pi) % (math.pi * 2) - math.pi
	orientation.pitch = math.clamp(pitch, camera.min_pitch, camera.max_pitch) % (math.pi * 2)
end)

local function camera_pose (v, occupant)
	if occupant.peer ~= Session.network.local_peer() then
		local first = ScriptUnit.extension(occupant.unit, "first_person_system")
		local yaw, pitch = Quaternion.to_yaw_pitch_roll(first:spectated_aim_rotation())
		return View.pose(v, yaw, pitch)
	end
	local orientation = occupant.player:get_orientation()
	local pitch = (orientation.pitch + math.pi) % (math.pi * 2) - math.pi
	return View.pose(v, orientation.yaw, pitch)
end

mod.camera_pose = camera_pose

mod:hook(CLASS.CameraManager, "_update_camera_properties", function (func, self, camera, shadow_camera, nodes, data, viewport)
	local v, occupant = Session.for_unit(self:_current_node(nodes):root_unit())
	if not v or Session.personal_weapons(occupant) then
		return func(self, camera, shadow_camera, nodes, data, viewport)
	end
	local position, rotation = camera_pose(v, occupant)
	data.position, data.rotation = position, rotation
	data.vertical_fov = v.type.camera.vertical_fov
	func(self, camera, shadow_camera, nodes, data, viewport)
	ScriptCamera.set_local_position(camera, position)
	ScriptCamera.set_local_rotation(camera, rotation)
end)

local function collect (unit, result)
	result[#result + 1] = unit
	for _, child in pairs(Unit.get_child_units(unit) or {}) do
		collect(child, result)
	end
end

mod:hook(Application, "render_world", function (func, world, ...)
	local hidden = {}
	for _, v in pairs(Session.vehicles) do
		if v.world == world then
			v.type.controller.pose(v)
			for _, occupant in pairs(v.occupants) do
				if ALIVE[occupant.unit] then
					RiderPose.apply(v, occupant)
					local personal_weapons = Session.personal_weapons(occupant)
					if not occupant.seat.visible or personal_weapons and occupant.peer == Session.network.local_peer() then
						collect(occupant.unit, hidden)
					end
					if not personal_weapons then
						local first = ScriptUnit.extension(occupant.unit, "first_person_system")
						local first_unit = first:first_person_unit()
						if first_unit and Unit.alive(first_unit) then
							collect(first_unit, hidden)
						end
						if occupant.seat.visible then
							local loadout = ScriptUnit.extension(occupant.unit, "visual_loadout_system")
							local inventory = ScriptUnit.extension(occupant.unit, "unit_data_system"):read_component("inventory")
							local held = loadout:unit_3p_from_slot(inventory.wielded_slot)
							if held then
								collect(held, hidden)
							end
						end
					end
				end
			end
		end
	end
	if #hidden == 0 then
		return func(world, ...)
	end
	Unit.take_visibility_snapshot(hidden)
	for _, unit in ipairs(hidden) do
		Unit.set_unit_visibility(unit, false)
	end
	func(world, ...)
	Unit.restore_visibility_snapshot(hidden)
end)
