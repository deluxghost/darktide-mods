local mod = get_mod("SimpleAssets")

local context = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/context")

local naming = {}

local RESOURCE_PREFIX = "simple_assets"
local MAX_RESOURCE_NAME_BYTES = 255

local function validate_resource_type(resource_type)
	if type(resource_type) ~= "string" or not resource_type:match("^[a-z][a-z0-9_]*$") then
		error("Resource type must use lowercase letters, digits, and underscores")
	end
end

local function validate_local_name(local_name)
	if type(local_name) ~= "string" then
		error(string.format("Resource local name must be a string, got %s", type(local_name)))
	end
	if local_name == "" then
		error("Resource local name must not be empty")
	end
	if not local_name:match("^[a-z0-9_./-]+$") then
		error("Resource local name must use lowercase letters, digits, underscores, hyphens, dots, and forward slashes")
	end
	if local_name:sub(1, 1) == "/" or local_name:sub(-1) == "/" or local_name:find("//", 1, true) then
		error("Resource local name must contain non-empty path segments")
	end

	for segment in local_name:gmatch("[^/]+") do
		if segment == "." or segment == ".." then
			error("Resource local name must not contain . or .. segments")
		end
	end
end

local function calling_mod_name()
	local mod_name = context.mod_name()

	if mod_name == "unknown" then
		error("Could not determine the calling mod for the resource name")
	end

	return mod_name
end

local function type_prefix(resource_type)
	validate_resource_type(resource_type)

	return string.format("%s/%s/%s/", RESOURCE_PREFIX, calling_mod_name(), resource_type)
end

naming.get_resource_name = function(resource_type, local_name)
	validate_local_name(local_name)

	local name = type_prefix(resource_type) .. local_name

	if #name > MAX_RESOURCE_NAME_BYTES then
		error(string.format("Resource name must not exceed %d UTF-8 bytes", MAX_RESOURCE_NAME_BYTES))
	end

	return name
end

return naming
