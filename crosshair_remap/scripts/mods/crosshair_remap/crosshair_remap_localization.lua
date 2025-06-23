local mod = get_mod("crosshair_remap")
mod:io_dofile("crosshair_remap/scripts/mods/crosshair_remap/crosshair_remap_init")

local builtin_crosshairs_localization = {
	chevron_crosshair = {
		en = "Chevron",
		["zh-cn"] = "倒 V 形",
	},
	small_circle_crosshair = {
		en = "Small Circle",
		["zh-cn"] = "小圆圈",
	},
	small_cross_no_spread_crosshair = {
		en = "Small Cross (No Spread)",
		["zh-cn"] = "小十字（无扩散）",
	},
	larger_dot_crosshair = {
		en = "Larger Dot",
		["zh-cn"] = "更大的点准星",
	},
	t_shape_crosshair = {
		en = "T Shape",
		["zh-cn"] = "T 形",
	},
	t_shape_dot_crosshair = {
		en = "T Shape + " .. Localize("loc_setting_crosshair_type_override_dot"),
		["zh-cn"] = "T 形 + " .. Localize("loc_setting_crosshair_type_override_dot"),
	},
	dash_dot_crosshair = {
		en = "Dash + " .. Localize("loc_setting_crosshair_type_override_dot"),
		["zh-cn"] = "横线 + " .. Localize("loc_setting_crosshair_type_override_dot"),
	},
	shotgun_dot_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_shotgun") .. " + " .. Localize("loc_setting_crosshair_type_override_dot"),
	},
	shotgun_wide_dot_crosshair = {
		en = "Wider Spreadshot + " .. Localize("loc_setting_crosshair_type_override_dot"),
		["zh-cn"] = "宽散射 + " .. Localize("loc_setting_crosshair_type_override_dot"),
	},
	spray_n_pray_dot_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_spray_n_pray") .. " + " .. Localize("loc_setting_crosshair_type_override_dot"),
	},
	charge_up_cross_crosshair = {
		en = "Charge Up + " .. Localize("loc_setting_crosshair_type_override_killshot"),
		["zh-cn"] = "充能 + " .. Localize("loc_setting_crosshair_type_override_killshot"),
	},
	charge_up_chevron_crosshair = {
		en = "Charge Up + Chevron",
		["zh-cn"] = "充能 + 倒 V 形",
	},
	charge_up_ads_dot_crosshair = {
		en = "Wider Charge Up + " .. Localize("loc_setting_crosshair_type_override_dot"),
		["zh-cn"] = "宽充能 + " .. Localize("loc_setting_crosshair_type_override_dot"),
	},
	charge_up_ads_cross_crosshair = {
		en = "Wider Charge Up + " .. Localize("loc_setting_crosshair_type_override_killshot"),
		["zh-cn"] = "宽充能 + " .. Localize("loc_setting_crosshair_type_override_killshot"),
	},
	charge_up_ads_chevron_crosshair = {
		en = "Wider Charge Up + Chevron",
		["zh-cn"] = "宽充能 + 倒 V 形",
	},
	charge_up_ads_t_shape_dot_crosshair = {
		en = "Wider Charge Up + T Shape + " .. Localize("loc_setting_crosshair_type_override_dot"),
		["zh-cn"] = "宽充能 + T 形 + " .. Localize("loc_setting_crosshair_type_override_dot"),
	},
}

