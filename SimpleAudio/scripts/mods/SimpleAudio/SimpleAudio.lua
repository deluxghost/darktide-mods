local mod = get_mod("SimpleAudio")

local audio_files = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/audio_files")
local native_backend = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/backend/native")
local playback = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback")
local wwise_hooks = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/wwise_hooks")

mod.play_file = playback.play_file
mod.stop_file = native_backend.stop
mod.file_status = native_backend.file_status
mod.is_file_playing = native_backend.is_playing
mod.glob = audio_files.glob
mod.hook_sound = wwise_hooks.hook_sound

mod.on_all_mods_loaded = function()
	wwise_hooks.install()
end

mod.update = function(dt)
	native_backend.update(dt)
end

mod.on_unload = function()
	native_backend.shutdown()
end
