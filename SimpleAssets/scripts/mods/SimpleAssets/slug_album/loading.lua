local mod = get_mod("SimpleAssets")

local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_replacement = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/replacement")

local loading = {}

local RESOURCE_TYPE = "slug_album"

local function start_slug_album(request)
	return native_runtime.slug_album_load(request.path)
end

loading.load_slug_album = resource_loading.create_loader(
	RESOURCE_TYPE,
	".slug",
	start_slug_album
)

loading.replace_slug_album = resource_replacement.create_replacer(
	RESOURCE_TYPE,
	".slug",
	start_slug_album,
	native_runtime.slug_album_replace
)

return loading
