local context = {}

context.mod_name = function()
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

context.userdata_type = function(value)
	if type(value) ~= "userdata" then
		return nil
	end

	if Unit.alive(value) then
		return "Unit"
	elseif Vector3.is_valid(value) then
		return "Vector3"
	end
end

return context
