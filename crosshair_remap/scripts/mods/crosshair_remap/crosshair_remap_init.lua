local mod = get_mod("crosshair_remap")
local DMF = get_mod("DMF")

mod.all_crosshair_names = {}
mod.vanilla_crosshair_names = {
	"none",
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
}
for _, name in ipairs(mod.vanilla_crosshair_names) do
	table.insert(mod.all_crosshair_names, name)
end

mod.builtin_crosshair_names = {}
mod.builtin_crosshair_templates = mod:io_dofile("crosshair_remap/scripts/mods/crosshair_remap/builtin_crosshair_templates")
for _, template in ipairs(mod.builtin_crosshair_templates) do
	table.insert(mod.builtin_crosshair_names, template.name)
	table.insert(mod.all_crosshair_names, template.name)
end

mod.custom_crosshair_names = {}
mod.custom_crosshair_templates = {}
mod.custom_localization = {}
for _, other_mod in pairs(DMF.mods) do
	if type(other_mod) == "table" and other_mod:is_enabled() and other_mod.crosshair_remap_crosshairs and type(other_mod.crosshair_remap_crosshairs) == "table" then
		for _, settings in ipairs(other_mod.crosshair_remap_crosshairs) do
			if settings.name and settings.template and not table.array_contains(mod.all_crosshair_names, settings.name) then
				if settings.localization and type(settings.localization) == "table" then
					local loc_name = settings.name .. "_crosshair"
					mod.custom_localization[loc_name] = {}
					for lang, msg in pairs(settings.localization) do
						mod.custom_localization[loc_name][lang] = " " .. msg
					end
				end
				table.insert(mod.custom_crosshair_names, settings.name)
				table.insert(mod.all_crosshair_names, settings.name)
				mod.custom_crosshair_templates[settings.name] = settings.template
			end
		end
	end
end
