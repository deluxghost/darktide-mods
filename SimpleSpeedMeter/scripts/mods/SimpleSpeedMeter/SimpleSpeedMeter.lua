local mod = get_mod("SimpleSpeedMeter")

mod:register_hud_element({
	class_name = "HudElementSpeed",
	filename = "SimpleSpeedMeter/scripts/mods/SimpleSpeedMeter/HudElementSpeed",
	use_hud_scale = true,
	visibility_groups = {
		"dead",
		"alive",
	},
})
