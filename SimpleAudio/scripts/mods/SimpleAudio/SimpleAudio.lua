local mod = get_mod("SimpleAudio")

local file_glob = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/file/glob")
local file_info = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/file/info")
local native_runtime = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/runtime/native")
local file_playback = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback/file")
local wwise_playback = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise/playback")
local wwise_hooks = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise/hooks")

local initialized, initialize_error = native_runtime.initialize()

if not initialized then
	error(string.format("Failed to initialize SimpleAudio runtime: %s", initialize_error))
end

mod.play = wwise_playback.play
mod.play_file = file_playback.play_file
mod.stop_file = native_runtime.stop
mod.is_file_playing = native_runtime.is_playing
mod.glob = file_glob.glob
mod.file_info = file_info.file_info
mod.hook_sound = wwise_hooks.hook_sound
mod.silence_sounds = wwise_hooks.silence_sounds
mod.unsilence_sounds = wwise_hooks.unsilence_sounds
mod.is_sound_silenced = wwise_hooks.is_sound_silenced

mod.on_all_mods_loaded = function()
	wwise_hooks.install()
end

mod.update = function(dt)
	native_runtime.update(dt)
end

mod.on_unload = function()
	native_runtime.shutdown()
end
