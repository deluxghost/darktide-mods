local mod = get_mod("M1GalvanicRifle")
local VisualLoadoutExtractData = require("scripts/extension_systems/visual_loadout/utilities/visual_loadout_extract_data")

local SimpleAudio
local shot_sounds
local ping_sounds
local ping_drop_sounds
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

local function register_replacement(event_name, sounds, setting_id, volume_setting_id, source_alias, get_sounds)
	local replacement = {
		setting_id = setting_id,
		sounds = sounds,
		get_sounds = get_sounds,
		source_alias = source_alias,
		volume_setting_id = volume_setting_id,
	}

	replacements[event_name] = replacement
	replacements[event_name .. "_husk"] = replacement
end

local function replacement_source_name(fx_extension, replacement)
	local visual_loadout_extension = fx_extension._visual_loadout_extension
	if not visual_loadout_extension then
		return
	end

	local slot_name
	if visual_loadout_extension.currently_wielded_slot then
		slot_name = visual_loadout_extension:currently_wielded_slot()
	else
		slot_name = visual_loadout_extension._wielded_slot
	end

	local fx_sources = slot_name and visual_loadout_extension:source_fx_for_slot(slot_name)

	return fx_sources and fx_sources[replacement.source_alias]
end

local function source_position(fx_extension, source_name, optional_attachment_name)
	if not source_name then
		return
	end

	local attachment_name = optional_attachment_name or VisualLoadoutExtractData.ROOT_ATTACH_NAME
	local spawners = fx_extension._vfx_spawners
	local spawner = spawners and spawners[source_name] and spawners[source_name][attachment_name]

	if not spawner or not spawner.unit or not Unit.alive(spawner.unit) then
		return
	end

	local pose = fx_extension:vfx_spawner_pose(source_name, attachment_name)

	return Matrix4x4.translation(pose)
end

local function play_replacement(fx_extension, event_name, is_teammate, source_name, optional_attachment_name)
	local replacement = replacements[event_name]

	if not replacement or not mod:is_enabled() or not mod:get(replacement.setting_id) then
		return nil, false
	end

	if is_teammate and not mod:get("replace_teammate_sounds") then
		return nil, false
	end

	local position = source_position(fx_extension, source_name or replacement_source_name(fx_extension, replacement), optional_attachment_name)

	if not position then
		return nil, true
	end

	local volume = mod:get(replacement.volume_setting_id)

	if is_teammate then
		volume = volume * mod:get("teammate_sound_volume") / 100
	end

	local sounds = replacement.get_sounds and replacement.get_sounds() or replacement.sounds

	return sounds:play({
		audio_type = "sfx",
		volume = volume,
	}, position), true
end

local function get_reload_sounds()
	return mod:get("enable_clip_drop_sound") and ping_drop_sounds or ping_sounds
end

local function is_resimulating(fx_extension)
	local unit_data_extension = fx_extension._unit_data_extension
	return unit_data_extension and unit_data_extension.is_resimulating
end

local function play_gear_replacement(fx_extension, sound_alias, external_properties, source_name, optional_attachment_name)
	local visual_loadout_extension = fx_extension._visual_loadout_extension
	if not visual_loadout_extension then
		return nil, false
	end

	local resolved, event_name, has_husk_events = visual_loadout_extension:resolve_gear_sound(sound_alias, external_properties)
	if not resolved then
		return nil, false
	end

	local wwise_event_name = resolved_event_name(fx_extension, event_name, has_husk_events)

	return play_replacement(fx_extension, wwise_event_name, is_teammate(fx_extension), source_name, optional_attachment_name)
end

local function install_hooks()
	mod:hook("PlayerUnitFxExtension", "trigger_gear_wwise_event", function(func, fx_extension, sound_alias, external_properties, ...)
		if is_resimulating(fx_extension) then
			return func(fx_extension, sound_alias, external_properties, ...)
		end

		local play_id, handled = play_gear_replacement(fx_extension, sound_alias, external_properties)
		if handled then
			return play_id
		end

		return func(fx_extension, sound_alias, external_properties, ...)
	end)

	mod:hook("PlayerUnitFxExtension", "trigger_gear_wwise_event_with_source", function(func, fx_extension, sound_alias, external_properties, source_name, sync_to_clients, include_client, optional_attachment_name)
		if is_resimulating(fx_extension) then
			return func(fx_extension, sound_alias, external_properties, source_name, sync_to_clients, include_client, optional_attachment_name)
		end

		local play_id, handled = play_gear_replacement(fx_extension, sound_alias, external_properties, source_name, optional_attachment_name)
		if handled then
			return play_id
		end

		return func(fx_extension, sound_alias, external_properties, source_name, sync_to_clients, include_client, optional_attachment_name)
	end)

	mod:hook("PlayerUnitFxExtension", "rpc_play_player_sound", function(func, fx_extension, channel_id, game_object_id, event_id, source_id, attachment_id, append_husk_to_event_name)
		local event_name = NetworkLookup.player_character_sounds[event_id]
		local wwise_event_name = resolved_event_name(fx_extension, event_name, append_husk_to_event_name)
		local source_name = NetworkLookup.player_character_fx_sources[source_id]
		local attachment_name = NetworkLookup.player_attachment_names[attachment_id]
		local play_id, handled = play_replacement(fx_extension, wwise_event_name, is_teammate(fx_extension), source_name, attachment_name)

		if handled then
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

	shot_sounds = SimpleAudio.glob("shot/*.mp3")
	ping_sounds = SimpleAudio.glob("ping/*.mp3")
	ping_drop_sounds = SimpleAudio.glob("ping_drop/*.mp3")

	register_replacement(
		"wwise/events/weapon/play_weapon_galvanic_rifle",
		shot_sounds,
		"replace_firing_sound",
		"firing_sound_volume",
		"_muzzle"
	)
	register_replacement(
		"wwise/events/weapon/play_galvanic_rifle_reload_lever_release",
		ping_sounds,
		"replace_reload_sound",
		"reload_sound_volume",
		"_mag_well",
		get_reload_sounds
	)

	install_hooks()
end
