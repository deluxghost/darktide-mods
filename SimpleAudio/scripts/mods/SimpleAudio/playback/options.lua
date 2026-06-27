local playback_options = {}

local AUDIO_TYPE_VOLUME = {
	dialogue = function()
		return ((Application.user_setting("sound_settings", "options_vo_trim") or 0) / 10) + 1
	end,
	music = function()
		return (Application.user_setting("sound_settings", "options_music_slider") or 100) / 100
	end,
	sfx = function()
		return (Application.user_setting("sound_settings", "options_sfx_slider") or 100) / 100
	end,
}

local function volume_adjustment(audio_type)
	local master_volume = (Application.user_setting("sound_settings", "option_master_slider") or 100) / 100

	if audio_type == nil then
		return master_volume
	end

	local type_volume = AUDIO_TYPE_VOLUME[audio_type]

	if not type_volume then
		error(string.format("Unsupported audio type: %s", tostring(audio_type)))
	end

	return master_volume * type_volume()
end

playback_options.create = function(playback_settings, spatial_volume, spatial_data)
	local volume_multiplier = playback_settings.volume and playback_settings.volume / 100 or 1
	local base_volume_gain = volume_adjustment(playback_settings.audio_type) * volume_multiplier

	return {
		audio_type = playback_settings.audio_type,
		base_volume_gain = base_volume_gain,
		duration = playback_settings.duration,
		filters = playback_settings.filters,
		loop = playback_settings.loop,
		on_finished = playback_settings.on_finished,
		on_update = playback_settings.on_update,
		pos = playback_settings.pos,
		spatial_data = spatial_data,
		volume_gain = (spatial_volume or 100) / 100 * base_volume_gain,
	}
end

return playback_options
