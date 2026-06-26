local mod = get_mod("SimpleAudio")

local context = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/context")

local paths = {}

paths.normalize_audio_path = function(audio_path)
	return audio_path:gsub("\\", "/"):gsub("^/", "")
end

paths.join_audio_path = function(base_path, path)
	if base_path == "" then
		return path
	end
	if path == "" then
		return base_path
	end
	if base_path:sub(-1) == "/" or base_path:sub(-1) == "\\" then
		return base_path .. path
	end

	return base_path .. "/" .. path
end

paths.resolve_audio_path = function(audio_path)
	local normalized_path = paths.normalize_audio_path(audio_path)

	if normalized_path:match("^%a:/") then
		return normalized_path
	end

	if normalized_path:sub(1, 5) == "mods/" then
		return "../" .. normalized_path
	end

	local caller_name = context.mod_name()

	if normalized_path:sub(1, #caller_name + 1) == caller_name .. "/" then
		return "../mods/" .. normalized_path
	end

	return "../mods/" .. caller_name .. "/audio/" .. normalized_path
end

paths.split_pattern_path = function(audio_path)
	local first_pattern = audio_path:find("[*?]")
	local search_end = first_pattern and first_pattern - 1 or #audio_path
	local prefix_end = 0

	for i = search_end, 1, -1 do
		if audio_path:sub(i, i) == "/" then
			prefix_end = i
			break
		end
	end

	return audio_path:sub(1, prefix_end), audio_path:sub(prefix_end + 1)
end

return paths
