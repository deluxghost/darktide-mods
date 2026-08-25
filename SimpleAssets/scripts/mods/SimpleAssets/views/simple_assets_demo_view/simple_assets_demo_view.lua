local mod = get_mod("SimpleAssets")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local definitions = mod:io_dofile(
	"SimpleAssets/scripts/mods/SimpleAssets/views/simple_assets_demo_view/simple_assets_demo_view_definitions"
)
local asset_paths = definitions.asset_paths
local resource_names = definitions.resource_names

local TEXTURE_PATH = "textures/cat.jpg"
local FONT_PATH = "fonts/DancingScript-Regular.slug"
local FONT_TYPE = "simple_assets_demo_dancing_script"
local MOUSE_CURSOR_PATH = asset_paths.mouse_cursor
local MOUSE_CURSOR_RESOURCE_NAME = resource_names.mouse_cursor
local MOUSE_CURSOR_HOTSPOT_X = 6
local MOUSE_CURSOR_HOTSPOT_Y = 2
local VIDEO_PATH = asset_paths.video
local VIDEO_RESOURCE_NAME = resource_names.video
local SLUG_ALBUM_PATH = asset_paths.slug_album
local SLUG_ALBUM_RESOURCE_NAME = resource_names.slug_album
local DEFAULT_MOUSE_CURSOR = "content/ui/textures/cursors/mouse_cursor_idle"
local LOADING_TEXT = "Loading..."

local assets = {
	revision = 0,
	texture = {
		status = "idle",
	},
	font = {
		status = "idle",
	},
	mouse_cursor = {
		resource = MOUSE_CURSOR_RESOURCE_NAME,
		status = "idle",
	},
	video = {
		resource = VIDEO_RESOURCE_NAME,
		status = "idle",
	},
	slug_album = {
		resource = SLUG_ALBUM_RESOURCE_NAME,
		status = "idle",
	},
}

local function set_failed(asset, asset_type, load_error)
	local message = type(load_error) == "table" and (load_error.error or load_error.url or load_error) or load_error

	asset.error = string.format("Failed to load %s. See the console log.", asset_type)
	asset.status = "failed"
	assets.revision = assets.revision + 1

	mod:error(string.format("SimpleAssets demo %s failed: %s", asset_type, tostring(message)))
end

local function load_texture()
	local asset = assets.texture

	if asset.status ~= "idle" then
		return
	end

	asset.status = "loading"
	assets.revision = assets.revision + 1

	mod.load_texture(TEXTURE_PATH)
		:next(function(data)
			if not data or not data.is_ok or not data.texture then
				set_failed(asset, "texture", data)
				return
			end

			asset.texture = data.texture
			asset.status = "ready"
			assets.revision = assets.revision + 1
		end)
		:catch(function(load_error)
			set_failed(asset, "texture", load_error)
		end)
end

local function load_font()
	local asset = assets.font

	if asset.status ~= "idle" then
		return
	end

	asset.status = "loading"
	assets.revision = assets.revision + 1

	mod.load_font(FONT_TYPE, FONT_PATH)
		:next(function(result)
			asset.font_type = result.font_type
			asset.status = "ready"
			assets.revision = assets.revision + 1
		end)
		:catch(function(load_error)
			set_failed(asset, "font", load_error)
		end)
end

local function load_engine_resource(asset, asset_type, load)
	if asset.status ~= "idle" then
		return
	end

	asset.status = "loading"
	assets.revision = assets.revision + 1

	load()
		:next(function(result)
			asset.resource = result.resource_name
			asset.status = "ready"
			assets.revision = assets.revision + 1
		end)
		:catch(function(load_error)
			set_failed(asset, asset_type, load_error)
		end)
end

local function load_assets()
	load_texture()
	load_font()
	load_engine_resource(assets.mouse_cursor, "mouse cursor", function()
		return mod.load_mouse_cursor(
			MOUSE_CURSOR_PATH,
			MOUSE_CURSOR_HOTSPOT_X,
			MOUSE_CURSOR_HOTSPOT_Y
		)
	end)
	load_engine_resource(assets.video, "video", function()
		return mod.load_video(VIDEO_PATH)
	end)
	load_engine_resource(assets.slug_album, "slug album", function()
		return mod.load_slug_album(SLUG_ALBUM_PATH)
	end)
end

SimpleAssetsDemoView = class("SimpleAssetsDemoView", "BaseView")

