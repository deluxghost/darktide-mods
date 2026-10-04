local mod = get_mod("Creeper")

local Motion = mod:io_dofile("Creeper/scripts/mods/Creeper/motion")
local Outline = mod:io_dofile("Creeper/scripts/mods/Creeper/outline")
local Audio = mod:io_dofile("Creeper/scripts/mods/Creeper/audio")
local BREED_NAME = "chaos_poxwalker_bomber"
local ASSETS = {
	creeper = { id = "unit_creeper", engine_type = "unit" },
	parent = { id = "unit_poxburster", engine_type = "unit" },
	explosion = { id = "particles_explosion", engine_type = "particles" },
	audio = { id = "wwise_event_creeper", engine_type = "wwise_event" },
}
local RETAIL_UNIT = "content/characters/enemy/chaos_poxwalker_bomber/third_person/base"
local visuals = {}
local tickets = {}
local assets = {}
local custom_assets
local package_manager
local scan_timer = 0
local hooked_explosions = setmetatable({}, { __mode = "k" })
mod.visuals = visuals
mod.assets = assets

local function destroy(parent, restore)
	local record = visuals[parent]
	Audio.remove(parent)
	if not record then return end
	visuals[parent] = nil
	if Unit.alive(record.unit) then
		World.destroy_unit(record.world, record.unit)
	end
	if restore and Unit.alive(parent) then
		Unit.set_unit_objects_visibility(parent, true, false)
		for _, unit in ipairs(record.gear) do
			if Unit.alive(unit) then
				Unit.set_unit_objects_visibility(unit, true, true)
			end
		end
	end
end

local function clear(world, restore)
	for parent, record in pairs(visuals) do
		if not world or record.world == world then
			destroy(parent, restore)
		end
	end
end

