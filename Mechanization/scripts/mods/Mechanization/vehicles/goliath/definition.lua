local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/goliath/settings")
local Interpolation = mod.load_module("network/interpolation")
local Goliath = {
	id = "goliath",
	name = "vehicle_goliath",
	settings = Settings,
	controller = mod.load_module("vehicles/goliath/controller"),
	crosshairs = {
		unarmed = { crosshair_type = "cross", spread_scalar = 0 },
	},
	controls = {
		throttle = { "move_forward", "move_backward" },
		steer = { "move_right", "move_left" },
	},
	camera = {
		distance = 12,
		offset = 0,
		height = 5,
		min_pitch = math.rad(-30),
		max_pitch = math.rad(45),
		vertical_fov = math.rad(65),
	},
	contacts = {
		damage = 1000,
		tick_interval = 0.4,
		contact_margin = 0.15,
		push_speed = 6,
		speed_multiplier = { ordinary = 0.95, elite = 0.75, ogryn = 0.5, boss = 0.2 },
	},
	seats = {
		{
			position = { -0.8, 2.2, 1.2 },
			yaw = 0,
			visible = false,
			protected = true,
			movement = true,
			actions = {},
		},
		{
			position = { -0.55, -3.1, 1.26 },
			yaw = 0,
			visible = true,
			protected = false,
			movement = false,
			actions = {},
			platform = "cargo",
			allow_ogryn = true,
		},
		{
			position = { 0.55, -3.1, 1.26 },
			yaw = 0,
			visible = true,
			protected = false,
			movement = false,
			actions = {},
			platform = "cargo",
			allow_ogryn = true,
		},
		{
			position = { -0.55, -1.9, 1.26 },
			yaw = 0,
			visible = true,
			protected = false,
			movement = false,
			actions = {},
			platform = "cargo",
			allow_ogryn = true,
		},
		{
			position = { 0.55, -1.9, 1.26 },
			yaw = 0,
			visible = true,
			protected = false,
			movement = false,
			actions = {},
			platform = "cargo",
			allow_ogryn = true,
		},
		{
			position = { -0.55, -0.7, 1.26 },
			yaw = 0,
			visible = true,
			protected = false,
			movement = false,
			actions = {},
			platform = "cargo",
			allow_ogryn = true,
		},
		{
			position = { 0.55, -0.7, 1.26 },
			yaw = 0,
			visible = true,
			protected = false,
			movement = false,
			actions = {},
			platform = "cargo",
			allow_ogryn = true,
		},
	},
	platforms = {
		cargo = {
			min = { -2.05, -3.9 },
			max = { 2.05, 0 },
			floor_height = 1.26,
			obstacles = {
				{ center = { -2.15, -2.413 }, half_length = 0.45, radius = 0.65 },
				{ center = { 2.15, -2.413 }, half_length = 0.45, radius = 0.65 },
			},
			max_speed = 6,
			jump_height = 2,
		},
	},
	actions = {},
}

Goliath.snapshot = function (v)
	local normal = v.normal:unbox()
	return { normal = { normal.x, normal.y, normal.z }, speed = v.speed, wheel_speed = v.wheel_speed, steering = v.steering }
end

Goliath.validate_state = function (state, finite)
	assert(type(state) == "table" and type(state.normal) == "table" and #state.normal == 3, "Invalid Goliath state")
	for index = 1, 3 do
		assert(finite(state.normal[index]), "Invalid Goliath ground normal")
	end
	assert(finite(state.speed) and finite(state.wheel_speed) and finite(state.steering), "Invalid Goliath motion")
end

Goliath.interpolate = function (v, from, to, fraction)
	v.normal:store(Interpolation.normal(from.normal, to.normal, fraction))
	v.speed = math.lerp(from.speed, to.speed, fraction)
	v.wheel_speed = math.lerp(from.wheel_speed, to.wheel_speed, fraction)
	v.steering = math.lerp(from.steering, to.steering, fraction)
end

Goliath.summary = function (v)
	return string.format("%.1f km/h", math.abs(v.speed) * 3.6), string.format("%.1f km/h", Settings.forward_speed * 3.6)
end

return Goliath
