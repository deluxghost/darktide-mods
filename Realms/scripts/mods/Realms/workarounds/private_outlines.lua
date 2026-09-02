local mod = get_mod("Realms")

local PrivateOutlines = {}
local Session
local context_stack = {}
local replay_depth = 0
local state = mod:persistent_table("private_outline_state")

state.records = state.records or {}

local function outline_system()
	local extension_manager = Managers.state and Managers.state.extension

	if not extension_manager or not extension_manager:has_system("outline_system") then
		return nil
	end

	return extension_manager:system("outline_system")
end

local function reset_for_system(system)
	if state.outline_system == system then
		return
	end

	state.outline_system = system
	state.records = {}
	state.rendered_source = nil
end

local function valid_source(context)
	if not Session or not Session.is_active_host() or not context or not context.is_server then
		return nil
	end

	local player = context.player

	if not player or player.__deleted or not player:is_human_controlled() then
		return nil
	end

	return player
end

local function call_in_context(func, context, scope, ...)
	local player = valid_source(context)

	if not player and #context_stack == 0 then
		return func(...)
	end

	context_stack[#context_stack + 1] = player and {
		player = player,
		scope = scope,
	} or false

	local success, result = pcall(func, ...)

	context_stack[#context_stack] = nil

	if not success then
		error(result, 0)
	end

	return result
end

local function active_context()
	return context_stack[#context_stack]
end

local function record_for(context)
	local scope = context.scope
	local record = state.records[scope]

	if not record then
		record = {
			entries = setmetatable({}, {__mode = "k"}),
			player = context.player,
		}
		state.records[scope] = record
	end

	return record
end

local function add_entry(context, unit, outline_name)
	local record = record_for(context)
	local unit_entries = record.entries[unit]

	if not unit_entries then
		unit_entries = {}
		record.entries[unit] = unit_entries
	end

	unit_entries[outline_name] = (unit_entries[outline_name] or 0) + 1
end

local function remove_entry(context, unit, outline_name)
	local record = state.records[context.scope]

	if not record or record.player ~= context.player then
		return false
	end

	local unit_entries = record.entries[unit]
	local count = unit_entries and unit_entries[outline_name]

	if not count then
		return false
	end

	if count == 1 then
		unit_entries[outline_name] = nil

		if not next(unit_entries) then
			record.entries[unit] = nil
		end
	else
		unit_entries[outline_name] = count - 1
	end

	if not next(record.entries) then
		state.records[context.scope] = nil
	end

	return true
end

local function remove_unit_entries(unit)
	for scope, record in pairs(state.records) do
		record.entries[unit] = nil

		if not next(record.entries) then
			state.records[scope] = nil
		end
	end
end

local function apply_record_changes(system, record, method_name)
	for unit, unit_entries in pairs(record.entries) do
		if system._unit_extension_data[unit] then
			for outline_name, count in pairs(unit_entries) do
				for _ = 1, count do
					system[method_name](system, unit, outline_name)
				end
			end
		end
	end
end

local function apply_record(system, record, method_name)
	replay_depth = replay_depth + 1

	local success, result = pcall(apply_record_changes, system, record, method_name)

	replay_depth = replay_depth - 1

	if not success then
		error(result, 0)
	end
end

local function apply_source(system, player, method_name)
	for _, record in pairs(state.records) do
		if record.player == player then
			apply_record(system, record, method_name)
		end
	end
end

local function clear_scope(scope)
	local record = state.records[scope]

	if not record then
		return
	end

	local system = outline_system()

	if system and state.rendered_source == record.player then
		apply_record(system, record, "remove_outline")
	end

	state.records[scope] = nil
end

local function perspective_player()
	local player_manager = Managers.player
	local local_player = player_manager and player_manager:local_player(1)

	if not local_player or local_player.__deleted then
		return nil
	end

	local camera_handler = local_player.camera_handler

	if camera_handler and camera_handler:is_observing() then
		local followed_unit = camera_handler:camera_follow_unit()
		local followed_player = followed_unit and player_manager:player_by_unit(followed_unit)

		if followed_player and not followed_player.__deleted and followed_player:is_human_controlled() then
			return followed_player
		end
	end

	return local_player
end

local function sync_rendered_source()
	local system = outline_system()

	reset_for_system(system)

	if not Session or not Session.is_active_host() then
		if system and state.rendered_source then
			apply_source(system, state.rendered_source, "remove_outline")
		end

		state.records = {}
		state.rendered_source = nil

		return
	end

	local wanted_source = perspective_player()

	if state.rendered_source == wanted_source then
		return
	end

	if system and state.rendered_source then
		apply_source(system, state.rendered_source, "remove_outline")
	end

	state.rendered_source = wanted_source

	if system and wanted_source then
		apply_source(system, wanted_source, "add_outline")
	end
end

local function install_buff_extension_hooks(BuffExtensionBase)
	mod:hook(BuffExtensionBase, "_add_buff", function (func, self, ...)
		return call_in_context(func, self._buff_context, self, self, ...)
	end)

	mod:hook(BuffExtensionBase, "_remove_buff", function (func, self, index, ...)
		return call_in_context(func, self._buff_context, self, self, index, ...)
	end)

	mod:hook(BuffExtensionBase, "destroy", function (func, self, ...)
		local result = call_in_context(func, self._buff_context, self, self, ...)

		clear_scope(self)

		return result
	end)
end

local function install_player_unit_buff_hooks(PlayerUnitBuffExtension)
	mod:hook(PlayerUnitBuffExtension, "fixed_update", function (func, self, ...)
		return call_in_context(func, self._buff_context, self, self, ...)
	end)
end

local function install_outline_system_hooks(OutlineSystem)
	mod:hook(OutlineSystem, "add_outline", function (func, self, unit, outline_name)
		if replay_depth > 0 then
			return func(self, unit, outline_name)
		end

		local context = active_context()

		if not context then
			return func(self, unit, outline_name)
		end

		reset_for_system(self)

		local extension = self._unit_extension_data[unit]

		if not extension or not extension.settings[outline_name] then
			return func(self, unit, outline_name)
		end

		add_entry(context, unit, outline_name)

		if state.rendered_source == context.player then
			return func(self, unit, outline_name)
		end
	end)

	mod:hook(OutlineSystem, "remove_outline", function (func, self, unit, outline_name)
		if replay_depth > 0 then
			return func(self, unit, outline_name)
		end

		local context = active_context()

		if not context then
			return func(self, unit, outline_name)
		end

		reset_for_system(self)

		if not remove_entry(context, unit, outline_name) then
			return
		end

		if state.rendered_source == context.player then
			return func(self, unit, outline_name)
		end
	end)

	mod:hook(OutlineSystem, "remove_all_outlines", function (func, self, unit)
		local result = func(self, unit)

		if Session and Session.is_active_host() then
			reset_for_system(self)
			remove_unit_entries(unit)
		end

		return result
	end)
end

function PrivateOutlines.install(session)
	Session = session

	mod:hook_require("scripts/extension_systems/buff/buff_extension_base", install_buff_extension_hooks)
	mod:hook_require("scripts/extension_systems/buff/player_unit_buff_extension", install_player_unit_buff_hooks)
	mod:hook_require("scripts/extension_systems/outline/outline_system", install_outline_system_hooks)
end

function PrivateOutlines.update()
	sync_rendered_source()
end

return PrivateOutlines
