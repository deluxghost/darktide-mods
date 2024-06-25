local mod = get_mod("crosshair_remap")

local Action = require("scripts/utilities/weapon/action")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local slot_configuration = PlayerCharacterConstants.slot_configuration

local function collect_settings()
	for k, _ in pairs(mod.settings) do
		local v = mod:get(k)
		if v == "shotgun_slug" then
			v = "cross"
			mod:set(k, v)
		end
		mod.settings[k] = v
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
	boltpistol = "boltpistal_class",
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
	shotgun = {
		p1 = "combat_shotguns",
		p2 = "assault_shotgun_class"
	},
	grenadier_gauntlet = "grenadier_gauntlet_class",
	heavystubber = "heavy_stubber_class",
	rippergun = "ripper_gun_class",
	shotgun_grenade = "thumpers_kickback_or_rumbler",
}

local template_name_to_class = {
	psyker_chain_lightning = "psyker_chain_lightning_class",
}

local function determine_ranged_weapon_class(weapon_template_name, weapon_template)
	for k, v in pairs(template_name_to_class) do
		if weapon_template_name == k then
			return v
		end
	end

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

	if weapon_class == nil then
		return nil
	end

	if weapon_class == "thumpers_kickback_or_rumbler" then
		if not weapon_template.crosshair then
			return weapon_class
		end
		weapon_class = weapon_template.crosshair.crosshair_type == "shotgun" and "kickback_class" or "rumbler_class"
	elseif weapon_class == "combat_shotguns" then
		if not weapon_template.crosshair then
			return weapon_class
		end
		if weapon_template.crosshair.crosshair_type_special_active == "shotgun_wide" then
			weapon_class = "shotgun_lawbringer_class"
		elseif weapon_template.crosshair.crosshair_type_special_active == "bfg" then
			weapon_class = "shotgun_agripinaa_class"
		else
			weapon_class = "shotgun_kantrael_class"
		end
	elseif weapon_class == "revolver_class" then
		if not weapon_template.crosshair then
			return weapon_class
		end
		if weapon_template.alternate_fire_settings and weapon_template.alternate_fire_settings.crosshair then
			if weapon_template.alternate_fire_settings.crosshair.crosshair_type == "bfg" then
				return "revolver_fanning_class"
			end
		end
		return weapon_class
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
		local weapon_template_name = weapon_action_component.template_name or ""

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

				if weapon_template_name == "psyker_smite" then
					return mod.settings["psyker_smite_class"]
				elseif weapon_template_name == "psyker_throwing_knives" then
					return mod.settings["psyker_throwing_knives_class"]
				end

				if WeaponTemplate.is_melee(weapon_template) then
					return mod.settings["melee_class"]
				end

				if WeaponTemplate.is_ranged(weapon_template) or weapon_template.psyker_smite then
					if melee_action_kinds[action_kind] then
						return mod.settings["melee_class"]
					end

					-- if reload_action_kinds[action_kind] then
					-- 	return mod.settings["none_class"]
					-- end

					local weapon_class = determine_ranged_weapon_class(weapon_template_name, weapon_template)
					if not weapon_class then
						goto unchanged
					end
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
				if action_settings and action_settings.crosshair then
					crosshair_type = action_settings.crosshair.crosshair_type
				elseif alternate_fire_component.is_active and alternate_fire_settings and alternate_fire_settings.crosshair and alternate_fire_settings.crosshair.crosshair_type then
					crosshair_type = alternate_fire_settings.crosshair.crosshair_type
				end

				crosshair_type = crosshair_type or (weapon_template.crosshair and weapon_template.crosshair.crosshair_type)
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

mod:hook("HudElementCrosshair", "_crosshair_settings", function(func, self)
	local crosshair_settings = func(self)
	return crosshair_settings or {
		crosshair_type = "none",
	}
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
					return 1.5, 1.5
				end
			end
		end
	end

	return yaw, pitch
end)
