local mod = get_mod("WarpUnboundTimer")

mod:register_hud_element({
	class_name = "HudElementWarpUnboundTimer",
	filename = "WarpUnboundTimer/scripts/mods/WarpUnboundTimer/HudElementWarpUnboundTimer",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
})
