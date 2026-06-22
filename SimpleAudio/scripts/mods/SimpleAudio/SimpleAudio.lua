local mod = get_mod("SimpleAudio")

local audio_files = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/audio_files")
local playback = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback")
local platform = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform")
local wwise_hooks = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise_hooks")

mod.play_file = playback.play_file
mod.stop_file = platform.stop_process
mod.glob = audio_files.glob
mod.hook_sound = wwise_hooks.hook_sound

mod.on_all_mods_loaded = function()
	wwise_hooks.install()
end

mod.update = function(dt)
	platform.update(dt)
end

mod.on_unload = function()
	platform.terminate_active_processes()
end
