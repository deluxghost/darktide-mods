local mod = get_mod("Realms")
local ScrollbarPassTemplates = require("scripts/ui/pass_templates/scrollbar_pass_templates")
local TalentBuilderViewSettings = require("scripts/ui/views/talent_builder_view/talent_builder_view_settings")
local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local Text = require("scripts/utilities/ui/text")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local ViewElementWeaponStats = require("scripts/ui/view_elements/view_element_weapon_stats/view_element_weapon_stats")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UISettings = require("scripts/settings/ui/ui_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local Preparation = mod._preparation
local definitions = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/preparation_view_definitions")
local Layout = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/preparation_view_layout")
local ViewElementTalentTooltip = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/view_element_talent_tooltip")

local SYSTEM_VIEW_NAME = "system_view"
local REFRESH_INTERVAL = 0.25
local GRID_DRAW_LAYER = 10
local GRID_RENDER_PADDING = 20
local WEAPON_STATS_DRAW_LAYER = 160
local READY_ICON = ""
local NOT_READY_ICON = ""
local PLAYER_SIGNATURE_FIELDS = {
	"peer_id",
	"name",
	"class_name",
	"loadout_key",
	"ready",
}
local MISSION_SIGNATURE_FIELDS = {
	"key",
}

local RealmsPreparationGrid = class("RealmsPreparationGrid", "ViewElementGrid")

RealmsPreparationGrid._update_window_size = function (self)
	RealmsPreparationGrid.super._update_window_size(self)

	local viewport_width, viewport_height = self:_scenegraph_size("grid_mask")
	local mask_width = viewport_width + GRID_RENDER_PADDING * 2
	local mask_height = viewport_height + GRID_RENDER_PADDING * 2

	self:_set_scenegraph_size("grid_mask", mask_width, mask_height)
	self:set_grid_interaction_offset(GRID_RENDER_PADDING, GRID_RENDER_PADDING)

	self._realms_render_viewport_size = self._realms_render_viewport_size or {}
	self._realms_render_viewport_size[1] = viewport_width
	self._realms_render_viewport_size[2] = viewport_height
	local uv_x = GRID_RENDER_PADDING / mask_width
	local uv_y = GRID_RENDER_PADDING / mask_height

	self._realms_render_uvs = {
		{
			uv_x,
			uv_y,
		},
		{
			1 - uv_x,
			1 - uv_y,
		},
	}
end

RealmsPreparationGrid._draw_render_target = function (self, render_settings)
	local ui_grid_renderer = self._ui_grid_renderer
	local material = self._ui_resource_renderer.render_target_material
	local scale = self._render_scale or 1
	local position = self:scenegraph_world_position("grid_mask")
	local viewport_size = self._realms_render_viewport_size
	local start_layer = (render_settings.start_layer or 0) + self._draw_layer
	local gui_position = Vector3(
		(position[1] + GRID_RENDER_PADDING) * scale,
		(position[2] + GRID_RENDER_PADDING) * scale,
		(position[3] or 0) + start_layer
	)
	local gui_size = Vector3(viewport_size[1] * scale, viewport_size[2] * scale, 0)
	local renderer = self._realms_render_target_renderer

	if not renderer then
		renderer = {
			base_render_pass = "to_screen",
			gui = ui_grid_renderer.gui,
			render_settings = {
				alpha_multiplier = 1,
				color_intensity_multiplier = 1,
				material_flags = 0,
				start_layer = 0,
			},
			scale = 1,
		}
		self._realms_render_target_renderer = renderer
	end

	UIRenderer.script_draw_bitmap_uv(renderer, material, gui_position, gui_size, self._realms_render_uvs, Color(255, 255, 255, 255))
end

local PORTRAIT_PROFILE_SLOTS = {
	"slot_body_face",
	"slot_body_hair",
	"slot_body_tattoo",
	"slot_gear_head",
	"slot_gear_lowerbody",
	"slot_gear_upperbody",
	"slot_portrait_frame",
}

RealmsPreparationView = class("RealmsPreparationView", "BaseView")

local function rows_signature(rows, fields)
	local parts = {}

	for i = 1, #rows do
		local row = rows[i]

		for j = 1, #fields do
			parts[#parts + 1] = tostring(row[fields[j]])
		end
	end

	return table.concat(parts, "\31")
end

local function item_key(item)
	return item and (item.gear_id or item.name or item.icon_material or item.icon) or ""
end

local function portrait_key(profile)
	if not profile then
		return ""
	end

	local parts = {
		tostring(profile.character_id),
	}
	local loadout = profile.loadout or {}

	for i = 1, #PORTRAIT_PROFILE_SLOTS do
		parts[#parts + 1] = tostring(item_key(loadout[PORTRAIT_PROFILE_SLOTS[i]]))
	end

	return table.concat(parts, "\31")
end

RealmsPreparationView.init = function (self, settings)
	RealmsPreparationView.super.init(self, definitions, settings)
end

RealmsPreparationView.ui_renderer = function (self)
	return self._ui_renderer
end

RealmsPreparationView.on_enter = function (self)
	mod._preparation_chat.capture_layout()
	RealmsPreparationView.super.on_enter(self)

	self._refresh_elapsed = 0
	self._portrait_slots = {}
	self._portraits_dirty = false
	self._known_ready_by_peer = {}
	self._player_rows_initialized = false
	self._countdown_active = false
	self._is_main_menu_open = Managers.ui:view_active(SYSTEM_VIEW_NAME)
	self._widgets_by_name.action_button.content.hotspot.pressed_callback = callback(self, "cb_on_action_pressed")
	self:_setup_talent_tooltip_element()
	self:_setup_grids()
	self:_setup_weapon_stats()
	self:_setup_input_legend()
	self:_refresh(true)
end

RealmsPreparationView._setup_talent_tooltip_element = function (self)
	self._talent_tooltip = self:_add_element(ViewElementTalentTooltip, "talent_tooltip", WEAPON_STATS_DRAW_LAYER)
	self._talent_tooltip:set_visibility(false)
end

RealmsPreparationView._sync_player_sounds = function (self, rows)
	local local_peer_id = string.lower(tostring(Network.peer_id()))
	local current_ready_by_peer = {}

	for i = 1, #rows do
		local row = rows[i]
		local peer_id = row.peer_id

		current_ready_by_peer[peer_id] = row.ready

		if self._player_rows_initialized and peer_id ~= local_peer_id then
			local previous_ready = self._known_ready_by_peer[peer_id]

			if previous_ready == nil then
				self:_play_sound(UISoundEvents.mission_lobby_matchmade_players_join)
			elseif previous_ready ~= row.ready then
				self:_play_sound(row.ready and UISoundEvents.mission_lobby_player_ready or UISoundEvents.mission_lobby_player_unready)
			end
		end
	end

	self._known_ready_by_peer = current_ready_by_peer
	self._player_rows_initialized = true
end

RealmsPreparationView.on_exit = function (self)
	for _, slot in pairs(self._portrait_slots) do
		self:_unload_portrait_slot(slot)
	end

	self._portrait_slots = nil
	self:_clear_hover()
	mod._preparation_chat.restore_layout()

	RealmsPreparationView.super.on_exit(self)
end

RealmsPreparationView._setup_weapon_stats = function (self)
	self._weapon_stats = self:_add_element(ViewElementWeaponStats, "weapon_stats", WEAPON_STATS_DRAW_LAYER, definitions.item_stats_grid_settings)
	self._weapon_stats:set_visibility(false)
end

RealmsPreparationView._unload_portrait_slot = function (self, slot)
	if slot.profile_load_id then
		Managers.ui:unload_profile_portrait(slot.profile_load_id)
		slot.profile_load_id = nil
	end
	if slot.frame_load_id then
		Managers.ui:unload_item_icon(slot.frame_load_id)
		slot.frame_load_id = nil
	end
end

RealmsPreparationView._cb_set_portrait = function (self, slot, grid_index, rows, columns, render_target)
	if not self._portrait_slots or self._portrait_slots[slot.peer_id] ~= slot then
		return
	end

	slot.columns = columns
	slot.grid_index = grid_index - 1
	slot.render_target = render_target
	slot.rows = rows
	self._portraits_dirty = true
end

RealmsPreparationView._cb_unset_portrait = function (self, slot)
	if not self._portrait_slots or self._portrait_slots[slot.peer_id] ~= slot then
		return
	end

	slot.columns = nil
	slot.grid_index = nil
	slot.render_target = nil
	slot.rows = nil
	self._portraits_dirty = true
end

RealmsPreparationView._cb_set_portrait_frame = function (self, slot, item)
	if not self._portrait_slots or self._portrait_slots[slot.peer_id] ~= slot then
		return
	end

	if item.icon_material and item.icon_material ~= "" then
		slot.frame_material = item.icon_material
		slot.frame_texture = nil
	else
		slot.frame_material = nil
		slot.frame_texture = item.icon
	end

	self._portraits_dirty = true
end

RealmsPreparationView._load_portrait_slot = function (self, slot, profile)
	slot.profile_load_id = Managers.ui:load_profile_portrait(
		profile,
		callback(self, "_cb_set_portrait", slot),
		nil,
		callback(self, "_cb_unset_portrait", slot)
	)

	local frame_item = profile.loadout and profile.loadout.slot_portrait_frame

	if frame_item then
		slot.frame_load_id = Managers.ui:load_item_icon(frame_item, callback(self, "_cb_set_portrait_frame", slot))
	end
end

RealmsPreparationView._sync_portraits = function (self, rows)
	local active_peers = {}

	for i = 1, #rows do
		local row = rows[i]
		local peer_id = row.peer_id
		local key = portrait_key(row.profile)
		local slot = self._portrait_slots[peer_id]

		active_peers[peer_id] = true

		if not slot or slot.key ~= key then
			if slot then
				self:_unload_portrait_slot(slot)
			end

			slot = {
				key = key,
				peer_id = peer_id,
			}
			self._portrait_slots[peer_id] = slot

			if row.profile then
				self:_load_portrait_slot(slot, row.profile)
			end
		end

		row.portrait = slot
	end

	for peer_id, slot in pairs(self._portrait_slots) do
		if not active_peers[peer_id] then
			self:_unload_portrait_slot(slot)
			self._portrait_slots[peer_id] = nil
		end
	end
end

RealmsPreparationView._setup_grid = function (self, scenegraph_id, grid_size, bottom_chin)
	local grid_settings = {
		edge_padding = 0,
		enable_gamepad_scrolling = true,
		hide_background = true,
		hide_dividers = true,
		scrollbar_pass_templates = ScrollbarPassTemplates.terminal_scrollbar,
		scrollbar_vertical_margin = 0,
		scrollbar_width = 8,
		title_height = 0,
		use_is_focused_for_navigation = false,
		use_select_on_focused = false,
		use_terminal_background = false,
		widget_icon_load_margin = 0,
		grid_spacing = {
			0,
			Layout.row_spacing,
		},
		top_padding = 4,
		bottom_chin = bottom_chin or 4,
		grid_size = grid_size,
		mask_size = {
			grid_size[1],
			grid_size[2],
		},
	}
	local grid = self:_add_element(RealmsPreparationGrid, scenegraph_id, GRID_DRAW_LAYER, grid_settings, scenegraph_id)

	self:_update_element_position(scenegraph_id, grid)
	grid:set_empty_message("")

	return grid
end

RealmsPreparationView._setup_grids = function (self)
	self._player_grid = self:_setup_grid("player_grid", definitions.player_grid_size)
	self._info_grid = self:_setup_grid("info_grid", definitions.info_grid_size, 20)
end

RealmsPreparationView._setup_input_legend = function (self)
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 100)
	self._input_legend_element:add_entry(
		"loc_main_menu",
		"close_view",
		function ()
			return not self._is_main_menu_open
		end,
		callback(self, "cb_on_open_main_menu_pressed"),
		"left_alignment"
	)
	self._input_legend_element:add_entry(
		"loc_input_legend_inventory",
		"lobby_open_inventory",
		nil,
		callback(self, "cb_on_inventory_pressed"),
		"right_alignment"
	)
end

RealmsPreparationView._present_player_rows = function (self, force)
	local rows = Preparation.player_rows()
	self:_sync_portraits(rows)
	self:_sync_player_sounds(rows)
	local signature = rows_signature(rows, PLAYER_SIGNATURE_FIELDS)

	if not force and signature == self._player_rows_signature then
		return
	end

	self._player_rows_signature = signature

	local layout = {}

	for i = 1, #rows do
		local row = rows[i]
		local portrait = row.portrait

		layout[#layout + 1] = {
			class_name = row.class_name,
			peer_id = row.peer_id,
			player_name = row.name,
			portrait_columns = portrait.columns,
			portrait_frame_material = portrait.frame_material,
			portrait_frame_texture = portrait.frame_texture,
			portrait_grid_index = portrait.grid_index,
			portrait_render_target = portrait.render_target,
			portrait_rows = portrait.rows,
			ready = row.ready,
			ready_status = row.ready and READY_ICON or NOT_READY_ICON,
			skills = row.skills,
			weapons = row.weapons,
			widget_type = "player",
		}
	end

	self._player_grid:present_grid_layout(layout, definitions.blueprints)
	self._player_grid:set_handle_grid_navigation(true)
end

RealmsPreparationView._present_mission_rows = function (self, force)
	local rows = Preparation.mission_details()
	local signature = rows_signature(rows, MISSION_SIGNATURE_FIELDS)

	if not force and signature == self._mission_rows_signature then
		return
	end

	self._mission_rows_signature = signature

	local layout = {}

	for i = 1, #rows do
		local row = rows[i]

		layout[#layout + 1] = {
			key = row.key,
			widget_data = row.widget_data,
			widget_type = row.widget_type,
		}
	end

	self._info_grid:present_grid_layout(layout, definitions.blueprints)
	self._info_grid:set_handle_grid_navigation(true)
end

RealmsPreparationView._refresh = function (self, force)
	local mission_header = Preparation.mission_header()
	local countdown = Preparation.countdown_remaining()
	local mission_title = self._widgets_by_name.mission_title
	mission_title.content.title = mission_header.title
	mission_title.content.sub_title = mission_header.subtitle
	self._widgets_by_name.player_header.content.player = Localize("loc_group_finder_group_player_title")
	self._widgets_by_name.player_header.content.skills = mod:localize("preparation_skills_header")
	self._widgets_by_name.player_header.content.loadout = mod:localize("preparation_weapons_header")
	self._widgets_by_name.player_header.content.status = mod:localize("preparation_status_header")

	local countdown_widget = self._widgets_by_name.countdown
	countdown_widget.content.visible = countdown ~= nil
	countdown_widget.content.text = countdown and UISettings.digital_clock_numbers[countdown] or ""

	local countdown_active = countdown ~= nil

	if countdown_active and not self._countdown_active then
		self:_play_sound(UISoundEvents.mission_lobby_all_players_ready)
	end

	self._countdown_active = countdown_active

	local button_content = self._widgets_by_name.action_button.content
	local button_text = mod:localize(Preparation.action_label())

	button_content.original_text = button_text
	button_content.text = button_text
	button_content.hotspot.disabled = Preparation.is_finalizing()

	self:_present_player_rows(force)
	self:_present_mission_rows(force)
end

RealmsPreparationView._row_anchor = function (self, widget, style_id)
	local grid_position = self._player_grid:scenegraph_world_position("grid_content_pivot")
	local style = widget.style[style_id]

	return grid_position[1] + widget.offset[1] + style.offset[1],
		grid_position[2] + widget.offset[2] + style.offset[2],
		style.size[1],
		style.size[2]
end

RealmsPreparationView._position_talent_tooltip = function (self, widget, style_id)
	local anchor_x, anchor_y, anchor_width, anchor_height = self:_row_anchor(widget, style_id)
	local tooltip_width, tooltip_height = self._talent_tooltip:size()
	local screen_width = Layout.screen_size[1]
	local screen_height = Layout.screen_size[2]
	local margin = 20
	local gap = 12
	local x = anchor_x + anchor_width + gap

	if x + tooltip_width > screen_width - margin then
		x = anchor_x - tooltip_width - gap
	end

	self._talent_tooltip:set_position(
		math.clamp(x, margin, screen_width - tooltip_width - margin),
		math.clamp(anchor_y + anchor_height * 0.5 - tooltip_height * 0.5, margin, screen_height - tooltip_height - margin)
	)

	if not self._talent_tooltip:visible() then
		self._talent_tooltip:_force_update_scenegraph()
		self._talent_tooltip:set_visibility(true)
	end
end

RealmsPreparationView._position_weapon_stats = function (self, widget, style_id)
	local anchor_x, anchor_y, anchor_width, anchor_height = self:_row_anchor(widget, style_id)
	local grid_width = definitions.item_stats_grid_settings.grid_size[1]
	local grid_height = math.min(self._weapon_stats:grid_height() or definitions.item_stats_grid_settings.grid_size[2], definitions.item_stats_grid_settings.grid_size[2])
	local screen_width = Layout.screen_size[1]
	local screen_height = Layout.screen_size[2]
	local margin = 20
	local gap = 12
	local x = anchor_x + anchor_width + gap

	if x + grid_width > screen_width - margin then
		x = anchor_x - grid_width - gap
	end

	local y = math.clamp(anchor_y + anchor_height * 0.5 - grid_height * 0.5, margin, screen_height - grid_height - margin)

	self._weapon_stats:set_pivot_offset(math.clamp(x, margin, screen_width - grid_width - margin), y)
end

RealmsPreparationView._show_weapon_stats = function (self, hover)
	if self._hover ~= hover then
		return
	end

	self:_position_weapon_stats(hover.widget, "weapon_" .. hover.index .. "_icon")
	self._weapon_stats:_force_update_scenegraph()
	self._weapon_stats:set_visibility(true)
end

RealmsPreparationView._setup_talent_tooltip = function (self, skill)
	local talent = skill.talent

	if not talent then
		return false
	end

	local widget = self._talent_tooltip:widget()
	local content = widget.content
	local style = widget.style
	local node_settings = TalentBuilderViewSettings.settings_by_node_type[skill.node_type]
	local text_width = 360
	local text_offset = 14

	content.talent_type_title = Localize(node_settings.display_name)
	content.title = TalentLayoutParser.talent_title(talent, 1, Color.ui_terminal(255, true))
	content.description = TalentLayoutParser.talent_description(talent, 1, Color.ui_terminal(255, true))
	style.talent_type_title.offset[2] = text_offset
	style.talent_type_title.size[2] = Text.text_height(self._ui_renderer, content.talent_type_title, style.talent_type_title, {text_width, 1000})
	text_offset = text_offset + style.talent_type_title.size[2]
	style.title.offset[2] = text_offset
	style.title.size[2] = Text.text_height(self._ui_renderer, content.title, style.title, {text_width, 1000})
	text_offset = text_offset + style.title.size[2] + 10
	style.description.offset[2] = text_offset
	style.description.size[2] = Text.text_height(self._ui_renderer, content.description, style.description, {text_width, 1000})
	text_offset = text_offset + style.description.size[2] + 20
	content.visible = true
	widget.alpha_multiplier = 1
	self._talent_tooltip:set_height(text_offset)

	return true
end

RealmsPreparationView._clear_hover = function (self)
	self._hover = nil

	local talent_tooltip = self._talent_tooltip

	if talent_tooltip then
		talent_tooltip:set_visibility(false)
	end

	if self._weapon_stats then
		self._weapon_stats:stop_presenting()
		self._weapon_stats:set_visibility(false)
	end
end

RealmsPreparationView._set_hover = function (self, hover)
	local previous = self._hover
	local changed = not previous or previous.widget ~= hover.widget or previous.kind ~= hover.kind or previous.index ~= hover.index

	if changed then
		self:_clear_hover()
		self._hover = hover

		if hover.kind == "skill" then
			if not self:_setup_talent_tooltip(hover.data) then
				self._hover = nil
				return
			end
		else
			self._weapon_stats:present_item(hover.data.item, nil, callback(self, "_show_weapon_stats", hover))
		end
	end

	if hover.kind == "skill" then
		self:_position_talent_tooltip(hover.widget, "skill_" .. hover.index)
	elseif self._weapon_stats:visible() then
		self:_position_weapon_stats(hover.widget, "weapon_" .. hover.index .. "_icon")
	end
end

RealmsPreparationView._update_hover = function (self)
	local widgets = self._player_grid and self._player_grid:widgets()

	if not widgets then
		return
	end

	for i = 1, #widgets do
		local widget = widgets[i]
		local content = widget.content

		for skill_index = 1, definitions.max_skills do
			local hotspot = content["skill_hotspot_" .. skill_index]

			if hotspot and (hotspot.is_hover or hotspot.is_selected) and content["skill_" .. skill_index] then
				self:_set_hover({
					data = content["skill_" .. skill_index],
					index = skill_index,
					kind = "skill",
					widget = widget,
				})

				return
			end
		end

		for weapon_index = 1, 2 do
			local hotspot = content["weapon_hotspot_" .. weapon_index]

			if hotspot and (hotspot.is_hover or hotspot.is_selected) and content["weapon_" .. weapon_index] then
				self:_set_hover({
					data = content["weapon_" .. weapon_index],
					index = weapon_index,
					kind = "weapon",
					widget = widget,
				})

				return
			end
		end
	end

	if self._hover then
		self:_clear_hover()
	end
end

RealmsPreparationView.cb_on_action_pressed = function (self)
	local ready = Preparation.local_ready()

	if Preparation.perform_action() then
		self:_play_sound(ready and UISoundEvents.mission_lobby_unready or UISoundEvents.mission_lobby_ready_up)
	end
	self:_refresh(false)
end

RealmsPreparationView.cb_on_open_main_menu_pressed = function (self)
	if not Managers.ui:view_active(SYSTEM_VIEW_NAME) then
		Managers.ui:open_view(SYSTEM_VIEW_NAME)
	end
end

RealmsPreparationView.cb_on_inventory_pressed = function (self)
	Preparation.open_inventory(self)
end

RealmsPreparationView.update = function (self, dt, t, input_service)
	self._is_main_menu_open = Managers.ui:view_active(SYSTEM_VIEW_NAME)
	self._refresh_elapsed = self._refresh_elapsed + dt

	if self._portraits_dirty then
		self._portraits_dirty = false
		self:_present_player_rows(true)
	end

	if self._refresh_elapsed >= REFRESH_INTERVAL then
		self._refresh_elapsed = 0
		self:_refresh(false)
	end

	local pass_input, pass_draw = RealmsPreparationView.super.update(self, dt, t, input_service)

	self:_update_hover()

	return pass_input, pass_draw
end

return RealmsPreparationView
