local mod = get_mod("UrlProtocol")
local ffi = Mods.lua.ffi

local BRIDGE_PATH = "../mods/UrlProtocol/bin/darktide-link-bridge.dll"
local HANDLER_PATH = "../mods/UrlProtocol/bin/darktide-link-handler.exe"
local BUFFER_SIZE = 8192 + 1
local MB_ICONERROR = 0x10
local INTERNAL_NAMESPACE = "-"

local instances = mod:persistent_table("instances")

if instances.bridge == nil then
	ffi.cdef([[
		int DarktideLink_StartServer();
		int DarktideLink_StopServer();
		int DarktideLink_PollEvent(char* buffer, int buffer_size);
		int DarktideLink_ActivateWindow();
		void DarktideLink_ShowMessage(const char* title, const char* message, unsigned int flags);
		int DarktideLink_RegisterAsync(const char* handler_path);
	]])
	instances.bridge = ffi.load(BRIDGE_PATH)
end
local buffer = ffi.new("char[?]", BUFFER_SIZE)
local handlers = {}

local pending_social_find_code
local social_find_state
local social_find_view_opened
local social_find_roster_opened

if instances.bridge.DarktideLink_RegisterAsync(HANDLER_PATH) ~= 1 then
	mod:error(mod:localize("err_register_start_failed"))
end

if instances.bridge.DarktideLink_StartServer() ~= 1 then
	mod:error(mod:localize("err_link_start_failed"))
end

local function register_handler(namespace, path, handler)
	if string.sub(path, 1, 1) ~= "/" then
		mod:error("URL protocol path must start with '/'.")
		return
	end
	if type(handler) ~= "function" then
		mod:error("URL protocol handler must be a function.")
		return
	end

	handlers[namespace] = handlers[namespace] or {}
	handlers[namespace][path] = handler
end

local function unregister_handler(namespace, path)
	local namespace_handlers = handlers[namespace]
	if not namespace_handlers then
		return
	end

	namespace_handlers[path] = nil

	if next(namespace_handlers) == nil then
		handlers[namespace] = nil
	end
end

local function dispatch_event(event_json)
	local event = cjson.decode(event_json)
	local namespace = event.namespace
	local path = event.path

	local namespace_handlers = handlers[namespace]
	local handler = namespace_handlers and namespace_handlers[path]
	if not handler then
		local message = mod:localize("err_no_handler", namespace, path)
		instances.bridge.DarktideLink_ShowMessage(nil, message, MB_ICONERROR)
		return
	end

	instances.bridge.DarktideLink_ActivateWindow()
	local context = {
		raw_url = event.raw_url,
		path = path,
		query = event.query,
	}
	handler(context)
end

local function poll_bridge()
	if instances.bridge == nil then
		return
	end

	local result = instances.bridge.DarktideLink_PollEvent(buffer, BUFFER_SIZE)

	if result == 0 then
		return
	elseif result < 0 then
		mod:error(mod:localize("err_link_poll_failed", tostring(result)))
		return
	end

	dispatch_event(ffi.string(buffer))
end

local function start_social_find(code)
	pending_social_find_code = code
	social_find_state = "open_find_popup"
	social_find_view_opened = false
	social_find_roster_opened = false
end

local function cancel_social_find()
	pending_social_find_code = nil
	social_find_state = nil
	social_find_view_opened = nil
	social_find_roster_opened = nil
end

local function update_social_find()
	if not pending_social_find_code then
		return
	end

	local social_view = Managers.ui:view_instance("social_menu_view")
	if not social_view then
		if social_find_view_opened then
			cancel_social_find()
		end
		return
	end
	social_find_view_opened = true

	local roster_view = Managers.ui:view_instance("social_menu_roster_view")
	local roster_ready = social_view._active_view == "social_menu_roster_view"
		and roster_view
		and roster_view._event_list.event_player_profile_updated
	if not roster_ready then
		if social_find_roster_opened then
			cancel_social_find()
		end
		return
	end
	social_find_roster_opened = true

	if social_find_state == "open_find_popup" then
		local party_widget = roster_view._party_widgets[1]
		if not party_widget or not party_widget.content.player_info then
			return
		end

		roster_view:handle_find_player()
		social_find_state = "enter_code"
		return
	end

	local popup = roster_view._popup_menu
	if not popup then
		cancel_social_find()
		return
	end

	if social_find_state == "enter_code" then
		popup._widgets_by_name.fatshark_id_entry.content.input_text = pending_social_find_code
		social_find_state = "select_result"
		return
	end

	if social_find_state == "select_result" then
		local pressed_callback = popup._widgets_by_name.player_plaque.content.hotspot.pressed_callback
		if pressed_callback then
			pressed_callback()
			cancel_social_find()
		end
	end
end

mod.register = function(owner_mod, path, handler)
	register_handler(owner_mod:get_name(), path, handler)
end

mod.unregister = function(owner_mod, path)
	unregister_handler(owner_mod:get_name(), path)
end

mod.update = function()
	poll_bridge()
	update_social_find()
end

register_handler(INTERNAL_NAMESPACE, "/social/find", function(context)
	local code = context.query.code
	if type(code) ~= "string" or not string.match(code, "^%d%d%d%d%d%d%d%d%d%d$") then
		mod:error(mod:localize("err_invalid_friend_code"))
		return
	end

	local context = {
		hub_interaction = true
	}
	Managers.ui:open_view("social_menu_view", nil, nil, nil, nil, context)
	start_social_find(code)
end)
