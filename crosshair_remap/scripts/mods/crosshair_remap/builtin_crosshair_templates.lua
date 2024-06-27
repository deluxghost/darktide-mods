local crosshairs = {
	"chevron",
	"small_circle",
	"t_shape",
	"t_shape_dot",
	"dash_dot",
	"shotgun_dot",
	"spray_n_pray_dot",
	"charge_up_cross",
	"charge_up_chevron" ,
	"charge_up_ads_dot",
	"charge_up_ads_cross",
	"charge_up_ads_chevron",
}

local templates = {}
for index, name in ipairs(crosshairs) do
	local template = Mods.file.dofile("crosshair_remap/scripts/mods/crosshair_remap/builtin_crosshairs/" .. name)
	template.name = name
	templates[index] = template
end

return templates
