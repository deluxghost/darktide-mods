local mod = get_mod("GoodOldOutlines")
local runtime = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/runtime/controller").new(mod)
local enemy_highlight = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/enemy_highlight")
local item_highlight = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/item_highlight")

local function update_enemy_highlight()
	enemy_highlight.set_hidden(mod:is_enabled() and mod:get("hide_mesh"))
end

mod.update = runtime.update

mod.on_enabled = function()
	runtime.request_enable()
	update_enemy_highlight()
	item_highlight.set_enabled(mod:get("highlight_tagged_items"))
end

local function disable()
	item_highlight.set_enabled(false)
	enemy_highlight.set_hidden(false)
	runtime.disable()
end

mod.on_disabled = disable
mod.on_unload = disable

mod.on_setting_changed = function(setting_id)
	if setting_id == "hide_mesh" then
		update_enemy_highlight()
	elseif setting_id == "highlight_tagged_items" then
		item_highlight.set_enabled(mod:is_enabled() and mod:get("highlight_tagged_items"))
	elseif setting_id == "item_outline_color" then
		item_highlight.update_color()
	end
end
