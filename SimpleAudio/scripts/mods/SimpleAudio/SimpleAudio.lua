local mod = get_mod("SimpleAudio")

local file_glob = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/file/glob")
local runtime = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/runtime/native")
local file_audio = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/file/playback")
local game_audio = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise/playback")
local game_hooks = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise/hooks")

local initialized, initialize_error = runtime.initialize()

if not initialized then
	error(string.format("Failed to initialize SimpleAudio runtime: %s", initialize_error))
end

mod.play = game_audio.play
mod.play_file = file_audio.play_file
mod.stop_file = runtime.stop
mod.is_file_playing = runtime.is_playing
mod.glob = file_glob.glob
mod.hook_sound = game_hooks.hook_sound
mod.silence_sounds = game_hooks.silence_sounds
mod.unsilence_sounds = game_hooks.unsilence_sounds
mod.is_sound_silenced = game_hooks.is_sound_silenced

mod.on_all_mods_loaded = function()
	game_hooks.install()
end

mod.update = function(dt)
	runtime.update(dt)
end

mod.on_unload = function()
	runtime.shutdown()
end
