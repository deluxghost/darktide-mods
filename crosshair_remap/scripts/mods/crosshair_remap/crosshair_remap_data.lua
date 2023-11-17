local mod = get_mod("crosshair_remap")

mod.settings = {}

local function make_options()
	local options = {}
	for i, name in ipairs(mod.all_crosshair_names) do
		options[i] = {
			text = name .. "_crosshair",
			value = name
		}
	end
	return options
end

local function make_dropdown(name, default, title)
	mod.settings[name] = default
	return {
		setting_id = name,
		title = title,
		type = "dropdown",
		default_value = default,
		options = make_options()
	}
end

local function make_group(name, default1, default2, default3)
	local widgets = {}
	if default1 then
		widgets[#widgets+1] = make_dropdown(name .. "_primary", default1, "primary")
	end
	if default2 then
		widgets[#widgets+1] = make_dropdown(name .. "_secondary", default2, "secondary")
	end
	if default3 then
		widgets[#widgets+1] = make_dropdown(name .. "_special", default3, "special")
	end
	return {
		setting_id = name,
		type = "group",
		sub_widgets = widgets
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			make_dropdown("none_class", "none"),
			make_dropdown("melee_class", "dot"),
			make_dropdown("psyker_bb_class", "charge_up"),
			make_group("autogun_infantry_class", "assault", "ironsight"),
			make_group("autogun_braced_class", "assault", "spray_n_pray"),
			make_group("autogun_headhunter_class", "cross", "ironsight"),
			make_group("autopistol_class", "assault", "assault"),
			make_group("boltgun_class", "spray_n_pray", "ironsight"),
			make_group("flamer_class", "spray_n_pray", "spray_n_pray"),
			make_group("force_staff_trauma_class", "assault", "charge_up"),
			make_group("force_staff_purgatus_class", "spray_n_pray", "charge_up"),
			make_group("force_staff_surge_class", "assault", "charge_up"),
			make_group("force_staff_voidstrike_class", "assault", "charge_up"),
			make_group("lasgun_infantry_class", "cross", "ironsight"),
			make_group("lasgun_helbore_class", "bfg", "charge_up_ads"),
			make_group("lasgun_recon_class", "assault", "ironsight"),
			make_group("laspistol_class", "assault", "ironsight"),
			make_group("plasma_gun_class", "bfg", "bfg"),
			make_group("revolver_class", "bfg", "ironsight"),
			make_group("shotgun_lawbringer_class", "shotgun", "ironsight", "shotgun_wide"),
			make_group("shotgun_agripinaa_class", "shotgun", "ironsight", "shotgun_slug"),
			make_group("shotgun_kantrael_class", "shotgun", "ironsight", "shotgun"),
			make_group("grenadier_gauntlet_class", "dot", "projectile_drop"),
			make_group("heavy_stubber_class", "spray_n_pray", "spray_n_pray"),
			make_group("ripper_gun_class", "shotgun", "spray_n_pray"),
			make_group("kickback_class", "shotgun", "shotgun"),
			make_group("rumbler_class", "projectile_drop", "none"),
		}
	}
}
