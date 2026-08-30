local mod = get_mod("Realms")

local SocialMenu = {}
local Session

local DEFINITIONS_PATH = "scripts/ui/views/social_menu_roster_view/social_menu_roster_view_definitions"
local ROSTER_VIEW_PATH = "scripts/ui/views/social_menu_roster_view/social_menu_roster_view"
local SCROLLBAR_PASS_TEMPLATES_PATH = "scripts/ui/pass_templates/scrollbar_pass_templates"
local STYLES_PATH = "scripts/ui/views/social_menu_roster_view/social_menu_roster_view_styles"
local UI_WIDGET_GRID_PATH = "scripts/ui/widget_logic/ui_widget_grid"
local UI_WIDGET_PATH = "scripts/managers/ui/ui_widget"
local MAX_PLAYERS = 8
local PARTY_GRID_INDEX = 1
local ROSTER_GRID_INDEX = 2
local PARTY_GRID_ID = "party_grid"
local PARTY_GRID_CONTENT_ID = "realms_party_grid_content"
local PARTY_GRID_INTERACTION_ID = "realms_party_grid_interaction"
local PARTY_GRID_MASK_ID = "realms_party_grid_mask"
local PARTY_SCROLLBAR_ID = "realms_party_scrollbar"
local PARTY_GRID_MASK_EXPANSION = 40
local installed_roster_views = setmetatable({}, { __mode = "k" })

local function realms_visible(content)
	return content.realms_active
end

local function official_visible(original)
	return function (content, style)
		return not content.realms_active and (not original or original(content, style))
	end
end

local function official_empty_slot_visible(content, style)
	return not content.realms_active and style.content_key <= 4 and style.content_key > content.num_party_members
end

local function extend_party_panel_definition(Definitions, RosterViewStyles, ScrollbarPassTemplates, UIWidget)
	local definition = Definitions.widget_definitions.party_panel

	if definition._realms_extended then
		return
	end

	definition._realms_extended = true

	local scenegraph = Definitions.scenegraph_definition
	local party_panel_size = scenegraph.party_panel.size
	local party_grid_size = scenegraph.party_grid.size
	local grid_margin = RosterViewStyles.grid_margin
	local scrollbar_width = ScrollbarPassTemplates.terminal_scrollbar.default_width

	scenegraph.realms_party_panel_bottom = {
		horizontal_alignment = "left",
		parent = "party_panel",
		vertical_alignment = "bottom",
		size = {
			party_panel_size[1],
			36,
		},
		position = {
			0,
			14,
			10,
		},
	}
	scenegraph[PARTY_GRID_CONTENT_ID] = {
		horizontal_alignment = "left",
		parent = PARTY_GRID_ID,
		vertical_alignment = "top",
		size = table.clone(party_grid_size),
		position = {
			0,
			0,
			0,
		},
	}
	scenegraph[PARTY_GRID_MASK_ID] = {
		horizontal_alignment = "center",
		parent = PARTY_GRID_ID,
		vertical_alignment = "top",
		size = {
			party_grid_size[1] + PARTY_GRID_MASK_EXPANSION * 2,
			party_panel_size[2],
		},
		position = {
			0,
			-scenegraph.party_grid.position[2],
			1,
		},
	}
	scenegraph[PARTY_SCROLLBAR_ID] = {
		horizontal_alignment = "right",
		parent = "party_panel",
		vertical_alignment = "top",
		size = {
			scrollbar_width,
			party_grid_size[2],
		},
		position = {
			0,
			grid_margin[2],
			5,
		},
	}

	for i = 1, #definition.passes do
		local pass = definition.passes[i]

		if pass.style_id == "frame_bottom" or string.match(pass.style_id or "", "^window_%d+$") then
			pass.visibility_function = official_visible(pass.visibility_function)
		elseif string.match(pass.style_id or "", "^party_slot_%d+$") then
			pass.visibility_function = official_empty_slot_visible
		end
	end

	UIWidget.add_definition_pass(definition, {
		pass_type = "texture",
		scenegraph_id = "realms_party_panel_bottom",
		style_id = "realms_frame_bottom",
		value = "content/ui/materials/dividers/horizontal_frame_big_lower",
		visibility_function = realms_visible,
	})

	local widget_definitions = Definitions.widget_definitions

	widget_definitions[PARTY_GRID_MASK_ID] = UIWidget.create_definition({
		{
			pass_type = "texture",
			value = "content/ui/materials/offscreen_masks/ui_overlay_offscreen_straight_blur",
			visibility_function = realms_visible,
			style = {
				color = {
					255,
					255,
					255,
					255,
				},
			},
		},
	}, PARTY_GRID_MASK_ID, {
		realms_active = false,
	})
	widget_definitions[PARTY_GRID_INTERACTION_ID] = UIWidget.create_definition({
		{
			content_id = "hotspot",
			pass_type = "hotspot",
		},
	}, PARTY_GRID_ID)
	widget_definitions[PARTY_GRID_INTERACTION_ID].visible = false
	widget_definitions[PARTY_SCROLLBAR_ID] = UIWidget.create_definition(ScrollbarPassTemplates.terminal_scrollbar, PARTY_SCROLLBAR_ID)
	widget_definitions[PARTY_SCROLLBAR_ID].visible = false
