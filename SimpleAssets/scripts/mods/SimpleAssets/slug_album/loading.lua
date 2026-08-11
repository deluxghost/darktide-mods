local mod = get_mod("SimpleAssets")

local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_naming = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/naming")

local loading = {}

local RESOURCE_TYPE = "slug_album"

local function validate_path(asset_path)
	if type(asset_path) ~= "string" then
		error(string.format("Slug album asset path must be a string, got %s", type(asset_path)))
	end
	if not asset_path:lower():match("%.slug$") then
		error("Slug album asset path must refer to a .slug file")
	end
end

loading.load_slug_album = function(name, asset_path)
	validate_path(asset_path)

	local resource_name = resource_naming.get_resource_name("slug_album", name)
	local request = resource_loading.prepare(RESOURCE_TYPE, resource_name, asset_path)

	return resource_loading.load_prepared(request)
end

return loading