local localization = {
	mod_name = {
		en = "Crosshair Remap",
		["zh-cn"] = "准星自定义",
	},
	mod_description = {
		en = "Allows players to change crosshairs per weapon type.",
		["zh-cn"] = "允许玩家按武器类型修改准星。",
	},

	none_crosshair = {
		en = "None (No Hitmarkers)",
		["zh-cn"] = "无准星（无命中提示）",
	},
	assault_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_assault"),
	},
	bfg_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_bfg"),
	},
	charge_up_crosshair = {
		en = "Charge Up",
		["zh-cn"] = "充能",
	},
	charge_up_ads_crosshair = {
		en = "Wider Charge Up ADS",
		["zh-cn"] = "宽充能机瞄",
	},
	cross_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_killshot"),
	},
	dot_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_dot"),
	},
	flamer_crosshair = {
		en = "Flamer",
		["zh-cn"] = "喷火",
	},
	ironsight_crosshair = {
		en = "Ironsight",
		["zh-cn"] = "机瞄",
	},
	projectile_drop_crosshair = {
		en = "Projectile Drop",
		["zh-cn"] = "弹道下坠",
	},
	shotgun_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_shotgun"),
	},
	shotgun_wide_crosshair = {
		en = "Wider Spreadshot",
		["zh-cn"] = "宽散射",
	},
	spray_n_pray_crosshair = {
		en = Localize("loc_setting_crosshair_type_override_spray_n_pray"),
	},

	none_class = {
		en = "When No Crosshair",
		["zh-cn"] = "无准星时",
	},
	melee_class = {
		en = "Melee Weapons and Actions",
		["zh-cn"] = "近战武器和动作",
	},
	ability_class = {
		en = "Combat Ability in Progress",
		["zh-cn"] = "主动技能进行时",
	},
	psyker_smite_class = {
		en = Localize("loc_class_psyker_title") .. " " .. Localize("loc_ability_psyker_smite"),
		["zh-cn"] = Localize("loc_class_psyker_title") .. Localize("loc_ability_psyker_smite"),
	},
	psyker_throwing_knives_class = {
		en = Localize("loc_class_psyker_title") .. " " .. Localize("loc_ability_psyker_blitz_throwing_knives"),
		["zh-cn"] = Localize("loc_class_psyker_title") .. Localize("loc_ability_psyker_blitz_throwing_knives"),
	},
	psyker_chain_lightning_class = {
		en = Localize("loc_class_psyker_title") .. " " .. Localize("loc_ability_psyker_chain_lightning"),
		["zh-cn"] = Localize("loc_class_psyker_title") .. Localize("loc_ability_psyker_chain_lightning"),
	},
	autogun_infantry_class = {
		en = Localize("loc_weapon_family_autogun_p1_m1"),
	},
	autogun_braced_class = {
		en = Localize("loc_weapon_family_autogun_p2_m1"),
	},
	autogun_headhunter_class = {
		en = Localize("loc_weapon_family_autogun_p3_m1"),
	},
	autopistol_class = {
		en = Localize("loc_weapon_family_autopistol_p1_m1"),
	},
	boltgun_class = {
		en = Localize("loc_weapon_family_bolter_p1_m1"),
	},
	boltpistal_class = {
		en = Localize("loc_weapon_family_boltpistol_p1_m1"),
	},
	flamer_class = {
		en = Localize("loc_weapon_family_flamer_p1_m1"),
	},
	force_staff_trauma_class = {
		en = Localize("loc_weapon_family_forcestaff_p1_m1"),
	},
	force_staff_purgatus_class = {
		en = Localize("loc_weapon_family_forcestaff_p2_m1"),
	},
	force_staff_surge_class = {
		en = Localize("loc_weapon_family_forcestaff_p3_m1"),
	},
	force_staff_voidstrike_class = {
		en = Localize("loc_weapon_family_forcestaff_p4_m1"),
	},
	lasgun_infantry_class = {
		en = Localize("loc_weapon_family_lasgun_p1_m1"),
	},
	lasgun_helbore_class = {
		en = Localize("loc_weapon_family_lasgun_p2_m1"),
	},
	lasgun_recon_class = {
		en = Localize("loc_weapon_family_lasgun_p3_m1"),
	},
	laspistol_class = {
		en = Localize("loc_weapon_family_laspistol_p1_m1"),
	},
	plasma_gun_class = {
		en = Localize("loc_weapon_family_plasmagun_p1_m1"),
	},
	revolver_class = {
		en = Localize("loc_weapon_family_stubrevolver_p1_m1"),
	},
	revolver_fanning_class = {
		en = Localize("loc_weapon_family_stubrevolver_p1_m1") .. " (Fanning)",
		["zh-cn"] = Localize("loc_weapon_family_stubrevolver_p1_m1") .. "（击锤速射型）",
	},
	shotgun_lawbringer_class = {
		en = Localize("loc_weapon_family_shotgun_p1_m1") .. " (Wider Spreadshot)",
		["zh-cn"] = Localize("loc_weapon_family_shotgun_p1_m1") .. "（宽散射）",
	},
	shotgun_agripinaa_class = {
		en = Localize("loc_weapon_family_shotgun_p1_m1") .. " (Slug)",
		["zh-cn"] = Localize("loc_weapon_family_shotgun_p1_m1") .. "（独头弹）",
	},
	shotgun_kantrael_class = {
		en = Localize("loc_weapon_family_shotgun_p1_m1") .. " (Incendiary)",
		["zh-cn"] = Localize("loc_weapon_family_shotgun_p1_m1") .. "（燃烧弹）",
	},
	assault_shotgun_class = {
		en = Localize("loc_weapon_family_shotgun_p2_m1"),
	},
	exterminator_shotgun_stun_class = {
		en = Localize("loc_weapon_family_shotgun_p4_m1") .. " (Electric)",
		["zh-cn"] = Localize("loc_weapon_family_shotgun_p4_m1") .. "（电击弹）",
	},
	exterminator_shotgun_rending_class = {
		en = Localize("loc_weapon_family_shotgun_p4_m2") .. " (Rending)",
		["zh-cn"] = Localize("loc_weapon_family_shotgun_p4_m2") .. "（脆弱弹）",
	},
	shotpistol_shield_class = {
		en = Localize("loc_weapon_family_shotpistol_shield_p1_m1"),
	},
	grenadier_gauntlet_class = {
		en = Localize("loc_weapon_family_ogryn_gauntlet_p1_m1"),
	},
	heavy_stubber_single_barrel_class = {
		en = Localize("loc_weapon_family_ogryn_heavystubber_p2_m1"),
	},
	heavy_stubber_class = {
		en = Localize("loc_weapon_family_ogryn_heavystubber_p1_m1"),
	},
	ripper_gun_class = {
		en = Localize("loc_weapon_family_ogryn_rippergun_p1_m1"),
	},
	kickback_class = {
		en = Localize("loc_weapon_family_ogryn_thumper_p1_m1"),
	},
	rumbler_class = {
		en = Localize("loc_weapon_family_ogryn_thumper_p1_m2"),
	},

	primary = {
		en = "Primary Action",
		["zh-cn"] = "主要动作",
	},
	secondary = {
		en = "Secondary Action",
		["zh-cn"] = "次要动作",
	},
	special = {
		en = "Special Action",
		["zh-cn"] = "特殊动作",
	},
}

for name, loc in pairs(builtin_crosshairs_localization) do
	localization[name] = {}
	for lang, msg in pairs(loc) do
		localization[name][lang] = " " .. msg
	end
end
for name, loc in pairs(mod.custom_localization) do
	localization[name] = loc
end

return localization
