local mod = get_mod("SimpleAssets")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local definitions = mod:io_dofile(
	"SimpleAssets/scripts/mods/SimpleAssets/views/simple_assets_demo_view/simple_assets_demo_view_definitions"
)

local TEXTURE_PATH = "textures/cat.jpg"
local FONT_PATH = "fonts/DancingScript-Regular.slug"
local FONT_TYPE = "simple_assets_demo_dancing_script"

local assets = {
	revision = 0,
	texture = {
		status = "idle",
	},
	font = {
		status = "idle",
	},
}

local function set_failed(asset, asset_type, load_error)
	asset.error = string.format("Failed to load %s. See the console log.", asset_type)
	asset.status = "failed"
	assets.revision = assets.revision + 1

	mod:error(string.format("SimpleAssets demo %s failed: %s", asset_type, tostring(load_error)))
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
		:next(function(font_type)
			asset.font_type = font_type
			asset.status = "ready"
			assets.revision = assets.revision + 1
		end)
		:catch(function(load_error)
			set_failed(asset, "font", load_error)
		end)
end

local function load_assets()
	load_texture()
	load_font()
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
	texture_widget.content.status = texture_asset.error or "Loading texture..."
	texture_widget.style.image.material_values.texture_map = texture_asset.texture

	local font_asset = assets.font
	local font_widget = self._widgets_by_name.font_demo
	local font_ready = font_asset.status == "ready"

	font_widget.content.font_ready = font_ready
	font_widget.content.status = font_asset.error or "Loading font..."

	if font_ready then
		font_widget.style.sample_text.font_type = font_asset.font_type
	end
end

SimpleAssetsDemoView.update = function(self, dt, t, input_service)
	self:_refresh_assets()

	return SimpleAssetsDemoView.super.update(self, dt, t, input_service)
end

SimpleAssetsDemoView._on_back_pressed = function(self)
	Managers.ui:close_view(self.view_name)
end

return SimpleAssetsDemoView
