local mod = get_mod("M1GalvanicRifle")

local SimpleAudio
local shot_sounds
local ping_sounds

local function replace_sound(event_name, sounds, setting_id, volume_setting_id)
	SimpleAudio.hook_sound(event_name, function(_, _, _, position_or_unit_or_id)
		if not mod:is_enabled() or not mod:get(setting_id) then
			return
		end

		sounds:play({
			audio_type = "sfx",
			volume = mod:get(volume_setting_id),
		}, position_or_unit_or_id)
		return false
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

	replace_sound(
		"wwise/events/weapon/play_weapon_galvanic_rifle",
		shot_sounds,
		"replace_firing_sound",
		"firing_sound_volume"
	)
	replace_sound(
		"wwise/events/weapon/play_galvanic_rifle_reload_lever_release",
		ping_sounds,
		"replace_reload_sound",
		"reload_sound_volume"
	)
end
