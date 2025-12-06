local mod = get_mod("crosshair_remap")
local Action = require("scripts/utilities/action/action")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local slot_configuration = PlayerCharacterConstants.slot_configuration

local settings_migration = {
	shotgun_slug = "cross",
	ironsight_dot = "dot",
	ironsight_chevron = "chevron",
}

local function collect_settings()
	for k, def in pairs(mod.default_settings) do
		local v = mod:get(k)
		local migration = settings_migration[v]
		if migration then
			v = migration
			mod:set(k, v)
		elseif not table.array_contains(mod.all_crosshair_names, v) then
			v = def
			mod:set(k, v)
		end
		mod.settings[k] = v
	end
end

mod.load_package = function (package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "crosshair_remap", nil, true)
	end
end

mod.on_enabled = function ()
	collect_settings()
end

mod.on_setting_changed = function ()
	collect_settings()
end

mod.on_all_mods_loaded = function ()
	mod.load_package("packages/ui/views/mission_board_view/mission_board_view")
end

local weapon_class_filter = {
	autogun_infantry_class = {
		keywords = { "autogun", "p1" },
	},
	autogun_braced_class = {
		keywords = { "autogun", "p2" },
	},
	autogun_headhunter_class = {
		keywords = { "autogun", "p3" },
	},
	autopistol_class = {
		keywords = { "autopistol" },
	},
	boltgun_class = {
		keywords = { "bolter" },
	},
	boltpistal_class = {
		keywords = { "boltpistol" },
	},
	flamer_class = {
		keywords = { "flamer" },
	},
	psyker_chain_lightning_class = {
		name = "psyker_chain_lightning",
	},
	force_staff_trauma_class = {
		keywords = { "force_staff", "p1" },
	},
	force_staff_purgatus_class = {
		keywords = { "force_staff", "p2" },
	},
	force_staff_surge_class = {
		keywords = { "force_staff", "p3" },
	},
	force_staff_voidstrike_class = {
		keywords = { "force_staff", "p4" },
	},
	lasgun_infantry_class = {
		keywords = { "lasgun", "p1" },
	},
	lasgun_helbore_class = {
		keywords = { "lasgun", "p2" },
	},
	lasgun_recon_class = {
		keywords = { "lasgun", "p3" },
	},
	laspistol_class = {
		keywords = { "laspistol" },
	},
	plasma_gun_class = {
		keywords = { "plasma_rifle" },
	},
	revolver_class = {
		keywords = { "stub_pistol" },
	},
	combat_shotguns = {
		keywords = { "shotgun", "p1" },
	},
	assault_shotgun_class = {
		keywords = { "shotgun", "p2" },
	},
	exterminator_shotguns = {
		keywords = { "shotgun", "p4" },
	},
	grenadier_gauntlet_class = {
		keywords = { "grenadier_gauntlet" },
	},
	heavy_stubber_class = {
		keywords = { "heavystubber", "p1" },
	},
	heavy_stubber_single_barrel_class = {
		keywords = { "heavystubber", "p2" },
	},
	ripper_gun_class = {
		keywords = { "rippergun" },
	},
	kickback_class = {
		name = "ogryn_thumper_p1_m1",
	},
	rumbler_class = {
		name = "ogryn_thumper_p1_m2",
	},
	shotpistol_shield_class = {
		keywords = { "shotpistol_shield" },
	},
	dual_autopistols_class = {
		name_prefix = "dual_autopistols_",
	},
	dual_stubpistols_class = {
		name_prefix = "dual_stubpistols_",
	},
	needlepistol_class = {
		keywords = { "needlepistol" },
	},
}
local class_name_filter = {}
local class_name_prefix_filter = {}
local class_keyword_filter = {}

for key, value in pairs(weapon_class_filter) do
	if value.name ~= nil then
		class_name_filter[key] = value
	elseif value.name_prefix ~= nil then
		class_name_prefix_filter[key] = value
	else
		class_keyword_filter[key] = value
	end
end

local special_shotgun_class = {
	"shotgun_lawbringer_class",
	"shotgun_agripinaa_class",
	"shotgun_kantrael_class",
	"exterminator_shotgun_stun_class",
	"exterminator_shotgun_rending_class",
}

local function get_filtered_weapon_class(weapon_template_name, weapon_template)
	local function has_keyword(keyword)
		return WeaponTemplate.has_keyword(weapon_template, keyword)
	end
	for class, filter in pairs(class_name_filter) do
		if weapon_template_name == filter.name then
			return class
		end
	end
	for class, filter in pairs(class_name_prefix_filter) do
		if string.starts_with(weapon_template_name, filter.name_prefix) then
			return class
		end
	end
	for class, filter in pairs(class_keyword_filter) do
		local total = #filter.keywords
		for _, keyword in ipairs(filter.keywords) do
			if has_keyword(keyword) then
				total = total - 1
			end
			if total == 0 then
				return class
			end
		end
	end
end

