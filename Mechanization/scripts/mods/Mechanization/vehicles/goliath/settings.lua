local root = "content/environment/artsets/imperial/global/props/machinery/goliath_truck/"

local settings = {
	unit = root .. "front_01",
	rear = root .. "backside_01",
	door = root .. "door_01",
	tyre = root .. "wheel_01",
	exhausts = {
		{ node = 1, offset = { -2.728, 0.265, 3.71 } },
		{ node = 1, offset = { -2.57, 0.547, 3.71 } },
		{ node = 1, offset = { 2.728, 0.265, 3.71 } },
		{ node = 1, offset = { 2.57, 0.547, 3.71 } },
	},
	forward_speed = 9,
	reverse_speed = 3,
	acceleration = 2.5,
	coasting_deceleration = 2,
	braking_deceleration = 7,
	steering_angle = math.rad(32),
	steering_speed = math.rad(55),
	max_yaw_rate = math.rad(30),
	wheelbase = 6.059,
	wheel_radius = 0.884,
	wheel_width = 0.758,
	wheels = {
		{ position = { -1.95, 3.646, 0.789 }, parent = 1, node = "ap_02", front = true },
		{ position = { 1.95, 3.646, 0.789 }, parent = 1, node = "ap_03", front = true },
		{ position = { -2.074, -2.413, 0.788 }, parent = 2, node = "ap_01", front = false },
		{ position = { 2.092, -2.413, 0.788 }, parent = 2, node = "ap_02", front = false },
	},
	gravity = 20,
	max_slope = math.rad(38),
	max_step_height = 1.15,
	hull_clearance = 1.15,
	suspension_travel = 0.45,
	suspension_response = 6,
	wheel_response = 18,
	suspension_speed = math.rad(40),
	terrain_contact_tolerance = 0.3,
	vertical_contact_tolerance = 0.12,
	collision_shapes = {
		{ center = { 0, 2.2, 1.95 }, half = { 2.4, 2.25, 1.65 } },
		{ center = { 0, -2.05, 1.55 }, half = { 2.2, 2.05, 1.35 } },
	},
	character_collision_shapes = {
		{ center = { 0, 2.7, 1.95 }, half = { 2.65, 2.6, 1.65 } },
		{ center = { 0, -2.05, 0.69 }, half = { 2.1, 2.05, 0.5 } },
		{ center = { -2.3, -2.05, 1.95 }, half = { 0.25, 2.05, 1 } },
		{ center = { 2.3, -2.05, 1.95 }, half = { 0.25, 2.05, 1 } },
		{ center = { -1.85, -2.4, 1.45 }, half = { 0.6, 0.95, 0.5 } },
		{ center = { 1.85, -2.4, 1.45 }, half = { 0.6, 0.95, 0.5 } },
		{ center = { 0, -4.05, 1.1 }, half = { 2.1, 0.15, 0.25 } },
	},
}

-- The lower tyres can step over terrain; their upper halves must still stop at a high wall.
for _, wheel in ipairs(settings.wheels) do
	settings.collision_shapes[#settings.collision_shapes + 1] = {
		center = { wheel.position[1], wheel.position[2], wheel.position[3] + settings.wheel_radius * 0.5 },
		half = { settings.wheel_width * 0.5, settings.wheel_radius, settings.wheel_radius * 0.5 },
	}
end

return settings
