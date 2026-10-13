local settings = {
	unit = "content/environment/artsets/imperial/global/props/machinery/genestealer_quadbike/genestealer_quadbike_01",
	tyre = "content/environment/artsets/imperial/global/props/machinery/genestealer_quadbike/genestealer_tyre_01",
	forward_speed = 12,
	reverse_speed = 4,
	acceleration = 5,
	coasting_deceleration = 2.5,
	braking_deceleration = 12,
	steering_angle = math.rad(30),
	steering_speed = math.rad(100),
	max_yaw_rate = math.rad(80),
	wheelbase = 1.404685,
	wheel_radius = 0.32,
	wheel_width = 0.277,
	wheels = {
		{ position = { -0.56563, 0.674695, 0.299494 }, front = true, side = -1 },
		{ position = { 0.56563, 0.674695, 0.299494 }, front = true, side = 1 },
		{ position = { -0.56563, -0.72999, 0.299494 }, front = false, side = -1 },
		{ position = { 0.56563, -0.72999, 0.299494 }, front = false, side = 1 },
	},
	gravity = 20,
	max_slope = math.rad(42),
	max_step_height = 0.45,
	suspension_travel = 0.12,
	suspension_response = 9,
	suspension_speed = math.rad(65),
	terrain_contact_tolerance = 0.08,
	vertical_contact_tolerance = 0.04,
	collision_shapes = {
		{ center = { 0, 0, 0.48 }, half = { 0.48, 0.8, 0.27 } },
		{ center = { 0, -0.91, 0.56 }, half = { 0.56, 0.23, 0.26 } },
		{ center = { 0, 1.02, 0.7 }, half = { 0.56, 0.22, 0.22 } },
	},
}

-- Lower tyre contacts belong to the rolling ground solver. The upper halves
-- still block walls and narrow openings using the model's actual wheel width.
for _, wheel in ipairs(settings.wheels) do
	settings.collision_shapes[#settings.collision_shapes + 1] = {
		center = { wheel.position[1], wheel.position[2], wheel.position[3] + settings.wheel_radius * 0.5 },
		half = { settings.wheel_width * 0.5, settings.wheel_radius, settings.wheel_radius * 0.5 },
	}
end

return settings