local function determine_ranged_weapon_class(weapon_template_name, weapon_template)
	local weapon_class = get_filtered_weapon_class(weapon_template_name, weapon_template)
	if weapon_class == nil then
		return nil
	end

	if weapon_class == "combat_shotguns" then
		if not weapon_template.actions or not weapon_template.actions.action_shoot_hip or not weapon_template.actions.action_shoot_hip.fire_configuration then
			return nil
		end
		if weapon_template.actions.action_shoot_hip.fire_configuration.shotshell_special then
			local shotshell_template = weapon_template.actions.action_shoot_hip.fire_configuration.shotshell_special
			if shotshell_template.name == "shotgun_cleaving_special" then
				return "shotgun_lawbringer_class"
			elseif shotshell_template.name == "shotgun_slug_special" then
				return "shotgun_agripinaa_class"
			elseif shotshell_template.name == "shotgun_burninating_special" then
				return "shotgun_kantrael_class"
			end
		end
		return nil
	elseif weapon_class == "exterminator_shotguns" then
		if not weapon_template.actions or not weapon_template.actions.action_shoot_hip or not weapon_template.actions.action_shoot_hip.fire_configuration then
			return nil
		end
		if weapon_template.actions.action_shoot_hip.fire_configuration.shotshell_special then
			local shotshell_template = weapon_template.actions.action_shoot_hip.fire_configuration.shotshell_special
			if shotshell_template.name == "shotgun_p4_m1_hip_special" or shotshell_template.name == "shotgun_p4_m3_hip_special" then
				return "exterminator_shotgun_stun_class"
			elseif shotshell_template.name == "shotgun_p4_m2_hip_special" then
				return "exterminator_shotgun_rending_class"
			end
		end
		return nil
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
	block = true,
	-- block_aiming = true,
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

mod:hook_origin("HudElementCrosshair", "_get_current_crosshair_type", function (self)
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

				if weapon_template_name == "unarmed" or weapon_template_name == "zealot_relic" then
					return mod.settings["ability_class"]
				end

				if weapon_template_name == "psyker_smite" then
					return mod.settings["psyker_smite_class"]
				elseif weapon_template_name == "psyker_throwing_knives" then
					return mod.settings["psyker_throwing_knives_class"]
				elseif weapon_template_name == "missile_launcher" then
					return mod.settings["missile_launcher_class"]
				end

				if WeaponTemplate.is_melee(weapon_template) then
					return mod.settings["melee_class"]
				end

				if WeaponTemplate.is_ranged(weapon_template) or weapon_template.psyker_smite then
					if melee_action_kinds[action_kind] then
						-- TODO: cleanup
						if string.starts_with(weapon_template_name, "dual_stubpistols_") and action_kind == "windup" then
						else
							return mod.settings["melee_class"]
						end
					end

					local weapon_class = determine_ranged_weapon_class(weapon_template_name, weapon_template)
					if not weapon_class then
						goto unchanged
					end
					local in_alt_fire = altfire_action_kinds[action_kind] or alternate_fire_component.is_active
					local in_reload = reload_action_kinds[action_kind] and true

					local inventory_component = unit_data_extension:read_component("inventory")
					local wielded_slot = inventory_component.wielded_slot
					local slot_type = slot_configuration[wielded_slot].slot_type
					local inventory_slot_component
					if slot_type == "weapon" then
						inventory_slot_component = unit_data_extension:read_component(wielded_slot)
					end

					if weapon_class == "shotpistol_shield_class" and inventory_slot_component and not in_reload then
						local current_ammunition_clip = inventory_slot_component.current_ammunition_clip[1] or 0
						local current_ammo = inventory_slot_component.current_ammunition_reserve + current_ammunition_clip
						if not in_alt_fire and current_ammo == 0 then
							return mod.settings["melee_class"]
						end
						if in_alt_fire and current_ammunition_clip == 0 then
							return mod.settings["melee_class"]
						end
					end

					if table.array_contains(special_shotgun_class, weapon_class) then
						local in_special = false
						if inventory_slot_component then
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

-- Inject custom crosshairs
mod:hook_safe("HudElementCrosshair", "init", function (self, ...)
	local scenegraph_id = "pivot"
	for _, template in ipairs(mod.builtin_crosshair_templates) do
		self._crosshair_templates[template.name] = template
		self._crosshair_widget_definitions[template.name] = template:create_widget_defintion(scenegraph_id)
	end
	for _, name in ipairs(mod.custom_crosshair_names) do
		local template = Mods.file.dofile(mod.custom_crosshair_templates[name])
		template.name = name
		self._crosshair_templates[template.name] = template
		self._crosshair_widget_definitions[template.name] = template:create_widget_defintion(scenegraph_id)
	end
end)

mod:hook("HudElementCrosshair", "_crosshair_settings", function (func, self)
	local crosshair_settings = func(self)
	return crosshair_settings or {
		crosshair_type = "none",
	}
end)

-- Provide default spread for melee weapons
mod:hook("HudElementCrosshair", "_spread_yaw_pitch", function (func, self)
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
