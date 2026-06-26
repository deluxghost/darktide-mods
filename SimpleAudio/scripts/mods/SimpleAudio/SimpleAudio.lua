local mod = get_mod("SimpleAudio")

local file_glob = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/files/glob")
local native_backend = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/backend/native")
local local_audio = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback/local_audio")
local game_audio = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise/playback")
local game_hooks = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise/hooks")

mod.play = game_audio.play
mod.play_file = local_audio.play_file
mod.stop_file = native_backend.stop
mod.is_file_playing = native_backend.is_playing
mod.glob = file_glob.glob
mod.hook_sound = game_hooks.hook_sound
mod.silence_sounds = game_hooks.silence_sounds
mod.unsilence_sounds = game_hooks.unsilence_sounds
mod.is_sound_silenced = game_hooks.is_sound_silenced

mod.on_all_mods_loaded = function()
	game_hooks.install()
end

mod.update = function(dt)
	native_backend.update(dt)
end

mod.on_unload = function()
	native_backend.shutdown()
end
