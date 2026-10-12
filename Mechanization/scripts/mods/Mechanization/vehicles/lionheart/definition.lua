local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/lionheart/settings")
local Controller = mod.load_module("vehicles/lionheart/controller")
local Weapons = mod.load_module("vehicles/lionheart/weapons")
local Lionheart = {
	id = "lionheart",
	name = "vehicle_lionheart",
	max_health = 50000,
	settings = Settings,
	controller = Controller,
	crosshairs = {
		unarmed = { crosshair_type = "cross", spread_scalar = 0 },
		main = { crosshair_type = "cross", spread_scalar = 0 },
		front = { crosshair_type = "cross", spread_scalar = 0 },
	},
	controls = {
		throttle = { "move_forward", "move_backward" },
		steer = { "move_right", "move_left" },
	},
	camera = {
		distance = 14,
		offset = 0,
		height = 7,
		min_pitch = math.rad(-30),
		max_pitch = math.rad(40),
		vertical_fov = math.rad(60),
	},
	contacts = {
		damage = 2000,
		tick_interval = 0.35,
		contact_margin = 0.2,
		push_speed = 8,
		speed_multiplier = { ordinary = 1, elite = 0.85, ogryn = 0.65, boss = 0.25 },
	},
	seats = {
		{ position = { 0, 0, 1 }, yaw = 0, visible = false, protected = true, movement = true, actions = { "main", "front" } },
		{ position = { 0, 0, 1 }, yaw = 0, visible = false, protected = true, movement = false, actions = { "main" } },
		{ position = { 0, 0, 1 }, yaw = 0, visible = false, protected = true, movement = false, actions = { "front" } },
		{ position = { 0, 0, 1 }, yaw = 0, visible = false, protected = true, movement = false, actions = {} },
	},
	actions = {
		main = "action_one_hold",
		front = "action_two_hold",
	},
}

Lionheart.snapshot = function (v, time)
	local normal = v.normal:unbox()

	return {
		normal = { normal.x, normal.y, normal.z },
		turret_yaw = v.turret_yaw,
		pitch = v.pitch,
		front_yaw = v.front_yaw,
		front_pitch = v.front_pitch,
		speed = v.speed,
		turn = v.turn,
		left_speed = v.left_speed,
		right_speed = v.right_speed,
		rounds = v.rounds,
		front_rounds = v.front_rounds,
		main_wait = math.max(0, v.next_shot - time),
		front_wait = math.max(0, v.next_front_shot - time),
	}
end

Lionheart.validate_state = function (state, finite)
	assert(type(state) == "table" and type(state.normal) == "table" and #state.normal == 3, "Invalid Lionheart state")
	for index = 1, 3 do
		assert(finite(state.normal[index]), "Invalid Lionheart ground normal")
	end
	for _, key in ipairs({
		"turret_yaw", "pitch", "front_yaw", "front_pitch", "speed", "turn", "left_speed", "right_speed",
		"rounds", "front_rounds", "main_wait", "front_wait",
	}) do
		assert(finite(state[key]), "Invalid Lionheart field: " .. key)
	end
end

Lionheart.receive_state = function (v, state, time)
	v.rounds = state.rounds
	v.front_rounds = state.front_rounds
	v.next_shot = time + state.main_wait
	v.next_front_shot = time + state.front_wait
end

Lionheart.interpolate = function (v, state)
	v.normal:store(Vector3(unpack(state.normal)))
	v.turret_yaw = state.turret_yaw
	v.pitch = state.pitch
	v.front_yaw = state.front_yaw
	v.front_pitch = state.front_pitch
	v.speed = state.speed
	v.turn = state.turn
	v.left_speed = state.left_speed
	v.right_speed = state.right_speed
end

Lionheart.update = function (v, time, emit)
	local pending = Weapons.update(Controller, v, time)
	if pending then
		Weapons.effect(Controller, v, pending)
		emit(v, pending)
	end
	for _, action in ipairs({ "main", "front" }) do
		local control = v.input.actions[action]
		if control and control.pressed then
			local event = Weapons.fire(Controller, v, action == "front", time, control.unit)
			if event then
				Weapons.effect(Controller, v, event)
				emit(v, event)
			end
		end
	end
end

Lionheart.receive_event = function (v, event, finite)
	assert(type(event) == "table" and (event.weapon == "main" or event.weapon == "front"), "Invalid Lionheart weapon")
	assert(event.phase == "fire" or (event.weapon == "main" and (event.phase == "prepare" or event.phase == "impact")), "Invalid Lionheart weapon phase")
	if event.weapon == "main" and event.phase ~= "impact" then
		Weapons.effect(Controller, v, event)
		return
	end
	assert(type(event.hit) == "boolean" and type(event.endpoint) == "table" and #event.endpoint == 3, "Invalid Lionheart impact")
	for index = 1, 3 do
		assert(finite(event.endpoint[index]), "Invalid Lionheart impact coordinate")
	end
	assert(event.phase ~= "impact" or event.hit, "Invalid Lionheart shell impact")
	Weapons.effect(Controller, v, event)
end

local function weapon_status (v, weapon, time)
	local remaining = math.max(0, v[weapon.ready_at] - time)
	local rounds = v[weapon.rounds]
	local reloading = rounds == 0 and remaining > 0
	local state = mod:localize("hud_ready")
	if remaining > 0 then
		state = mod:localize(reloading and "hud_reload" or "hud_cooldown", remaining)
	end

	return {
		action = weapon.action,
		label = string.format("%s %d/%d", mod:localize(weapon.label), rounds, weapon.capacity),
		text = state,
		progress = math.clamp(1 - remaining / (reloading and weapon.reload or weapon.interval), 0, 1),
	}
end

local STATUS_WEAPONS = {
	{
		action = "main",
		label = "hud_main",
		rounds = "rounds",
		ready_at = "next_shot",
		capacity = Settings.magazine_size,
		reload = Settings.reload_time,
		interval = Settings.reload_time,
	},
	{
		action = "front",
		label = "hud_front",
		rounds = "front_rounds",
		ready_at = "next_front_shot",
		capacity = Settings.front_magazine_size,
		reload = Settings.front_reload_time,
		interval = Settings.front_shot_interval,
	},
}

Lionheart.summary = function (v)
	local max_speed = math.max(Settings.forward_speed, Settings.reverse_speed)
	return string.format("%.1f km/h", math.abs(v.speed) * 3.6), string.format("%.1f km/h", max_speed * 3.6)
end

Lionheart.status = function (v, time)
	local rows = {}
	for index, weapon in ipairs(STATUS_WEAPONS) do
		rows[index] = weapon_status(v, weapon, time)
	end
	return rows
end

return Lionheart
