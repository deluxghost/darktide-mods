local mod = get_mod("Realms")
local SoloPlay = get_mod("SoloPlay")

local LoadoutChanges = {}
local Session
local Preparation
local opened_by_realms = false

local VIEW_NAME = "inventory_background_view"

local function available()
	return Session.is_active()
		and Session.loadout_changes_allowed()
		and Managers.state
		and Managers.state.game_session ~= nil
		and not Preparation.is_waiting()
end

local function open_inventory()
	local ui_manager = Managers.ui

	if not ui_manager or ui_manager:chat_using_input() or ui_manager:view_active(VIEW_NAME) then
		return
	end

	opened_by_realms = ui_manager:open_view(VIEW_NAME, nil, nil, nil, nil, nil) and true or false
end

function LoadoutChanges.install(session, preparation)
	Session = session
	Preparation = preparation

	mod:hook(SoloPlay, "keybind_open_inventory", function (func, ...)
		if not Session.is_active() then
			return func(...)
		end
		if available() then
			open_inventory()
		end
	end)
end

function LoadoutChanges.update()
	if not opened_by_realms then
		return
	end

	local ui_manager = Managers.ui

	if not ui_manager or not ui_manager:view_active(VIEW_NAME) then
		opened_by_realms = false

		return
	end
	if not available() and not ui_manager:is_view_closing(VIEW_NAME) then
		ui_manager:close_view(VIEW_NAME, true)
	end
end

return LoadoutChanges
