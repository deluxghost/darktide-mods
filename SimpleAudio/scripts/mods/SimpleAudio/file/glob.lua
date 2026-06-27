local mod = get_mod("SimpleAudio")

local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/paths")
local filesystem = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform/filesystem")

local glob = {}
local glob_result_state = setmetatable({}, { __mode = "k" })

local GlobResult = {}
GlobResult.__index = GlobResult
GlobResult.__metatable = false

local function get_result_state(result)
	return glob_result_state[result] or error("Invalid SimpleAudio glob result")
end

function GlobResult:count()
	return #get_result_state(self).files
end

function GlobResult:list()
	local files = get_result_state(self).files
	local copy = {}

	for i = 1, #files do
		copy[i] = files[i]
	end

	return copy
end

function GlobResult:random()
	local current_state = get_result_state(self)
	local files = current_state.files
	local count = #files

	if count == 0 then
		error(string.format("No audio files matched pattern: %s", current_state.pattern))
	end

	return files[math.random(1, count)]
end

function GlobResult:play(
	playback_settings,
	unit_or_position,
	decay,
	min_distance,
	max_distance,
	override_position,
	override_rotation
)
	return mod.play_file(
		self:random(),
		playback_settings,
		unit_or_position,
		decay,
		min_distance,
		max_distance,
		override_position,
		override_rotation
	)
end

glob.glob = function(pattern)
	if type(pattern) ~= "string" then
		error(string.format("Audio glob pattern must be a string, got %s", type(pattern)))
	end

	local normalized_pattern = paths.normalize_audio_path(pattern)
	local caller_base_path, relative_pattern = paths.split_pattern_path(normalized_pattern)
	local resolved_base_path = paths.resolve_audio_path(caller_base_path)
	local search_pattern = paths.join_audio_path(resolved_base_path, relative_pattern)
	local files = filesystem.find_files(search_pattern, caller_base_path)

	if not files or #files == 0 then
		error(string.format("No audio files matched pattern: %s", normalized_pattern))
	end

	local result = setmetatable({}, GlobResult)
	glob_result_state[result] = {
		pattern = normalized_pattern,
		files = files,
	}

	return result
end

return glob
