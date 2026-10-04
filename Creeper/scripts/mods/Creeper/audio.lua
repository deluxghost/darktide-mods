local mod = get_mod("Creeper")
local Audio = {}
local sources = {}
local sounds = {}
local ALARM_EVENT = "wwise/events/minions/play_enemy_combat_poxwalker_bomber_beep_loop"
local FUSE_EVENT = "wwise/events/minions/play_minion_poxwalker_bomber_wind_up"
local STOP_FUSE_EVENT = "wwise/events/minions/stop_minion_poxwalker_bomber_wind_up"
local CUSTOM_FUSE_EVENT = "wwise/events/mods/creeper/play_creeper_fuse"

function Audio.install(assets)
	mod:hook(WwiseWorld, "make_manual_source", function(func, world, unit, ...)
		local id = func(world, unit, ...)
		sources[id] = unit
		return id
	end)
	mod:hook(WwiseWorld, "destroy_manual_source", function(func, world, id)
		sources[id] = nil
		return func(world, id)
	end)
	mod:hook(WwiseWorld, "trigger_resource_event", function(func, world, event, ...)
		if event ~= ALARM_EVENT and event ~= FUSE_EVENT and event ~= STOP_FUSE_EVENT then return func(world, event, ...) end
		local first, second = ...
		local source = type(first) == "boolean" and second or first
		local unit = sources[source] or source
		if event == STOP_FUSE_EVENT then
			Audio.stop_fuse(unit)
			return func(world, event, ...)
		end
		local record = sounds[unit]
		if not record then
			record = {}
			sounds[unit] = record
		end
		if event == ALARM_EVENT then
			record.alarm_world, record.alarm_source = world, source
			if not mod:get("enable_alarm") then return end
		elseif mod:get("replace_fuse_sound") then
			assert(assets.audio, "Creeper audio package is not loaded")
			event = CUSTOM_FUSE_EVENT
		end
		local playing_id, source_id = func(world, event, ...)
		if event == ALARM_EVENT then record.alarm_id = playing_id end
		if event == CUSTOM_FUSE_EVENT then record.fuse_id, record.fuse_world = playing_id, world end
		return playing_id, source_id
	end)
end

function Audio.stop_fuse(unit)
	local record = sounds[unit]
	if record and record.fuse_id then
		WwiseWorld.stop_event(record.fuse_world, record.fuse_id)
		record.fuse_id = nil
	end
end

function Audio.update_alarm()
	for parent, record in pairs(sounds) do
		if record.alarm_world and HEALTH_ALIVE[parent] then
			if record.alarm_id then WwiseWorld.stop_event(record.alarm_world, record.alarm_id) end
			record.alarm_id = nil
			if mod:get("enable_alarm") then
				record.alarm_id = WwiseWorld.trigger_resource_event(record.alarm_world, ALARM_EVENT, record.alarm_source)
			end
		end
	end
end

function Audio.remove(unit)
	Audio.stop_fuse(unit)
	sounds[unit] = nil
end

function Audio.clear()
	table.clear(sources)
	table.clear(sounds)
end

return Audio
