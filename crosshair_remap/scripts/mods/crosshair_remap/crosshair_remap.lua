local mod = get_mod("crosshair_remap")

local Action = require("scripts/utilities/weapon/action")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local slot_configuration = PlayerCharacterConstants.slot_configuration

local function collect_settings()
	for k, _ in pairs(mod.settings) do
		mod.settings[k] = mod:get(k)
	end
end

mod.on_enabled = function()
	collect_settings()
end

mod.on_setting_changed = function()
	collect_settings()
end

local keywords_to_class = {
	autogun = {
		p1 = "autogun_infantry_class",
		p2 = "autogun_braced_class",
		p3 = "autogun_headhunter_class",
	},
	autopistol = "autopistol_class",
	bolter = "boltgun_class",
	flamer = "flamer_class",
	force_staff = {
		p1 = "force_staff_trauma_class",
		p2 = "force_staff_purgatus_class",
		p3 = "force_staff_surge_class",
		p4 = "force_staff_voidstrike_class",
	},
	lasgun = {
		p1 = "lasgun_infantry_class",
		p2 = "lasgun_helbore_class",
		p3 = "lasgun_recon_class",
	},
	laspistol = "laspistol_class",
	plasma_rifle = "plasma_gun_class",
	stub_pistol = "revolver_class",
	shotgun = "shotguns",
	grenadier_gauntlet = "grenadier_gauntlet_class",
	heavystubber = "heavy_stubber_class",
	rippergun = "ripper_gun_class",
	shotgun_grenade = "thumpers_kickback_or_rumbler",
}

local function determine_ranged_weapon_class(weapon_template)
	local function has_keyword(keyword)
		return WeaponTemplate.has_keyword(weapon_template, keyword)
	end

	local weapon_class = nil

	for k, v in pairs(keywords_to_class) do
		if has_keyword(k) then
			if type(v) == "string" then
				weapon_class = v
			else
				for k2, v2 in pairs(v) do
					if has_keyword(k2) then
						weapon_class = v2
						break
					end
				end
			end
			break
		end
	end

	assert(weapon_class)

	if weapon_class == "thumpers_kickback_or_rumbler" then
		if not weapon_template.crosshair then
			return weapon_class
		end
		weapon_class = weapon_template.crosshair.crosshair_type == "shotgun" and "kickback_class" or "rumbler_class"
	elseif weapon_class == "shotguns" then
		if not weapon_template.crosshair then
			return weapon_class
		end
		if weapon_template.crosshair.crosshair_type_special_active == "shotgun_wide" then
			weapon_class = "shotgun_lawbringer_class"
		elseif weapon_template.crosshair.crosshair_type_special_active == "shotgun_slug" then
			weapon_class = "shotgun_agripinaa_class"
		else
			weapon_class = "shotgun_kantrael_class"
		end
	end

	return weapon_class
end

local function retrieve_ranged_weapon_setting(weapon_class, in_alt_fire, in_special)
	local suffix = in_alt_fire and "_secondary" or "_primary"
	if in_special and not in_alt_fire then
		suffix = "_special"
	end
	return mod.settings[weapon_class .. suffix]
end

local function is_in_hub()
	if Managers and Managers.state and Managers.state.game_mode then
		return Managers.state.game_mode:game_mode_name() == "hub"
	end
	return false
end

local melee_action_kinds = {
	windup = true,
	sweep = true,
	push = true,
	melee_explosivve = true,
	block = true, -- No ranged has this action.
}

local reload_action_kinds = {
	reload_state = true,
	reload_shotgun = true,
	ranged_load_special = true,
}

local altfire_action_kinds = {
	aim = true,
	unaim = true,
	overload_charge = true,
	overload_charge_target_finder = true,
	overload_charge_position_finder = true,
	flamer_gas = true,
}

mod:hook_origin("HudElementCrosshair", "_get_current_crosshair_type", function(self)
	if is_in_hub() then
		return "none"
	end

	local crosshair_type = nil
	local parent = self._parent
	local player_extensions = parent:player_extensions()

	if player_extensions then
		local unit_data_extension = player_extensions.unit_data
		local weapon_action_component = unit_data_extension and unit_data_extension:read_component("weapon_action")

		if weapon_action_component then
			local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)

			if weapon_template then
				local current_action_name, action_settings = Action.current_action(weapon_action_component, weapon_template)
				local alternate_fire_component = unit_data_extension:read_component("alternate_fire")
				local alternate_fire_settings = weapon_template.alternate_fire_settings
				local action_kind = current_action_name ~= "none" and action_settings.kind or "no_action"

				if action_kind == "inspect" then
					goto unchanged
				end

				if weapon_template.psyker_smite then
					return mod.settings["psyker_bb_class"]
				end

				if WeaponTemplate.is_melee(weapon_template) then
					return mod.settings["melee_class"]
				end

				if WeaponTemplate.is_ranged(weapon_template) then
					if melee_action_kinds[action_kind] then
						return mod.settings["melee_class"]
					end

					if reload_action_kinds[action_kind] then
						goto unchanged
					end

					local weapon_class = determine_ranged_weapon_class(weapon_template)
					local in_alt_fire = altfire_action_kinds[action_kind] or alternate_fire_component.is_active

					if string.starts_with(weapon_class, "shotgun_") then
						local inventory_comp = unit_data_extension:read_component("inventory")
						local wielded_slot = inventory_comp.wielded_slot
						local slot_type = slot_configuration[wielded_slot].slot_type
						local in_special = false
						if slot_type == "weapon" then
							local inventory_slot_component = unit_data_extension:read_component(wielded_slot)
							in_special = inventory_slot_component.special_active
						end
						return retrieve_ranged_weapon_setting(weapon_class, in_alt_fire, in_special)
					else
						return retrieve_ranged_weapon_setting(weapon_class, in_alt_fire)
					end
				end

				::unchanged::
				if action_settings then
					crosshair_type = action_settings.crosshair_type
				elseif alternate_fire_component.is_active and alternate_fire_settings and alternate_fire_settings.crosshair_type then
					crosshair_type = alternate_fire_settings.crosshair_type
				end

				crosshair_type = crosshair_type or weapon_template.crosshair_type
			end
		end
	end

	crosshair_type = crosshair_type or "none"
	return crosshair_type == "none" and mod.settings["none_class"] or crosshair_type
end)

-- Inject custom crosshairs.
mod:hook_safe("HudElementCrosshair", "init", function(self, ...)
	local scenegraph_id = "pivot"
	for _, name in ipairs(mod.custom_crosshair_names) do
		local template = Mods.file.dofile(mod.custom_dir .. name)
		template.name = name
		self._crosshair_templates[name] = template
		self._crosshair_widget_definitions[name] = template:create_widget_defintion(scenegraph_id)
	end
end)

-- Provide default spread for melee weapons.
mod:hook("HudElementCrosshair", "_spread_yaw_pitch", function(func, self)
	local yaw, pitch = func(self)

	local parent = self._parent
	local player_extensions = parent:player_extensions()

	if player_extensions then
		local unit_data_extension = player_extensions.unit_data
		local weapon_action_component = unit_data_extension and unit_data_extension:read_component("weapon_action")

		if weapon_action_component then
			local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)

			if weapon_template then
				if WeaponTemplate.is_melee(weapon_template) then
					return 2, 2
				end
			end
		end
	end

	return yaw, pitch
end)
