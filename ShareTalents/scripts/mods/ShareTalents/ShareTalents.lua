local mod = get_mod("ShareTalents")
local ProfileUtils = require("scripts/utilities/profile_utils")
local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")

local function set_success(player, data)
	local peer_id = player:peer_id()
	local local_player_id = player:local_player_id()
	local connection_manager = Managers.connection

	if connection_manager:is_host() then
		local profile_synchronizer_host = Managers.profile_synchronization:synchronizer_host()

		profile_synchronizer_host:profile_changed(peer_id, local_player_id)
	elseif connection_manager:is_client() then
		connection_manager:send_rpc_server("rpc_notify_profile_changed", peer_id, local_player_id)
	end

	mod:echo(mod:localize("msg_code_applied"))
	return data
end

local function set_fail(result)
	local errors = result and result.body and result.body.errors

	mod:echo(mod:localize("err_invalid_code"))
	Log.error("Talents", "couldn't set selected talents in backend")
	if errors then
		Log.error("Talents", "Message: %s", table.tostring(errors, 5))
	end
end

local function get_talents()
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local character_id = player and player:character_id()
	local profile = player:profile()
	local profile_archetype = profile.archetype
	local archetype_name = profile_archetype.name
	Managers.backend.interfaces.characters:get_talents_v2(character_id):next(function(code)
		if not code or string.sub(code, -1) == ";" then
			mod:echo(mod:localize("err_invalid_talents"))
			return
		end
		Clipboard.put(string.format("/usetalents %s %s", archetype_name, code))
		mod:echo(mod:localize("msg_code_copied"))
	end):catch(function(err)
		mod:dump({err = err}, "share_talents_err", 4)
		mod:echo(mod:localize("err_unknown"))
	end)
end

local function set_talents(arch, talents)
	if not arch or not talents then
		mod:echo(mod:localize("err_argument"))
		return
	end
	local local_player_id = 1
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(local_player_id)
	local character_id = player:character_id()
	local profile = player:profile()
	local profile_archetype = profile.archetype
	local archetype_name = profile_archetype.name
	if arch ~= archetype_name then
		mod:echo(mod:localize("err_archetype_mismatch"))
		return
	end
	local talent_layout_file_path = profile_archetype and profile_archetype.talent_layout_file_path
	local active_layout = talent_layout_file_path and require(talent_layout_file_path)
	if not active_layout then
		mod:dump({err = "active_layout not found"}, "share_talents_err", 2)
		mod:echo(mod:localize("err_unknown"))
		return
	end
	local active_layout_version = active_layout.version
	local active_profile_preset_id = ProfileUtils.get_active_profile_preset_id()

	local selected_nodes = {}
	local points_spent_on_nodes = {}
	TalentLayoutParser.unpack_backend_data(active_layout, talents, selected_nodes)
	if table.size(selected_nodes) < 1 then
		mod:echo(mod:localize("err_invalid_code"))
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
		mod:echo(mod:localize("err_invalid_code"))
		return
	end

	local talents_data = TalentLayoutParser.pack_backend_data(active_layout, points_spent_on_nodes)
	local promise = Managers.backend.interfaces.characters:set_talents_v2(character_id, talents_data)
	promise:next(function(data)
		if active_profile_preset_id then
			ProfileUtils.save_talent_nodes_for_profile_preset(active_profile_preset_id, points_spent_on_nodes, active_layout_version)
		end
		set_success(player, data)
	end, set_fail):catch(function (err)
		set_fail(err)
	end)
end

mod:command("sharetalents", mod:localize("cmd_share"), function()
	get_talents()
end)

mod:command("usetalents", mod:localize("cmd_use"), function(arch, talents)
	set_talents(arch, talents)
end)