SimpleAssetsDemoView.init = function(self, settings)
	SimpleAssetsDemoView.super.init(self, definitions, settings)
end

SimpleAssetsDemoView.on_enter = function(self)
	SimpleAssetsDemoView.super.on_enter(self)

	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 100)

	local legend_inputs = self._definitions.legend_inputs

	for i = 1, #legend_inputs do
		local entry = legend_inputs[i]

		self._input_legend_element:add_entry(
			entry.display_name,
			entry.input_action,
			entry.visibility_function,
			entry.on_pressed_callback and callback(self, entry.on_pressed_callback),
			entry.alignment
		)
	end

	load_assets()
	self:_refresh_assets()
end

SimpleAssetsDemoView._refresh_assets = function(self)
	if self._asset_revision == assets.revision then
		return
	end

	self._asset_revision = assets.revision

	local texture_asset = assets.texture
	local texture_widget = self._widgets_by_name.texture_demo
	local texture_ready = texture_asset.status == "ready"

	texture_widget.content.texture_ready = texture_ready
	texture_widget.content.status = texture_asset.error or LOADING_TEXT
	texture_widget.style.image.material_values.texture_map = texture_asset.texture

	local font_asset = assets.font
	local font_widget = self._widgets_by_name.font_demo
	local font_ready = font_asset.status == "ready"

	font_widget.content.font_ready = font_ready
	font_widget.content.status = font_asset.error or LOADING_TEXT

	if font_ready then
		font_widget.style.sample_text.font_type = font_asset.font_type
	end

	local mouse_cursor_asset = assets.mouse_cursor
	local mouse_cursor_widget = self._widgets_by_name.mouse_cursor_demo
	local mouse_cursor_ready = mouse_cursor_asset.status == "ready"

	mouse_cursor_widget.content.mouse_cursor_ready = mouse_cursor_ready
	mouse_cursor_widget.content.status = mouse_cursor_asset.error or LOADING_TEXT

	local video_asset = assets.video
	local video_widget = self._widgets_by_name.video_demo
	local video_ready = video_asset.status == "ready"

	video_widget.content.video_ready = video_ready
	video_widget.content.status = video_asset.error or LOADING_TEXT

	if video_ready and not video_widget.content.video_player_reference then
		local video_player_reference = self.__class_name

		UIRenderer.create_video_player(self._ui_renderer, video_player_reference, nil, video_asset.resource, true)
		video_widget.content.video_player_reference = video_player_reference
	end

	local slug_album_asset = assets.slug_album
	local slug_album_widget = self._widgets_by_name.slug_album_demo
	local slug_album_ready = slug_album_asset.status == "ready"

	slug_album_widget.content.slug_album_ready = slug_album_ready
	slug_album_widget.content.status = slug_album_asset.error or LOADING_TEXT
end

SimpleAssetsDemoView._update_mouse_cursor = function(self)
	local widget = self._widgets_by_name.mouse_cursor_demo
	local hotspot = widget.content.hotspot
	local should_apply = assets.mouse_cursor.status == "ready" and hotspot and hotspot.is_hover

	if should_apply and not self._mouse_cursor_applied then
		Window.set_cursor(assets.mouse_cursor.resource)
		self._mouse_cursor_applied = true
	elseif not should_apply and self._mouse_cursor_applied then
		Window.set_cursor(DEFAULT_MOUSE_CURSOR)
		self._mouse_cursor_applied = nil
	end
end

SimpleAssetsDemoView.update = function(self, dt, t, input_service)
	self:_refresh_assets()
	self:_update_mouse_cursor()

	return SimpleAssetsDemoView.super.update(self, dt, t, input_service)
end

SimpleAssetsDemoView._on_back_pressed = function(self)
	Managers.ui:close_view(self.view_name)
end

SimpleAssetsDemoView.on_exit = function(self)
	local video_widget = self._widgets_by_name.video_demo

	if video_widget.content.video_player_reference then
		UIRenderer.destroy_video_player(self._ui_renderer, video_widget.content.video_player_reference)
		video_widget.content.video_player_reference = nil
	end

	if self._mouse_cursor_applied then
		Window.set_cursor(DEFAULT_MOUSE_CURSOR)
		self._mouse_cursor_applied = nil
	end

	SimpleAssetsDemoView.super.on_exit(self)
end

return SimpleAssetsDemoView
