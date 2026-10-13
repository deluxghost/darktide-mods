local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/valkyrie/settings")
local Controller = mod.load_module("vehicles/valkyrie/controller")
local Weapons = mod.load_module("vehicles/valkyrie/weapons")
local Valkyrie = {
	id = "valkyrie",
	name = "vehicle_valkyrie",
	max_health = 35000,
	settings = Settings,
	controller = Controller,
	crosshairs = {
		unarmed = { crosshair_type = "cross", spread_scalar = 0 },
		laser = { crosshair_type = "cross", spread_scalar = 0 },
		rocket = { crosshair_type = "cross", spread_scalar = 0 },
	},
	controls = {
		throttle = { "move_forward", "move_backward" },
		strafe = { "move_right", "move_left" },
		lift = { "jump_held", "crouching" },
	},
	camera = {
		distance = 32,
		offset = 0,
		height = 3,
		vertical_offset = 9,
		look_sensitivity = 0.5,
		min_pitch = Settings.min_pitch,
		max_pitch = Settings.max_pitch,
		vertical_fov = math.rad(60),
	},
	dismount = { near_ground = 4, descent_speed = 4 },
	contacts = {
		damage = 2000,
		tick_interval = 0.35,
		contact_margin = 0.2,
		push_speed = 10,
		speed_multiplier = { ordinary = 1, elite = 0.95, ogryn = 0.85, boss = 0.55 },
	},
	seats = {
		{ position = { 0, 6, 2.6 }, yaw = 0, visible = false, protected = true, movement = true, actions = { "laser", "rocket" } },
		{ position = { 0, 4.3, 3.4 }, yaw = 0, visible = false, protected = true, movement = false, allow_ogryn = true, actions = {} },
	},
	actions = { laser = "action_one_hold", rocket = "action_two_hold" },
}
local STATE_FIELDS = { "pitch", "bank", "speed", "laser_rounds", "rocket_rounds", "laser_wait", "rocket_wait" }

Valkyrie.snapshot = function (v, time)
	return {
		pitch = v.pitch,
		bank = v.bank,
		speed = v.speed,
		laser_rounds = v.laser_rounds,
		rocket_rounds = v.rocket_rounds,
		laser_wait = math.max(0, v.next_laser - time),
		rocket_wait = math.max(0, v.next_rocket - time),
	}
end

Valkyrie.validate_state = function (state, finite)
	assert(type(state) == "table", "Invalid Valkyrie state")
	for _, field in ipairs(STATE_FIELDS) do
		assert(finite(state[field]), "Invalid Valkyrie field: " .. field)
	end
	assert(state.laser_rounds >= 0 and state.laser_rounds <= Settings.laser_capacity, "Invalid laser ammunition")
	assert(state.rocket_rounds >= 0 and state.rocket_rounds <= Settings.rocket_capacity, "Invalid rocket ammunition")
	assert(state.laser_rounds % 1 == 0 and state.rocket_rounds % 1 == 0, "Invalid fractional ammunition")
	assert(state.pitch >= Settings.min_pitch and state.pitch <= Settings.max_pitch, "Invalid aircraft pitch")
	assert(math.abs(state.bank) <= Settings.bank_angle and state.speed >= 0, "Invalid aircraft movement")
	assert(state.laser_wait >= 0 and state.rocket_wait >= 0, "Invalid weapon delay")
end

Valkyrie.receive_state = function (v, state, time)
	v.laser_rounds, v.rocket_rounds = state.laser_rounds, state.rocket_rounds
	v.next_laser, v.next_rocket = time + state.laser_wait, time + state.rocket_wait
end

Valkyrie.interpolate = function (v, from, to, fraction)
	v.pitch = math.lerp(from.pitch, to.pitch, fraction)
	v.bank = math.lerp(from.bank, to.bank, fraction)
	v.speed = math.lerp(from.speed, to.speed, fraction)
end

Valkyrie.update = function (v, time, emit)
	Weapons.update(v, time)
	for _, action in ipairs({ "laser", "rocket" }) do
		local control = v.input.actions[action]
		if control and control.pressed then
			local event = Weapons.fire(v, action, control, time)
			if event then
				emit(v, event)
			end
		end
	end
end

Valkyrie.receive_event = function (v, event, finite)
	assert(type(event) == "table" and (event.weapon == "laser" or event.weapon == "rocket"), "Invalid Valkyrie weapon")
	assert(type(event.reloading) == "boolean", "Invalid Valkyrie reload")
	assert(finite(event.yaw) and finite(event.pitch) and finite(event.roll), "Invalid Valkyrie firing angle")
	assert(type(event.origin) == "table" and #event.origin == 3, "Invalid Valkyrie muzzle")
	for index = 1, 3 do
		assert(finite(event.origin[index]), "Invalid Valkyrie muzzle coordinate")
	end
	if event.weapon == "laser" then
		assert(type(event.endpoint) == "table" and #event.endpoint == 3 and type(event.hit) == "boolean", "Invalid laser impact")
		for index = 1, 3 do
			assert(finite(event.endpoint[index]), "Invalid laser impact coordinate")
		end
	end
	Weapons.effect(v, event)
end

Valkyrie.summary = function (v)
	local maximum = math.sqrt(Settings.forward_speed^2 + Settings.strafe_speed^2 + Settings.lift_speed^2)
	return string.format("%.1f km/h", v.speed * 3.6), string.format("%.1f km/h", maximum * 3.6)
end

Valkyrie.status = function (v, time)
	local rows = {}
	for _, action in ipairs({ "laser", "rocket" }) do
		local remaining = math.max(0, v["next_" .. action] - time)
		local rounds = v[action .. "_rounds"]
		local reloading = rounds == 0 and remaining > 0
		rows[#rows + 1] = {
			action = action,
			label = string.format("%s %d/%d", mod:localize("hud_" .. action), rounds, Settings[action .. "_capacity"]),
			text = remaining == 0 and mod:localize("hud_ready") or mod:localize(reloading and "hud_reload" or "hud_cooldown", remaining),
			progress = math.clamp(1 - remaining / Settings[action .. (reloading and "_reload" or "_interval")], 0, 1),
		}
	end
	return rows
end

return Valkyrie
