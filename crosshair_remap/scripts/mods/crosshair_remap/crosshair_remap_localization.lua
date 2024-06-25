local mod = get_mod("crosshair_remap")

-- Not part of localization. DO NOT CHANGE. SCROLL DOWN.

mod.vanilla_crosshair_names = {
	"assault",
	"bfg",
	"charge_up",
	"charge_up_ads",
	"cross",
	"dot",
	"flamer",
	"ironsight",
	"projectile_drop",
	"shotgun",
	"shotgun_wide",
	"spray_n_pray",
	"none",
}

mod.custom_dir = "crosshair_remap/custom_crosshairs/"

mod.custom_crosshair_names = Mods.file.dofile(mod.custom_dir .. "LIST")

mod.all_crosshair_names = {}
for _, name in ipairs(mod.vanilla_crosshair_names) do
	table.insert(mod.all_crosshair_names, name)
end
for _, name in ipairs(mod.custom_crosshair_names) do
	table.insert(mod.all_crosshair_names, name)
end

-- Localization starts here

local locres = {
	mod_name = {
		en = "Crosshair Remap",
		["zh-cn"] = "准星自定义",
	},
	mod_description = {
		en = "Allows players to change crosshairs per weapon type.",
		["zh-cn"] = "允许玩家按武器类型修改准星。",
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
		en = "Charge Up ADS",
		["zh-cn"] = "充能机瞄",
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
	none_crosshair = {
		en = "None (No Hitmarkers)",
		["zh-cn"] = "无准星（无命中提示）",
	},

	none_class = {
		en = "When No Crosshair",
		["zh-cn"] = "无准星时",
	},
	melee_class = {
		en = "Melee Weapons and Actions",
		["zh-cn"] = "近战武器和动作",
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
		en = "Autoguns (Infantry)",
		["zh-cn"] = "自动枪（步兵）",
	},
	autogun_braced_class = {
		en = "Autoguns (Braced)",
		["zh-cn"] = "自动枪（稳固）",
	},
	autogun_headhunter_class = {
		en = "Autoguns (Headhunter)",
		["zh-cn"] = "自动枪（猎颅者）",
	},
	autopistol_class = {
		en = "Autopistols",
		["zh-cn"] = "自动手枪",
	},
	boltgun_class = {
		en = "Boltguns",
		["zh-cn"] = "爆矢枪",
	},
	boltpistal_class = {
		en = "Bolt Pistols",
		["zh-cn"] = "爆矢手枪",
	},
	flamer_class = {
		en = "Flamers",
		["zh-cn"] = "火焰喷射器",
	},
	force_staff_trauma_class = {
		en = "Force Staves (Trauma)",
		["zh-cn"] = "力场杖（创伤）",
	},
	force_staff_purgatus_class = {
		en = "Force Staves (Purgatus)",
		["zh-cn"] = "力场杖（净化）",
	},
	force_staff_surge_class = {
		en = "Force Staves (Surge)",
		["zh-cn"] = "力场杖（激涌）",
	},
	force_staff_voidstrike_class = {
		en = "Force Staves (Voidstrike)",
		["zh-cn"] = "力场杖（虚空打击）",
	},
	lasgun_infantry_class = {
		en = "Lasguns (Infantry)",
		["zh-cn"] = "激光枪（步兵）",
	},
	lasgun_helbore_class = {
		en = "Lasguns (Helbore)",
		["zh-cn"] = "激光枪（地狱钻）",
	},
	lasgun_recon_class = {
		en = "Lasguns (Recon)",
		["zh-cn"] = "激光枪（侦察）",
	},
	laspistol_class = {
		en = "Laspistols",
		["zh-cn"] = "激光手枪",
	},
	plasma_gun_class = {
		en = "Plasma Guns",
		["zh-cn"] = "等离子枪",
	},
	revolver_class = {
		en = "Stub Revolvers",
		["zh-cn"] = "速发左轮枪",
	},
	revolver_fanning_class = {
		en = "Stub Revolvers (Fanning)",
		["zh-cn"] = "速发左轮枪（击锤速射型）",
	},
	shotgun_lawbringer_class = {
		en = "Combat Shotguns (Lawbringer)",
		["zh-cn"] = "战斗霰弹枪（执法者）",
	},
	shotgun_agripinaa_class = {
		en = "Combat Shotguns (Agripinaa)",
		["zh-cn"] = "战斗霰弹枪（阿格里皮娜）",
	},
	shotgun_kantrael_class = {
		en = "Combat Shotguns (Kantrael)",
		["zh-cn"] = "战斗霰弹枪（卡特雷尔）",
	},
	assault_shotgun_class = {
		en = "Assault Shotguns",
		["zh-cn"] = "突击霰弹枪",
	},
	grenadier_gauntlet_class = {
		en = "Grenadier Gauntlets",
		["zh-cn"] = "掷弹兵臂铠",
	},
	heavy_stubber_class = {
		en = "Heavy Stubbers",
		["zh-cn"] = "重机枪",
	},
	ripper_gun_class = {
		en = "Ripper Guns",
		["zh-cn"] = "开膛枪",
	},
	kickback_class = {
		en = "Kickbacks",
		["zh-cn"] = "击退者",
	},
	rumbler_class = {
		en = "Rumblers",
		["zh-cn"] = "低吼者",
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

for _, name in ipairs(mod.custom_crosshair_names) do
	locres[name .. "_crosshair"] = {
		en = "> " .. name
	}
end

return locres
