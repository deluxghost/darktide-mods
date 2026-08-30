local mod = get_mod("Realms")
local UIConstantElements = require("scripts/managers/ui/ui_constant_elements")

local PreparationChat = {}
local VIEW_NAME = "realms_preparation_view"
local VISIBILITY_GROUP_NAME = "realms_preparation"
local previous_layout

local function chat_element()
	local constant_elements = Managers.ui and Managers.ui:ui_constant_elements()

	return constant_elements and constant_elements._elements.ConstantElementChat
end

function PreparationChat.capture_layout()
	local chat = chat_element()
	local chat_window = chat and chat._ui_scenegraph.chat_window

	if not chat_window then
		return
	end

	previous_layout = {
		horizontal_alignment = chat_window.horizontal_alignment,
		vertical_alignment = chat_window.vertical_alignment,
		chat_window_offset = table.clone(chat_window.position),
		chat_window_size = table.clone(chat_window.size),
	}
end

function PreparationChat.restore_layout()
	local chat = chat_element()

	if chat and previous_layout then
		chat:set_visible(false, previous_layout)
	end

	previous_layout = nil
end

local function install_visibility_group(constant_elements)
	local visibility_groups = constant_elements._visibility_groups
	local preparation_group_index
	local in_view_group

	for i = 1, #visibility_groups do
		local group = visibility_groups[i]

		if group.name == VISIBILITY_GROUP_NAME then
			return
		elseif group.name == "mission_lobby" then
			preparation_group_index = i
		elseif group.name == "in_view" then
			in_view_group = group
		end
	end

	local visibility_parameters = constant_elements._visibility_group_parameters
	local chat_parameters = visibility_parameters.mission_lobby.ConstantElementChat
	local visible_elements = setmetatable({
		ConstantElementChat = true,
	}, {
		__index = in_view_group.visible_elements,
	})

	table.insert(visibility_groups, preparation_group_index, {
		name = VISIBILITY_GROUP_NAME,
		validation_function = function ()
			return Managers.ui:view_active(VIEW_NAME)
		end,
		visible_elements = visible_elements,
	})
	visibility_parameters[VISIBILITY_GROUP_NAME] = setmetatable({
		ConstantElementChat = chat_parameters,
	}, {
		__index = visibility_parameters.in_view,
	})
	constant_elements._current_group_name = nil
end

function PreparationChat.install()
	mod:hook(UIConstantElements, "init", function (func, self, ...)
		local result = func(self, ...)

		install_visibility_group(self)

		return result
	end)

	local constant_elements = Managers.ui and Managers.ui:ui_constant_elements()

	if constant_elements then
		install_visibility_group(constant_elements)
	end
end

return PreparationChat
