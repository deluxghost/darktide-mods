local mod = get_mod("GoodOldOutlines")
local state = mod:persistent_table("runtime")
local opaque_outlines = 1
local occluded_dimming = 0.5
local outline_opacity = 100

local function update()
	opaque_outlines = mod:get("opaque_outlines") and 1 or 0
	-- The renderer consumes dimming; the setting expresses visibility.
	occluded_dimming = 1 - mod:get("occluded_outline_visibility") / 100
	outline_opacity = mod:get("outline_opacity")
end

mod:hook_safe(CLASS.CameraManager, "shading_callback", function(manager, world, shading_environment)
	if state.active and manager._world == world then
		-- The camera blends the original environment again before each callback.
		ShadingEnvironment.set_vector3(shading_environment, "outline_color_alpha",
			Vector3(opaque_outlines, occluded_dimming, outline_opacity))
	end
end)

return { update = update }
