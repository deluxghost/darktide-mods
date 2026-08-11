local mod = get_mod("SimpleAssets")

local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_naming = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/naming")

local loading = {}

local RESOURCE_TYPE = "mouse_cursor"
local MAX_UINT32 = 4294967295

local function validate_path(asset_path)
	if type(asset_path) ~= "string" then
		error(string.format("Mouse cursor asset path must be a string, got %s", type(asset_path)))
	end
	if not asset_path:lower():match("%.png$") then
		error("Mouse cursor asset path must refer to a .png file")
	end
end

local function validate_hotspot(value, name)
	if type(value) ~= "number" or value < 0 or value > MAX_UINT32 or value % 1 ~= 0 then
		error(string.format("%s must be an unsigned 32-bit integer", name))
	end
end

local function start_mouse_cursor(request)
	return native_runtime.mouse_cursor_load(
		request.name,
		request.path,
		request.hotspot_x,
		request.hotspot_y
	)
end

loading.load_mouse_cursor = function(name, asset_path, hotspot_x, hotspot_y)
	validate_path(asset_path)
	validate_hotspot(hotspot_x, "Mouse cursor hotspot X")
	validate_hotspot(hotspot_y, "Mouse cursor hotspot Y")

	local resource_name = resource_naming.get_resource_name("mouse_cursor", name)
	local request = resource_loading.prepare(
		RESOURCE_TYPE,
		resource_name,
		asset_path,
		string.format("%u,%u", hotspot_x, hotspot_y)
	)

	request.hotspot_x = hotspot_x
	request.hotspot_y = hotspot_y

	return resource_loading.load_prepared(request, start_mouse_cursor)
end

return loading
