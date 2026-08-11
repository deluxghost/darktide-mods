local mod = get_mod("SimpleAssets")

local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_naming = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/naming")

local loading = {}

local RESOURCE_TYPE = "ivf"

local function validate_path(asset_path)
	if type(asset_path) ~= "string" then
		error(string.format("Video asset path must be a string, got %s", type(asset_path)))
	end
	if not asset_path:lower():match("%.ivf$") then
		error("Video asset path must refer to an .ivf file")
	end
end

local function start_video(request)
	return native_runtime.video_load(request.name, request.path)
end

loading.load_video = function(name, asset_path)
	validate_path(asset_path)

	local resource_name = resource_naming.get_resource_name("video", name)
	local request = resource_loading.prepare(RESOURCE_TYPE, resource_name, asset_path)

	return resource_loading.load_prepared(request, start_video)
end

return loading
