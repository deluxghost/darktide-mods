local mod = get_mod("MustSayForTheEmperor")
local DialogueQueries = require("scripts/extension_systems/dialogue/dialogue_queries")
local dialogue_data = mod:io_dofile("MustSayForTheEmperor/scripts/mods/MustSayForTheEmperor/dialogue_data")
local SHOUT_RULE_NAME = "com_wheel_vo_for_the_emperor"

local function personality_from_event(sound_event)
	return sound_event and string.match(sound_event, "^loc_([%w_]+)__")
end

local function is_known_personality(personality)
	return personality ~= nil and dialogue_data[personality] ~= nil
end

local function shout_data_for_personality(personality)
	if not is_known_personality(personality) then
		return nil
	end

	local personality_data = dialogue_data[personality]

	return mod:get("prefer_for_the_emperor") and personality_data.prefer_fte or personality_data.all
end

local function choose_shout_event(personality)
	local shout = shout_data_for_personality(personality)
	if not shout then
		return nil, nil
	end

	local index = DialogueQueries.get_dialogue_event_index(shout)
	if not index then
		error(string.format("Missing %s event index for personality %s", SHOUT_RULE_NAME, personality))
	end

	local sound_event = shout.sound_events[index]
	local duration = shout.sound_events_duration and shout.sound_events_duration[index]

	if not sound_event then
		error(string.format("Missing %s sound event %s for personality %s", SHOUT_RULE_NAME, tostring(index), personality))
	end

	return sound_event, duration
end

local function replacement_for_sound_event(dialogue_extension, sound_event)
	if not sound_event or not dialogue_extension:is_a_player() then
		return nil, nil
	end

	local personality = personality_from_event(sound_event)
	if not is_known_personality(personality) then
		return nil, nil
	end

	return choose_shout_event(personality)
end

mod:hook("DialogueExtension", "get_dialogue_event", function (func, self, dialogue_name, dialogue_index)
	local sound_event, subtitles_event, duration = func(self, dialogue_name, dialogue_index)

	local shout_event, shout_duration = replacement_for_sound_event(self, sound_event)
	if not shout_event then
		return sound_event, subtitles_event, duration
	end

	return shout_event, shout_event, shout_duration or duration
end)
