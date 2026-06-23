local mod = get_mod("M1GalvanicRifle")

local SimpleAudio
local shot_sounds
local ping_sounds
local replacements = {}

local function resolved_event_name(fx_extension, event_name, append_husk_to_event_name)
	if append_husk_to_event_name and fx_extension:should_play_husk_effect() then
		return event_name .. "_husk"
	end

	return event_name
end

local function is_teammate(fx_extension)
	return not fx_extension._is_local_unit
end

local function register_replacement(event_name, sounds, setting_id, volume_setting_id)
	local replacement = {
		setting_id = setting_id,
		sounds = sounds,
		volume_setting_id = volume_setting_id,
	}

	replacements[event_name] = replacement
	replacements[event_name .. "_husk"] = replacement
end

local function play_replacement(fx_extension, event_name, is_teammate)
	local replacement = replacements[event_name]

	if not replacement or not mod:is_enabled() or not mod:get(replacement.setting_id) then
		return
	end

	if is_teammate and not mod:get("replace_teammate_sounds") then
		return
	end

	local unit = fx_extension._unit

	if not unit or not Unit.alive(unit) then
		return
	end

	local volume = mod:get(replacement.volume_setting_id)

	if is_teammate then
		volume = volume * mod:get("teammate_sound_volume") / 100
	end

	return replacement.sounds:play({
		audio_type = "sfx",
		volume = volume,
	}, unit)
end

local function install_hooks()
	mod:hook("PlayerUnitFxExtension", "trigger_wwise_event", function(func, fx_extension, event_name, append_husk_to_event_name, ...)
		local wwise_event_name = resolved_event_name(fx_extension, event_name, append_husk_to_event_name)
		local play_id = play_replacement(fx_extension, wwise_event_name, is_teammate(fx_extension))

		if play_id then
			return play_id
		end

		return func(fx_extension, event_name, append_husk_to_event_name, ...)
	end)

	mod:hook("PlayerUnitFxExtension", "rpc_play_player_sound", function(func, fx_extension, channel_id, game_object_id, event_id, source_id, attachment_id, append_husk_to_event_name)
		local event_name = NetworkLookup.player_character_sounds[event_id]
		local wwise_event_name = resolved_event_name(fx_extension, event_name, append_husk_to_event_name)
		local play_id = play_replacement(fx_extension, wwise_event_name, is_teammate(fx_extension))

		if play_id then
			return play_id
		end

		return func(fx_extension, channel_id, game_object_id, event_id, source_id, attachment_id, append_husk_to_event_name)
	end)
end

mod.on_all_mods_loaded = function()
	SimpleAudio = get_mod("SimpleAudio")

	if not SimpleAudio then
		mod:error(mod:localize("missing_simple_audio"))
		return
	end

	shot_sounds = SimpleAudio.glob("shot*.mp3")
	ping_sounds = SimpleAudio.glob("ping*.mp3")

	register_replacement(
		"wwise/events/weapon/play_weapon_galvanic_rifle",
		shot_sounds,
		"replace_firing_sound",
		"firing_sound_volume"
	)
	register_replacement(
		"wwise/events/weapon/play_galvanic_rifle_reload_lever_release",
		ping_sounds,
		"replace_reload_sound",
		"reload_sound_volume"
	)

	install_hooks()
end
