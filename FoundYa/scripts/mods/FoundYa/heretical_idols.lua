local ColorUtilities = require("scripts/utilities/ui/colors")

local mod = get_mod("FoundYa")

local HERETICAL_IDOL_MARKER_TYPE = "interaction"
local HERETICAL_IDOL_ICON = "content/ui/materials/hud/interactions/icons/enemy"
local HERETICAL_IDOL_ICON_COLOR = { 255, 169, 255, 0 }
local HERETICAL_IDOL_INTERACTION_TYPE = "penance_collectible"
local HERETICAL_IDOL_UI_INTERACTION_TYPE = "pickup"

local heretical_idols = {}

local heretical_idol_interaction_data = {
	__foundya_heretical_idol = true,
	interaction_icon = function ()
		return HERETICAL_IDOL_ICON
	end,
	interaction_type = function ()
		return HERETICAL_IDOL_INTERACTION_TYPE
	end,
	show_marker = function ()
		return mod:get("add_heretical_idol_icon") ~= false
	end,
	ui_interaction_type = function ()
		return HERETICAL_IDOL_UI_INTERACTION_TYPE
	end,
	can_interact = function ()
		return false
	end,
}

local function is_heretical_idol_marker_data(data)
	return type(data) == "table" and rawget(data, "__foundya_heretical_idol") == true
end

heretical_idols.update_marker = function (widget, marker)
	if is_heretical_idol_marker_data(marker.data) then
		ColorUtilities.color_copy(HERETICAL_IDOL_ICON_COLOR, widget.style.icon.color)
	end
end

local function get_world_markers()
	local markers

	Managers.event:trigger("request_world_markers_list", function (world_markers)
		markers = world_markers
	end)

	return markers
end

local function is_heretical_idol_marker(marker)
	return marker.type == HERETICAL_IDOL_MARKER_TYPE and is_heretical_idol_marker_data(marker.data)
end

local function is_data_unit_valid(data)
	if not data or not data.unit or not Unit.alive(data.unit) then
		return false
	end

	return true
end

local function is_data_valid(data)
	if not is_data_unit_valid(data) or not data.section_id or not data.id then
		return false
	end

	return true
end

local function is_extension_active(extension)
	local destruction_info = extension._destruction_info
	if destruction_info and destruction_info.current_stage_index <= 0 then
		return false
	end

	local visibility_info = extension._visibility_info
	if visibility_info and visibility_info.visible == false then
		return false
	end

	return true
end

local function has_marker(data)
	local markers = get_world_markers()
	if not markers then
		return false
	end

	for i = 1, #markers do
		local marker = markers[i]

		if is_heretical_idol_marker(marker) and marker.unit == data.unit then
			return true
		end
	end

	return false
end

heretical_idols.add_marker = function (data)
	if not is_data_valid(data) or has_marker(data) then
		return
	end

	Managers.event:trigger("add_world_marker_unit", HERETICAL_IDOL_MARKER_TYPE, data.unit, nil, heretical_idol_interaction_data)
end

heretical_idols.remove_marker = function (data)
	if not is_data_unit_valid(data) then
		return
	end

	local markers = get_world_markers()
	if not markers then
		return
	end

	for i = #markers, 1, -1 do
		local marker = markers[i]

		if is_heretical_idol_marker(marker) and marker.unit == data.unit then
			Managers.event:trigger("remove_world_marker", marker.id)
		end
	end
end

heretical_idols.clear_markers = function ()
	local markers = get_world_markers()
	if not markers then
		return
	end

	for i = #markers, 1, -1 do
		local marker = markers[i]

		if is_heretical_idol_marker(marker) then
			Managers.event:trigger("remove_world_marker", marker.id)
		end
	end
end

heretical_idols.sync_extension = function (extension)
	local data = extension and extension._collectible_data
	if not is_data_unit_valid(data) then
		return
	end

	if is_data_valid(data) and is_extension_active(extension) then
		heretical_idols.add_marker(data)
	else
		heretical_idols.remove_marker(data)
	end
end

heretical_idols.sync_markers = function ()
	local extension_manager = Managers.state and Managers.state.extension
	local destructible_system = extension_manager and extension_manager:system("destructible_system")
	local unit_to_extension_map = destructible_system and destructible_system:unit_to_extension_map()

	if not unit_to_extension_map then
		return
	end

	local active_units = {}

	for _, extension in pairs(unit_to_extension_map) do
		local data = extension and extension._collectible_data

		if is_data_valid(data) and is_extension_active(extension) then
			active_units[data.unit] = true
			heretical_idols.add_marker(data)
		end
	end

	local markers = get_world_markers()
	if not markers then
		return
	end

	for i = #markers, 1, -1 do
		local marker = markers[i]

		if is_heretical_idol_marker(marker) and not active_units[marker.unit] then
			Managers.event:trigger("remove_world_marker", marker.id)
		end
	end
end

return heretical_idols
