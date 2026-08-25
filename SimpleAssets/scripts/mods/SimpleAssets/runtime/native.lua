local mod = get_mod("SimpleAssets")

if mod._simple_assets_native_runtime then
	return mod._simple_assets_native_runtime
end

local ffi = Mods.lua.ffi

mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/cdef")

local windows = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/platform/windows")

local native = {}

local RUNTIME_PATH = "../mods/SimpleAssets/bin/simple-assets-runtime.dll"

local state = {}

local function load_runtime()
	if state.runtime then
		return state.runtime
	end

	local ok, runtime_or_error = pcall(ffi.load, windows.path(RUNTIME_PATH))

	if not ok then
		return nil, tostring(runtime_or_error)
	end

	state.runtime = runtime_or_error

	return state.runtime
end

native.runtime = load_runtime

local function runtime_string(pointer)
	if pointer == nil then
		return nil
	end

	local value = ffi.string(pointer)

	if value == "" then
		return nil
	end

	return value
end

local function runtime_or_error()
	local runtime = state.runtime

	if not runtime then
		error("SimpleAssets runtime is not initialized")
	end

	return runtime
end

native.initialize = function()
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local ok = runtime.SimpleAssetsRuntime_Start()

	if ok == 0 then
		return false, runtime_string(runtime.SimpleAssetsRuntime_LastError()) or "SimpleAssets runtime failed to start"
	end

	state.game_dir = runtime_string(runtime.SimpleAssetsRuntime_GameDir())
	state.user_dir = runtime_string(runtime.SimpleAssetsRuntime_UserDir())

	return true
end

native.game_dir = function()
	if state.game_dir then
		return state.game_dir
	end

	local runtime = runtime_or_error()
	local game_dir = runtime_string(runtime.SimpleAssetsRuntime_GameDir())

	if not game_dir then
		error("SimpleAssets runtime did not return game directory")
	end

	state.game_dir = game_dir

	return game_dir
end

native.user_dir = function()
	if state.user_dir then
		return state.user_dir
	end

	local runtime = runtime_or_error()
	local user_dir = runtime_string(runtime.SimpleAssetsRuntime_UserDir())

	if not user_dir then
		error("SimpleAssets runtime did not return user directory")
	end

	state.user_dir = user_dir

	return user_dir
end

native.asset_url = function(path)
	local runtime = runtime_or_error()

	local asset_url = runtime_string(runtime.SimpleAssetsRuntime_AssetUrl(windows.path(path)))

	if not asset_url then
		error(runtime_string(runtime.SimpleAssetsRuntime_LastError()) or "SimpleAssets runtime failed to generate asset URL")
	end

	return asset_url
end

native.canonical_asset_path = function(path)
	local runtime = runtime_or_error()
	local asset_path = runtime_string(runtime.SimpleAssetsRuntime_CanonicalAssetPath(windows.path(path)))

	if not asset_path then
		error(runtime_string(runtime.SimpleAssetsRuntime_LastError()) or
			"SimpleAssets runtime failed to canonicalize asset path")
	end

	return asset_path
end

local IMAGE_FORMATS = {
	[1] = "png",
	[2] = "jpeg",
	[3] = "dds",
}

native.detect_image_format = function(path)
	local runtime = runtime_or_error()
	local result = runtime.SimpleAssetsRuntime_DetectImageFormat(windows.path(path))

	if result < 0 then
		return nil, runtime_string(runtime.SimpleAssetsRuntime_LastError()) or
			"SimpleAssets runtime failed to detect the asset image format"
	end

	return IMAGE_FORMATS[result]
end

local function create_resource_loader(symbol, description)
	return function(path)
		local runtime = runtime_or_error()
		local result = runtime[symbol](windows.path(path))

		if result == 0 then
			return false, runtime_string(runtime.SimpleAssetsRuntime_LastError()) or
				string.format("SimpleAssets runtime failed to load %s", description)
		end

		return true
	end
end

native.animation_load = create_resource_loader("SimpleAssetsRuntime_AnimationLoad", "animation resource")
native.font_load = create_resource_loader("SimpleAssetsRuntime_FontLoad", "Slug font resource")
native.material_load = create_resource_loader("SimpleAssetsRuntime_MaterialLoad", "material resource")
native.particles_load = create_resource_loader("SimpleAssetsRuntime_ParticlesLoad", "particles resource")
native.slug_album_load = create_resource_loader("SimpleAssetsRuntime_SlugAlbumLoad", "Slug album resource")
native.texture_load = create_resource_loader("SimpleAssetsRuntime_TextureLoad", "texture resource")
native.unit_load = create_resource_loader("SimpleAssetsRuntime_UnitLoad", "unit resource")
native.video_load = create_resource_loader("SimpleAssetsRuntime_VideoLoad", "video resource")

local function create_resource_replacer(symbol, description)
	return function(target_resource_path, source_asset_path)
		local runtime = runtime_or_error()
		local result = runtime[symbol](
			windows.path(target_resource_path),
			windows.path(source_asset_path)
		)

		if result == 0 then
			return false, runtime_string(runtime.SimpleAssetsRuntime_LastError()) or
				string.format("SimpleAssets runtime failed to replace %s", description)
		end

		return true
	end
end

native.animation_replace = create_resource_replacer("SimpleAssetsRuntime_AnimationReplace", "animation resource")
native.font_replace = create_resource_replacer("SimpleAssetsRuntime_FontReplace", "font resource")
native.material_replace = create_resource_replacer("SimpleAssetsRuntime_MaterialReplace", "material resource")
native.mouse_cursor_replace = create_resource_replacer("SimpleAssetsRuntime_MouseCursorReplace", "mouse cursor resource")
native.particles_replace = create_resource_replacer("SimpleAssetsRuntime_ParticlesReplace", "particles resource")
native.slug_album_replace = create_resource_replacer("SimpleAssetsRuntime_SlugAlbumReplace", "Slug album resource")
native.texture_replace = create_resource_replacer("SimpleAssetsRuntime_TextureReplace", "texture resource")
native.unit_replace = create_resource_replacer("SimpleAssetsRuntime_UnitReplace", "unit resource")
native.video_replace = create_resource_replacer("SimpleAssetsRuntime_VideoReplace", "video resource")
native.mouse_cursor_load = function(path, hotspot_x, hotspot_y)
	local runtime = runtime_or_error()
	local result = runtime.SimpleAssetsRuntime_MouseCursorLoad(
		windows.path(path),
		hotspot_x,
		hotspot_y
	)

	if result == 0 then
		return false, runtime_string(runtime.SimpleAssetsRuntime_LastError()) or
			"SimpleAssets runtime failed to load mouse cursor"
	end

	return true
end

native.resource_state = function(resource_type, path)
	local runtime = runtime_or_error()
	local result = runtime.SimpleAssetsRuntime_ResourceState(resource_type, windows.path(path))

	if result < 0 then
		return nil, runtime_string(runtime.SimpleAssetsRuntime_LastError()) or "SimpleAssets runtime failed to query resource state"
	end

	return result
end

native.shutdown = function()
	local runtime = state.runtime

	if runtime then
		runtime.SimpleAssetsRuntime_Shutdown()
	end

	state.game_dir = nil
	state.user_dir = nil
end

mod._simple_assets_native_runtime = native

return native
