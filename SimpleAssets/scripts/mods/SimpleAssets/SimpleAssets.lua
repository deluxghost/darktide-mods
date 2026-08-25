local mod = get_mod("SimpleAssets")

local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local initialized, initialize_error = native_runtime.initialize()

if not initialized then
	local error_message = mod:localize("initialize_failed", initialize_error)
	mod:error(error_message)
	error(error_message)
end

local paths = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/core/paths")
local font_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/font/loading")
local mouse_cursor_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/mouse_cursor/loading")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_replacement = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/replacement")
local resource_naming = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/naming")
local slug_album_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/slug_album/loading")
local texture_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/texture/loading")
local video_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/video/loading")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")

mod.get_game_dir = paths.get_game_dir
mod.get_resource_name = resource_naming.get_resource_name
mod.get_user_dir = paths.get_user_dir

local function start_animation(request)
	return native_runtime.animation_load(request.path)
end

local function start_material(request)
	return native_runtime.material_load(request.path)
end

local function start_particles(request)
	return native_runtime.particles_load(request.path)
end

local function start_unit(request)
	return native_runtime.unit_load(request.path)
end

mod.load_animation = resource_loading.create_loader("animation", ".animation", start_animation)
mod.load_font = font_loading.load_font
mod.load_material = resource_loading.create_loader("material", ".material", start_material)
mod.load_mouse_cursor = mouse_cursor_loading.load_mouse_cursor
mod.load_particles = resource_loading.create_loader("particles", ".particles", start_particles)
mod.load_slug_album = slug_album_loading.load_slug_album
mod.load_texture = texture_loading.load_texture
mod.load_textures = texture_loading.load_textures
mod.load_textures_from_dir = texture_loading.load_textures_from_dir
mod.load_unit = resource_loading.create_loader("unit", ".unit", start_unit)
mod.load_video = video_loading.load_video
mod.replace_animation = resource_replacement.create_replacer(
	"animation", ".animation", start_animation, native_runtime.animation_replace
)
mod.replace_font = font_loading.replace_font
mod.replace_material = resource_replacement.create_replacer(
	"material", ".material", start_material, native_runtime.material_replace
)
mod.replace_mouse_cursor = mouse_cursor_loading.replace_mouse_cursor
mod.replace_particles = resource_replacement.create_replacer(
	"particles", ".particles", start_particles, native_runtime.particles_replace
)
mod.replace_slug_album = slug_album_loading.replace_slug_album
mod.replace_texture = texture_loading.replace_texture
mod.replace_unit = resource_replacement.create_replacer(
	"unit", ".unit", start_unit, native_runtime.unit_replace
)
mod.replace_video = video_loading.replace_video

local DEMO_VIEW_NAME = "simple_assets_demo_view"
local DEMO_VIEW_PATH = "SimpleAssets/scripts/mods/SimpleAssets/views/simple_assets_demo_view/simple_assets_demo_view"

mod:add_require_path(DEMO_VIEW_PATH)
mod:register_view({
	view_name = DEMO_VIEW_NAME,
	view_settings = {
		init_view_function = function()
			return true
		end,
		state_bound = true,
		path = DEMO_VIEW_PATH,
		class = "SimpleAssetsDemoView",
		disable_game_world = false,
		load_always = true,
		load_in_hub = true,
		game_world_blur = 1.1,
		enter_sound_events = {
			UISoundEvents.system_menu_enter,
		},
		exit_sound_events = {
			UISoundEvents.system_menu_exit,
		},
		wwise_states = {
			options = WwiseGameSyncSettings.state_groups.options.ingame_menu,
		},
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
	},
})

mod:command("simpleassets", "Open the SimpleAssets UI demo view.", function()
	if not Managers.ui:view_instance(DEMO_VIEW_NAME) then
		Managers.ui:open_view(DEMO_VIEW_NAME, nil, nil, nil, nil, {})
	end
end)

mod.on_unload = function()
	native_runtime.shutdown()
end
