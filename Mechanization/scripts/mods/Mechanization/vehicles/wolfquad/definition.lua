local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/wolfquad/settings")
local Wolfquad = {
	id = "wolfquad",
	name = "vehicle_wolfquad",
	max_health = 2000,
	settings = Settings,
	controller = mod.load_module("vehicles/wolfquad/controller"),
	crosshairs = {
		unarmed = { crosshair_type = "cross", spread_scalar = 0 },
	},
	controls = {
		throttle = { "move_forward", "move_backward" },
		steer = { "move_right", "move_left" },
	},
	camera = {
		distance = 4.5,
		offset = 0,
		height = 1.5,
		min_pitch = math.rad(-40),
		max_pitch = math.rad(55),
		vertical_fov = math.rad(65),
	},
	contacts = {
		damage = 250,
		tick_interval = 0.4,
		contact_margin = 0.08,
		push_speed = 3,
		speed_multiplier = { ordinary = 0.75, elite = 0.55, ogryn = 0.3, boss = 0.12 },
	},
	seats = {
		{
			position = { 0, 0, 0 },
			yaw = 0,
			visible = true,
			protected = false,
			movement = true,
			actions = {},
			pose = {
				hips = { 0, -0.28, 0.94 },
				lean = math.rad(38),
				hands = {
					left = {
						position = { -0.36, 0.39, 1.153 },
						rotation = { math.pi / 2, math.pi / 2, 0 },
						bend = { -1, -0.15, -0.55 },
					},
					right = {
						position = { 0.36, 0.39, 1.153 },
						rotation = { -math.pi / 2, -math.pi / 2, 0 },
						bend = { 1, -0.15, -0.55 },
					},
				},
				feet = {
					left = { position = { -0.36, 0, 0.378 }, bend = { -1, 1, 0 } },
					right = { position = { 0.36, 0, 0.378 }, bend = { 1, 1, 0 } },
				},
			},
		},
	},
	actions = {},
}

Wolfquad.snapshot = function (v)
	local normal = v.normal:unbox()
	return { normal = { normal.x, normal.y, normal.z }, speed = v.speed, wheel_speed = v.wheel_speed, steering = v.steering }
end

Wolfquad.validate_state = function (state, finite)
	assert(type(state) == "table" and type(state.normal) == "table" and #state.normal == 3, "Invalid Wolfquad state")
	for index = 1, 3 do
		assert(finite(state.normal[index]), "Invalid Wolfquad ground normal")
	end
	assert(finite(state.speed) and finite(state.wheel_speed) and finite(state.steering), "Invalid Wolfquad motion")
end

Wolfquad.interpolate = function (v, state)
	v.normal:store(Vector3(unpack(state.normal)))
	v.speed = state.speed
	v.wheel_speed = state.wheel_speed
	v.steering = state.steering
end

Wolfquad.receive_state = Wolfquad.interpolate

Wolfquad.summary = function (v)
	return string.format("%.1f km/h", math.abs(v.speed) * 3.6), string.format("%.1f km/h", Settings.forward_speed * 3.6)
end

return Wolfquad
