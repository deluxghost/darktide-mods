local paths = {}

paths.caller_mod_name = function()
	local highest_mod_in_stack
	local highest_non_library_mod_in_stack

	for i = 2, 32 do
		local info = debug.getinfo(i, "S")

		if not info then
			break
		end

		local source = info.source:gsub("\\", "/")
		local calling_mod_name = source:match("/mods/([^/]+)/scripts/")

		if not calling_mod_name and i > 2 then
			break
		end

		if calling_mod_name and calling_mod_name ~= "dmf" then
			highest_mod_in_stack = calling_mod_name

			if calling_mod_name ~= "SimpleAudio" then
				highest_non_library_mod_in_stack = calling_mod_name
			end
		end
	end

	return highest_non_library_mod_in_stack or highest_mod_in_stack or "unknown"
end

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

	local caller_name = paths.caller_mod_name()

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
