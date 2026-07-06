local mod = get_mod("SimpleAssets")

local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local initialized, initialize_error = native_runtime.initialize()

if not initialized then
	local error_message = mod:localize("initialize_failed", initialize_error)
	mod:error(error_message)
	error(error_message)
end

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local texture_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/texture/loading")

mod:info(string.format("SimpleAssets runtime listening on %s", native_runtime.listen_info()))

mod.get_game_dir = paths.get_game_dir
mod.get_user_dir = paths.get_user_dir
mod.load_texture = texture_loading.load_texture
mod.load_textures = texture_loading.load_textures
mod.load_textures_from_dir = texture_loading.load_textures_from_dir

mod.on_unload = function()
	native_runtime.shutdown()
end
