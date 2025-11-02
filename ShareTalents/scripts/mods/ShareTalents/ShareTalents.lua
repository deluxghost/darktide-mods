local mod = get_mod("ShareTalents")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ProfileUtils = require("scripts/utilities/profile_utils")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local TalentBuilderView = require("scripts/ui/views/talent_builder_view/talent_builder_view")
local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")

local function string_trim_prefix(s, prefix)
	return (s:sub(0, #prefix) == prefix) and s:sub(#prefix+1) or s
end

local function show_msg(view, msg)
	if view then
		mod:notify(msg)
	else
		mod:echo(msg)
	end
end

local function set_success(view, player, data)
	local peer_id = player:peer_id()
	local local_player_id = player:local_player_id()
	local connection_manager = Managers.connection

	if connection_manager:is_host() then
		local profile_synchronizer_host = Managers.profile_synchronization:synchronizer_host()

		profile_synchronizer_host:profile_changed(peer_id, local_player_id)
	elseif connection_manager:is_client() then
		connection_manager:send_rpc_server("rpc_notify_profile_changed", peer_id, local_player_id)
	end

	if view then
		mod:notify(mod:localize("msg_view_pasted"))
	else
		mod:echo(mod:localize("msg_code_applied"))
	end
	return data
end

local function set_fail(view, result)
	local errors = result and result.body and result.body.errors

	show_msg(view, mod:localize("err_invalid_code"))
	Log.error("Talents", "couldn't set selected talents in backend")
	if errors then
		Log.error("Talents", "Message: %s", table.tostring(errors, 5))
	end
end

local function cmd_get_talents()
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local character_id = player and player:character_id()
	local profile = player:profile()
	local profile_archetype = profile.archetype
	local archetype_name = profile_archetype.name
	Managers.backend.interfaces.characters:get_talents_v2(character_id):next(function (code)
		if not code or string.sub(code, -1) == ";" then
			mod:echo(mod:localize("err_invalid_talents"))
			return
		end
		Clipboard.put(string.format("/usetalents %s %s", archetype_name, code))
		mod:echo(mod:localize("msg_code_copied"))
	end):catch(function (err)
		mod:dump({err = err}, "share_talents_err", 4)
		mod:echo(mod:localize("err_unknown"))
	end)
end

local function set_talents(view, arch, talents)
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local character_id = player:character_id()
	local profile = player:profile()
	local profile_archetype = profile.archetype
	local archetype_name = profile_archetype.name
	if arch ~= archetype_name then
		show_msg(view, mod:localize("err_archetype_mismatch"))
		return
	end
	local talent_layout_file_path = profile_archetype and profile_archetype.talent_layout_file_path
	local active_layout = talent_layout_file_path and require(talent_layout_file_path)
	if not active_layout then
		mod:dump({err = "active_layout not found"}, "share_talents_err", 2)
		show_msg(view, mod:localize("err_unknown"))
		return
	end
	local active_layout_version = active_layout.version
	local active_profile_preset_id = ProfileUtils.get_active_profile_preset_id()

	local selected_nodes = {}
	local points_spent_on_nodes = {}
	TalentLayoutParser.unpack_backend_data(active_layout, talents, selected_nodes)
	if table.size(selected_nodes) < 1 then
		show_msg(view, mod:localize("err_invalid_code"))
		return
	end

	local nodes = active_layout.nodes
	local num_nodes = #nodes
	for i = 1, num_nodes do
		local node = nodes[i]
		local widget_name = node.widget_name
		if selected_nodes[tostring(i)] then
			points_spent_on_nodes[widget_name] = selected_nodes[tostring(i)]
		end
	end
	if table.size(points_spent_on_nodes) < 1 then
		show_msg(view, mod:localize("err_invalid_code"))
		return
	end

	local talents_data = TalentLayoutParser.pack_backend_data(active_layout, points_spent_on_nodes)
	local promise = Managers.backend.interfaces.characters:set_talents_v2(character_id, talents_data)
	promise:next(function (data)
		if active_profile_preset_id then
			ProfileUtils.save_talent_nodes_for_profile_preset(active_profile_preset_id, points_spent_on_nodes, active_layout_version)
		end
		if view and Managers.ui:view_instance("talent_builder_view") then
			view:event_on_profile_preset_changed(ProfileUtils.get_profile_preset(ProfileUtils.get_active_profile_preset_id()), false)
		end
		set_success(view, player, data)
	end, set_fail):catch(function (err)
		set_fail(view, err)
	end)
end

local function clipboard_get_code()
	local s = string.sub(Clipboard:get() or "", 1, 300)
	if not string.starts_with(s, "/usetalents") then
		return
	end
	local args = string.split(string.trim(string_trim_prefix(s, "/usetalents")), " ")
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
			local code = TalentLayoutParser.pack_backend_data(self:get_active_layout(), self._points_spent_on_node_widgets)
			Clipboard.put(string.format("/usetalents %s %s", archetype_name, code))
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

mod:command("sharetalents", mod:localize("cmd_share"), function ()
	cmd_get_talents()
end)

mod:command("usetalents", mod:localize("cmd_use"), function (arch, talents)
	if not arch or not talents then
		mod:echo(mod:localize("err_argument"))
		return
	end
	set_talents(nil, arch, talents)
end)