local function attach(parent)
	if visuals[parent] or not assets.creeper or not assets.explosion or not assets.audio or not Unit.alive(parent) then return end
	local unit_data = ScriptUnit.has_extension(parent, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	if not breed or breed.name ~= BREED_NAME then return end
	local world = Unit.world(parent)
	local visual = World.spawn_unit_ex(world, assets.creeper.primary.name, nil, Unit.world_position(parent, 1), Quaternion.flat_no_roll(Unit.world_rotation(parent, 1)))
	local record = Motion.create(parent, visual, breed, unit_data)
	record.gear = {}
	local loadout = ScriptUnit.has_extension(parent, "visual_loadout_system")
	if loadout then
		for _, slot in pairs(loadout:slots()) do
			if slot.unit and Unit.alive(slot.unit) then
				Unit.set_unit_objects_visibility(slot.unit, false, true)
				record.gear[#record.gear + 1] = slot.unit
			end
		end
	end
	Unit.set_unit_objects_visibility(parent, false, false)
	visuals[parent] = record
end

local function scan()
	local state = Managers.state
	local spawner = state and state.minion_spawn
	if spawner then
		for _, unit in pairs(spawner:spawned_minions()) do attach(unit) end
	end
	local husks = state and state.unit_spawner and state.unit_spawner._husk_units
	for unit in pairs(husks or {}) do attach(unit) end
end

local function release()
	clear(nil, true)
	if custom_assets then
		for _, ticket in pairs(tickets) do
			local ok, err = custom_assets.release(ticket)
			assert(ok, err)
		end
	end
	table.clear(tickets)
	table.clear(assets)
	Audio.clear()
	package_manager = nil
end

local function acquire()
	if package_manager == Managers.package and next(tickets) then return end
	custom_assets = assert(get_mod("CustomAssets"), "Creeper requires Custom Assets")
	assert(custom_assets.is_api_compatible(1), "Creeper requires Custom Assets API 1")
	package_manager = Managers.package
	for name, definition in pairs(ASSETS) do
		local ticket, err = custom_assets.acquire(mod, "Creeper:" .. definition.id, function(_, asset, load_error)
			assert(not load_error, load_error)
			assert(asset.primary.engine_type == definition.engine_type, "Unexpected Creeper asset type")
			assets[name] = asset
			scan()
		end)
		assert(ticket, err)
		tickets[name] = ticket
	end
end

Audio.install(assets)

mod:hook(World, "spawn_unit_ex", function(func, world, name, ...)
	if name == RETAIL_UNIT then
		assert(assets.parent, "Creeper gameplay unit package is not loaded")
		name = assets.parent.primary.name
	end
	return func(world, name, ...)
end)

local function start_fuse(unit)
	local record = visuals[unit]
	if not record then return end
	record.fuse_start = Managers.time:time("gameplay")
	record.fuse_duration = 1.5
end

mod:hook("MinionSpawnManager", "spawn_minion", function(func, self, ...)
	local unit = func(self, ...)
	attach(unit)
	return unit
end)

mod:hook_safe("UnitSpawnerManager", "spawn_husk_unit", function(self, id)
	attach(self:unit(id))
end)

mod:hook_safe("UnitSpawnerManager", "mark_for_deletion", function(_, unit)
	destroy(unit, false)
end)

mod:hook_safe("OutlineSystem", "update", function(self)
	Outline.sync(visuals, self._unit_extension_data)
end)

mod:hook("WoundsExtension", "add_wounds", function(func, self, ...)
	if self._breed.name == BREED_NAME then return end
	return func(self, ...)
end)

mod:hook("MinionGibbing", "gib", function(func, self, ...)
	if self._breed.name == BREED_NAME then return false end
	return func(self, ...)
end)

mod:hook("UnitSpawnerManager", "_world_delete_units", function(func, self, units, count, ...)
	for i = 1, count do destroy(units[i], false) end
	return func(self, units, count, ...)
end)

mod:hook("WorldManager", "destroy_world", function(func, self, world, ...)
	if self.locked then return func(self, world, ...) end
	local resolved = type(world) == "string" and self:world(world) or world
	clear(resolved, false)
	return func(self, world, ...)
end)

mod:hook_safe("MinionAnimationExtension", "anim_event", function(self, event)
	if event == "attack_lunge" then start_fuse(self._unit) end
end)

mod:hook_safe("AnimationSystem", "rpc_minion_anim_event", function(_, _, id, event)
	local unit = Managers.state.unit_spawner:unit(id)
	if visuals[unit] and event == Unit.index_by_animation_event(unit, "attack_lunge") then
		start_fuse(unit)
	end
end)

mod:hook_require("scripts/utilities/attack/explosion", function(target)
	if hooked_explosions[target] then return end
	hooked_explosions[target] = true
	mod:hook(target, "create_husk_explosion", function(func, world, physics, wwise, owner, template, position, ...)
		if not assets.explosion or (template.name ~= "poxwalker_bomber" and template.name ~= "poxwalker_bomber_mild") then
			return func(world, physics, wwise, owner, template, position, ...)
		end
		local visual_template = table.clone(template)
		visual_template.vfx = { assets.explosion.primary.name }
		if mod:get("replace_explosion_sound") then
			assert(assets.audio, "Creeper audio package is not loaded")
			visual_template.sfx = { "wwise/events/mods/creeper/play_creeper_explode" .. math.random(1, 4) }
		end
		func(world, physics, wwise, owner, visual_template, position, ...)
		local record = visuals[owner]
		if record then
			Audio.stop_fuse(owner)
			Unit.set_unit_objects_visibility(record.unit, false, true)
			record.exploded = true
		end
	end)
end)

mod.update = function(dt)
	if not mod:is_enabled() then return end
	if package_manager ~= Managers.package then
		release()
		acquire()
	end
	local t = next(visuals) and Managers.time:time("gameplay")
	for parent, record in pairs(visuals) do
		if not Unit.alive(parent) then
			destroy(parent, false)
		elseif not record.exploded and dt > 0 then
			Motion.update(parent, record, dt, t)
		end
	end
	scan_timer = scan_timer + dt
	if scan_timer >= 0.5 then
		scan_timer = 0
		scan()
	end
end

mod.on_all_mods_loaded = function()
	if mod:is_enabled() then acquire() end
end
mod.on_setting_changed = function(id)
	if id == "enable_alarm" then Audio.update_alarm() end
end
mod.on_unload = release