end

local function install_view_hooks(SocialMenuRosterView, Definitions, RosterViewStyles, UIWidget, UIWidgetGrid)
	if installed_roster_views[SocialMenuRosterView] then
		return
	end

	local player_size = RosterViewStyles.player_panel_size
	local player_height = player_size[2]
	local grid_spacing = RosterViewStyles.grid_spacing
	local row_step = player_height + grid_spacing[2]
	local default_panel_height = Definitions.scenegraph_definition.party_panel.size[2]
	local default_grid_height = Definitions.scenegraph_definition.party_grid.size[2]
	local max_panel_height = RosterViewStyles.roster_panel_size[2]
	local panel_grid_inset = default_panel_height - default_grid_height
	local empty_slot_definition = UIWidget.create_definition({
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/line_medium_inner_shadow",
			style = {
				color = {
					255,
					0,
					0,
					0,
				},
				offset = {
					0,
					0,
					10,
				},
			},
		},
	}, PARTY_GRID_CONTENT_ID, nil, player_size)

	local function current_capacity(self)
		local configured = Session.max_members() or 4
		local current_members = self._party_widgets and #self._party_widgets or 0

		return math.clamp(math.max(configured, current_members), 2, MAX_PLAYERS)
	end

	local function empty_slot_widgets(self)
		local widgets = self._realms_party_empty_widgets

		if widgets then
			return widgets
		end

		widgets = {}

		for i = 1, MAX_PLAYERS do
			widgets[i] = UIWidget.init("realms_party_empty_slot_" .. i, empty_slot_definition)
		end

		self._realms_party_empty_widgets = widgets

		return widgets
	end

	local function destroy_empty_slot_widgets(self)
		local widgets = self._realms_party_empty_widgets

		if not widgets then
			return
		end

		local renderer = self._offscreen_renderer or self._ui_renderer

		for i = 1, #widgets do
			UIWidget.destroy(renderer, widgets[i])
		end

		self._realms_party_empty_widgets = nil
		self._realms_party_alignment_widgets = nil
	end

	local function use_portrait_renderer(self, widget, renderer)
		local content = widget.content
		local player_info = content.player_info
		local profile = player_info and player_info:profile()

		if profile and content.portrait_renderer ~= renderer then
			self:_load_widget_portrait(widget, profile, renderer)
		end
	end

	local function create_party_grid(self, active, capacity, panel_height, grid_height)
		local party_widgets = self._party_widgets
		local area_scenegraph_id = PARTY_GRID_ID
		local alignment_widgets = party_widgets
		local portrait_renderer = self._ui_renderer

		if active then
			area_scenegraph_id = PARTY_GRID_CONTENT_ID
			alignment_widgets = {}
			portrait_renderer = self._offscreen_renderer

			for i = 1, #party_widgets do
				local widget = party_widgets[i]

				widget.scenegraph_id = PARTY_GRID_CONTENT_ID
				alignment_widgets[#alignment_widgets + 1] = widget
			end

			local empty_widgets = empty_slot_widgets(self)

			for i = #party_widgets + 1, capacity do
				alignment_widgets[#alignment_widgets + 1] = empty_widgets[i]
			end

			self._realms_party_alignment_widgets = alignment_widgets
		else
			for i = 1, #party_widgets do
				party_widgets[i].scenegraph_id = PARTY_GRID_ID
			end

			self._realms_party_alignment_widgets = nil
		end

		for i = 1, #party_widgets do
			use_portrait_renderer(self, party_widgets[i], portrait_renderer)
		end

		local grid = UIWidgetGrid:new(party_widgets, alignment_widgets, self._ui_scenegraph, area_scenegraph_id, "down", grid_spacing, nil, true)
		local scrollbar_widget = self._widgets_by_name[PARTY_SCROLLBAR_ID]
		local content_length = capacity * player_height + math.max(capacity - 1, 0) * grid_spacing[2]
		local scrollable = active and panel_height == max_panel_height and content_length > grid_height

		if scrollable then
			scrollbar_widget.visible = true
			scrollbar_widget.content.scroll_speed = 50
			grid:assign_scrollbar(scrollbar_widget, PARTY_GRID_CONTENT_ID, PARTY_GRID_ID, true)

			local scroll_length = grid:scroll_length()

			scrollbar_widget.content.scroll_amount = scroll_length > 0 and math.min(1, row_step / scroll_length) or 0
		else
			scrollbar_widget.visible = false
			scrollbar_widget.content.value = 0
			scrollbar_widget.content.scroll_add = nil
			scrollbar_widget.content.scroll_value = nil
		end

		self._grids[PARTY_GRID_INDEX] = grid
	end

	local function configure_party_panel(self)
		local active = Session.is_active()
		local capacity = active and current_capacity(self) or 4
		local num_party_members = self._party_widgets and #self._party_widgets or 0
		local signature = string.format("%s:%d:%d", tostring(active), capacity, num_party_members)

		if self._realms_party_panel_signature == signature then
			return
		end

		self._realms_party_panel_signature = signature

		local extra_slots = math.max(capacity - 4, 0)
		local panel_height = active and math.min(default_panel_height + extra_slots * row_step, max_panel_height) or default_panel_height
		local grid_height = active and panel_height - panel_grid_inset or default_grid_height
		local panel_widget = self._widgets_by_name.party_panel
		local panel_content = panel_widget.content

		panel_content.realms_active = active
		panel_content.realms_max_members = capacity
		panel_content.num_party_members = num_party_members
		panel_content.max_num_party_members = capacity
		panel_content.header = Managers.localization:localize("loc_social_menu_party_header", true, panel_content)
		self._widgets_by_name[PARTY_GRID_MASK_ID].content.realms_active = active
		self._widgets_by_name[PARTY_GRID_INTERACTION_ID].visible = active
		self:_set_scenegraph_size("party_panel", nil, panel_height)
		self:_set_scenegraph_size(PARTY_GRID_ID, nil, grid_height)
		self:_set_scenegraph_size(PARTY_GRID_CONTENT_ID, nil, grid_height)
		self:_set_scenegraph_size(PARTY_GRID_MASK_ID, nil, panel_height)
		self:_set_scenegraph_size(PARTY_SCROLLBAR_ID, nil, grid_height)
		create_party_grid(self, active, capacity, panel_height, grid_height)
	end

	local function add_party_member(self, unique_id, player_info)
		local party_widgets = self._party_widgets
		local num_party_members = #party_widgets
		local party_member_widget = self:_get_roster_widget(player_info, "player_plaque", PARTY_GRID_ID)
		local widget_content = party_member_widget.content

		widget_content.party_panel = true
		widget_content.unique_id = unique_id

		if not widget_content.is_own_player then
			local name_or_activity_style = party_member_widget.style.name_or_activity

			name_or_activity_style.default_color = name_or_activity_style.party_member_color
		end

		local profile = player_info:profile()

		if profile then
			self:_load_widget_portrait(party_member_widget, profile, self._offscreen_renderer)
		end

		party_widgets[num_party_members + 1] = party_member_widget
	end

	local function draw_realms_party_grid(self, ui_renderer)
		if not Session.is_active() then
			return
		end

		local widgets = self._realms_party_alignment_widgets
		local grid = self._grids[PARTY_GRID_INDEX]

		if not widgets or not grid then
			return
		end

		local interaction_widget = self._widgets_by_name[PARTY_GRID_INTERACTION_ID]
		local is_grid_hovered = not self._using_cursor_navigation or interaction_widget.content.hotspot.is_hover

		for i = 1, #widgets do
			local widget = widgets[i]

			if grid:is_widget_visible(widget, grid_spacing[2]) then
				local hotspot = widget.content.hotspot

				if hotspot then
					hotspot.force_disabled = not is_grid_hovered
				end

				UIWidget.draw(widget, ui_renderer)
			end
		end
	end

	mod:hook(SocialMenuRosterView, "_add_to_party", function (func, self, unique_id, player_info)
		if not Session.is_active() then
			return func(self, unique_id, player_info)
		end

		local before = #self._party_widgets

		if before >= MAX_PLAYERS then
			return
		end

		local result = func(self, unique_id, player_info)

		if #self._party_widgets == before then
			add_party_member(self, unique_id, player_info)
		end

		return result
	end)

	mod:hook(SocialMenuRosterView, "_create_party_grid", function (func, self)
		local result = func(self)

		configure_party_panel(self)

		return result
	end)

	mod:hook(SocialMenuRosterView, "_update_party_list", function (func, self, party_members, force_update)
		local result = func(self, party_members, force_update)

		configure_party_panel(self)

		return result
	end)

	mod:hook(SocialMenuRosterView, "update", function (func, self, dt, t, input_service)
		local pass_input, pass_draw = func(self, dt, t, input_service)

		configure_party_panel(self)

		return pass_input, pass_draw
	end)

	mod:hook(SocialMenuRosterView, "_draw_widgets", function (func, self, dt, t, input_service, ui_renderer)
		if not Session.is_active() or not self._grids[ROSTER_GRID_INDEX] then
			return func(self, dt, t, input_service, ui_renderer)
		end

		local party_widgets = self._party_widgets
		local visibility = {}

		for i = 1, #party_widgets do
			local widget = party_widgets[i]

			visibility[i] = widget.visible
			widget.visible = false
		end

		local result = func(self, dt, t, input_service, ui_renderer)

		for i = 1, #party_widgets do
			party_widgets[i].visible = visibility[i]
		end

		return result
	end)

	mod:hook(SocialMenuRosterView, "_draw_roster_grid", function (func, self, dt, t, input_service, ui_renderer)
		local result = func(self, dt, t, input_service, ui_renderer)

		draw_realms_party_grid(self, ui_renderer)

		return result
	end)

	mod:hook(SocialMenuRosterView, "on_exit", function (func, self, ...)
		destroy_empty_slot_widgets(self)

		return func(self, ...)
	end)

	installed_roster_views[SocialMenuRosterView] = true
end

function SocialMenu.install(session)
	Session = session

	mod:hook_require(DEFINITIONS_PATH, function (Definitions)
		local RosterViewStyles = require(STYLES_PATH)
		local ScrollbarPassTemplates = require(SCROLLBAR_PASS_TEMPLATES_PATH)
		local UIWidget = require(UI_WIDGET_PATH)

		extend_party_panel_definition(Definitions, RosterViewStyles, ScrollbarPassTemplates, UIWidget)
	end)

	mod:hook_require(ROSTER_VIEW_PATH, function (SocialMenuRosterView)
		local Definitions = require(DEFINITIONS_PATH)
		local RosterViewStyles = require(STYLES_PATH)
		local UIWidget = require(UI_WIDGET_PATH)
		local UIWidgetGrid = require(UI_WIDGET_GRID_PATH)

		install_view_hooks(SocialMenuRosterView, Definitions, RosterViewStyles, UIWidget, UIWidgetGrid)
	end)
end

return SocialMenu
