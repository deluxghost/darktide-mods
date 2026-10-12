local mod = get_mod("Mechanization")
local RiderPose = mod.load_module("players/rider_pose")
local IntroSettings = require("scripts/ui/views/mission_intro_view/mission_intro_view_settings")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local PlayerUnitAnimationState = require("scripts/extension_systems/animation/utilities/player_unit_animation_state")
local Seated = {}

Seated.start = function (occupant)
	local unit = occupant.unit
	local data = ScriptUnit.extension(unit, "unit_data_system")
	local weapon = assert(WeaponTemplate.current_weapon_template(data:read_component("weapon_action")), "Missing occupant weapon template")
	occupant.animation_machine = WeaponTemplate.state_machines(weapon, data:breed_name())
	if occupant.seat.pose then
		occupant.rider_pose = RiderPose.create(unit, occupant.seat.pose, data:breed().base_unit)
		return
	end
	local archetype = occupant.player:profile().archetype
	local animation = occupant.seat.animation or assert(IntroSettings.animations_per_archetype[archetype.name], "Missing seated animation")[1]
	Unit.set_animation_state_machine(unit, archetype.mission_intro_state_machine)
	Unit.animation_event(unit, animation)
end

Seated.stop = function (occupant)
	local unit = occupant.unit
	if not ALIVE[unit] then
		return
	end
	if occupant.rider_pose then
		RiderPose.restore(unit, occupant.rider_pose)
		occupant.rider_pose = nil
	end
	Unit.set_animation_state_machine(unit, occupant.animation_machine)
	local animation = ScriptUnit.extension(unit, "animation_system")
	local first = ScriptUnit.extension(unit, "first_person_system")
	PlayerUnitAnimationState.cache_anim_variable_ids(
		unit,
		first:first_person_unit(),
		animation._anim_variable_ids_third_person,
		animation._anim_variable_ids_first_person
	)
	ScriptUnit.extension(unit, "aim_system"):state_machine_changed(unit)
	if first.__class_name == "PlayerUnitFirstPersonExtension" then
		local component = ScriptUnit.extension(unit, "unit_data_system"):write_component("first_person")
		component.wanted_height = first:default_height("default")
		component.height_change_duration = 0
	end
end

Seated.install = function (session)
	-- Gameplay keeps driving the first-person weapon. Only its third-person
	-- animation writes are suppressed while the actual player skeleton is seated.
	for _, class_name in ipairs({ "PlayerUnitAnimationExtension", "AuthoritativePlayerUnitAnimationExtension" }) do
		for _, method in ipairs({
			"anim_event",
			"anim_event_with_variable_float",
			"anim_event_with_variable_floats",
			"anim_event_with_variable_int",
		}) do
			mod:hook(class_name, method, function (func, self, ...)
				if not session.for_unit(self._unit) then
					return func(self, ...)
				end
			end)
		end
	end
	for _, method in ipairs({
		"animation_event_by_index",
		"animation_set_variable",
		"animation_set_constraint_target",
		"animation_set_state",
		"animation_set_time",
		"animation_set_animation",
	}) do
		mod:hook(Unit, method, function (func, unit, ...)
			if not session.for_unit(unit) then
				return func(unit, ...)
			end
		end)
	end
	mod:hook(Unit, "set_animation_state_machine_blend_base_layer", function (func, unit, machine, ...)
		local _, occupant = session.for_unit(unit)
		if occupant then
			occupant.animation_machine = machine
			return
		end
		return func(unit, machine, ...)
	end)
	for _, class_name in ipairs({ "PlayerUnitAimExtension", "PlayerHuskAimExtension" }) do
		mod:hook(class_name, "state_machine_changed", function (func, self, unit, ...)
			-- The intro skeleton has no gameplay aim constraints. Restore them on exit.
			if not session.for_unit(unit) then
				return func(self, unit, ...)
			end
		end)
	end
	mod:hook(CLASS.PlayerUnitLocomotionExtension, "update", function (func, self, unit, ...)
		-- Vehicle posing replaces locomotion interpolation and its gameplay animation reads.
		if not session.for_unit(unit) then
			return func(self, unit, ...)
		end
	end)
	mod:hook(CLASS.PlayerUnitFirstPersonExtension, "fixed_update", function (func, self, unit, ...)
		local _, occupant = session.for_unit(unit)
		if occupant then
			local head = Unit.world_position(unit, Unit.node(unit, "j_head"))
			local height = head.z - Unit.world_position(unit, 1).z
			self._first_person_component.wanted_height = height
			self._first_person_component.height_change_duration = 0
		end
		return func(self, unit, ...)
	end)
	mod:hook(CLASS.PlayerUnitFirstPersonExtension, "_update_first_person_mode", function (func, self, t)
		local _, occupant = session.for_unit(self._unit)
		if occupant and not session.personal_weapons(occupant) then
			return false, false
		end
		return func(self, t)
	end)
end

return Seated
