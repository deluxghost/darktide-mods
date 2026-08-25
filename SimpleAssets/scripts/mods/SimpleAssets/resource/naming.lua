local mod = get_mod("SimpleAssets")

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")

local naming = {}

local function resource_name(virtual_path)
	local name = virtual_path:match("^(.+)%.[^./]+$")

	if not name then
		error("Resource asset path must have a file extension")
	end

	return name
end

naming.get_resource_name = function(asset_path)
	return resource_name(paths.get_asset_path(asset_path))
end

naming.get_name = resource_name

return naming
