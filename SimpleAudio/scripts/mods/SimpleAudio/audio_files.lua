local mod = get_mod("SimpleAudio")

local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/paths")
local platform = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform")
local utilities = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/utilities")

local audio_files = {}

local GlobResult = {}
GlobResult.__index = GlobResult

function GlobResult:count()
	return #self._files
end

function GlobResult:list()
	return utilities.copy_list(self._files)
end

function GlobResult:random()
	local files = self._files
	local count = #files

	if count == 0 then
		error(string.format("No audio files matched pattern: %s", self._pattern))
	end

	return files[math.random(1, count)]
end

function GlobResult:play(playback_settings, unit_or_position)
	return mod.play_file(self:random(), playback_settings, unit_or_position)
end

audio_files.glob = function(pattern)
	if type(pattern) ~= "string" then
		error(string.format("Audio glob pattern must be a string, got %s", type(pattern)))
	end

	local normalized_pattern = paths.normalize_audio_path(pattern)
	local caller_base_path, relative_pattern = paths.split_pattern_path(normalized_pattern)
	local resolved_base_path = paths.resolve_audio_path(caller_base_path)
	local search_pattern = paths.join_audio_path(resolved_base_path, relative_pattern)
	local files = platform.find_files(search_pattern, caller_base_path)

	if not files or #files == 0 then
		error(string.format("No audio files matched pattern: %s", normalized_pattern))
	end

	return setmetatable({
		_pattern = normalized_pattern,
		_files = files,
	}, GlobResult)
end

return audio_files
