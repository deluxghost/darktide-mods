local mod = get_mod("ShareTalents")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local TalentBuilderView = require("scripts/ui/views/talent_builder_view/talent_builder_view")
local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")

local function set_talents(view, arch, talents)
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local profile = player:profile()
	local profile_archetype = profile.archetype
	local archetype_name = profile_archetype.name
	if arch ~= archetype_name then
		mod:notify(mod:localize("err_archetype_mismatch"))
		return
	end
	local talent_layout_file_path = profile_archetype and profile_archetype.talent_layout_file_path
	local active_layout = talent_layout_file_path and require(talent_layout_file_path)
	if not active_layout then
		mod:dump({err = "active_layout not found"}, "share_talents_err", 2)
		mod:notify(mod:localize("err_unknown"))
		return
	end

	local selected_nodes = {}
	TalentLayoutParser.unpack_backend_data(active_layout, talents, selected_nodes)
	if table.size(selected_nodes) < 1 then
		mod:notify(mod:localize("err_invalid_code"))
		return
	end

	view:clear_node_points()
	view._node_widget_tiers = selected_nodes
	view:_refresh_all_nodes()
	Managers.event:trigger("event_player_talent_node_updated", view._node_widget_tiers)
end

local function clipboard_get_code()
	local s = string.sub(Clipboard:get() or "", 1, 300)
	local args = string.split(string.trim(s), " ")
	if #args < 2 then
		return
	end
	return args[1], args[2]
end

local button_def_table = {
	__share_talents_copy = {
		scenegraph_definition = {
			parent = "info_banner",
			vertical_alignment = "bottom",
			horizontal_alignment = "center",
			size = { 200, 36 },
			position = { 0, 38, 20 }
		},
		pressed_callback = function (self, widget)
			local layout = self:get_active_layout()
			local archetype_name = layout.archetype_name
			local code = TalentLayoutParser.pack_backend_data(self:get_active_layout(), self._node_widget_tiers)
			Clipboard.put(string.format("%s %s", archetype_name, code))
			mod:notify(mod:localize("msg_view_copied"))
		end,
		allow_readonly = true,
	},
	__share_talents_paste = {
		scenegraph_definition = {
			parent = "__share_talents_copy",
			vertical_alignment = "top",
			horizontal_alignment = "right",
			size = { 200, 36 },
			position = { 0, 42, 20 }
		},
		pressed_callback = function (self, widget)
			local clip_archetype, clip_code = clipboard_get_code()
			if not clip_archetype or not clip_code then
				mod:notify(mod:localize("err_clipboard_notfound"))
				return
			end
			set_talents(self, clip_archetype, clip_code)
		end
	},
}

mod:hook_require("scripts/ui/views/talent_builder_view/talent_builder_view_definitions", function (definitions)
	for name, button_def in pairs(button_def_table) do
		local button = UIWidget.create_definition(ButtonPassTemplates.terminal_button_small, name, {
			text = mod:localize("widget" .. name),
			view_name = button_def.view_name
		})
		definitions.widget_definitions[name] = button
		definitions.overlay_scenegraph_definition[name] = button_def.scenegraph_definition
	end
end)

mod:hook_safe(TalentBuilderView, "on_enter", function (self)
	for name, button_def in pairs(button_def_table) do
		local widget = self._widgets_by_name[name]
		if widget then
			widget.content.hotspot.pressed_callback = function ()
				button_def.pressed_callback(self, widget)
			end
		end
	end
end)

mod:hook(TalentBuilderView, "_allowed_node_input", function (func, self)
	local ret = func(self)
	for name, button_def in pairs(button_def_table) do
		local widget = self._widgets_by_name[name]
		if widget then
			if widget.content.hotspot.is_hover then
				return false
			end
		end
	end
	return ret
end)

mod:hook_safe(TalentBuilderView, "_update_button_statuses", function (self, dt, t)
	for name, button_def in pairs(button_def_table) do
		local widget = self._widgets_by_name[name]
		if widget then
			if (self._is_readonly or not self._is_own_player) and not button_def.allow_readonly then
				widget.content.hotspot.disabled = true
			else
				widget.content.hotspot.disabled = self:_is_handling_popup_window() or self._input_blocked
			end
		end
	end
end)
