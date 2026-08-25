local mod = get_mod("SimpleAssets")

local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_replacement = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/replacement")

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
		request.path,
		request.hotspot_x,
		request.hotspot_y
	)
end

loading.load_mouse_cursor = function(asset_path, hotspot_x, hotspot_y)
	validate_path(asset_path)
	validate_hotspot(hotspot_x, "Mouse cursor hotspot X")
	validate_hotspot(hotspot_y, "Mouse cursor hotspot Y")

	local request = resource_loading.prepare(RESOURCE_TYPE, asset_path)

	request.hotspot_x = hotspot_x
	request.hotspot_y = hotspot_y

	return resource_loading.load_prepared(request, start_mouse_cursor)
end

loading.replace_mouse_cursor = function(target_resource_path, source_asset_path, hotspot_x, hotspot_y)
	validate_hotspot(hotspot_x, "Mouse cursor hotspot X")
	validate_hotspot(hotspot_y, "Mouse cursor hotspot Y")

	return resource_replacement.replace(
		RESOURCE_TYPE,
		".mouse_cursor",
		".png",
		target_resource_path,
		source_asset_path,
		function(request)
			request.hotspot_x = hotspot_x
			request.hotspot_y = hotspot_y

			return start_mouse_cursor(request)
		end,
		native_runtime.mouse_cursor_replace
	)
end

return loading
