local mod = get_mod("SimpleAudio")

local decoder = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/backend/ffmpeg_decoder")
local mixer = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/backend/winmm_mixer")

local native = {}

native.preload = function(files)
	for i = 1, #files do
		decoder.preload(files[i])
	end
end

native.play = function(path, options)
	local source, decode_error = decoder.decode(path)

	if not source then
		return false, decode_error
	end

	local play_id, play_error = mixer.play(source, options)

	if not play_id then
		return false, play_error
	end

	return play_id
end

native.stop = function(play_id)
	return mixer.stop(play_id)
end

native.file_status = function(play_id)
	return mixer.file_status(play_id)
end

native.is_playing = function(play_id)
	return mixer.is_playing(play_id)
end

native.update = function()
	mixer.update()
end

native.shutdown = function()
	mixer.shutdown()
	decoder.shutdown()
end

return native
