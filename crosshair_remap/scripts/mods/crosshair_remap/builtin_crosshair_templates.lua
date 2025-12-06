local crosshairs = {
	"chevron",
	"small_circle",
	"small_cross_no_spread",
	"larger_dot",
	"t_shape",
	"t_shape_dot",
	"dash_dot",
	"shotgun_dot",
	"shotgun_wide_dot",
	"spray_n_pray_dot",
	"charge_up_cross",
	"charge_up_chevron" ,
	"charge_up_ads_dot",
	"charge_up_ads_cross",
	"charge_up_ads_chevron",
	"charge_up_ads_t_shape_dot",
}

local templates = {}
for index, name in ipairs(crosshairs) do
	local template = Mods.file.dofile("crosshair_remap/scripts/mods/crosshair_remap/builtin_crosshairs/" .. name)
	template.name = name
	templates[index] = template
end

return templates
