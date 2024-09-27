local mod = get_mod("Mark9")
local LocalizationManager = require("scripts/managers/localization/localization_manager")

mod.on_enabled = function()
	table.clear(Managers.localization._string_cache)
end

mod.on_disabled = function()
	table.clear(Managers.localization._string_cache)
end

local prefixes = {
	"MK[%. ]", "Mk[%. ]", "MG[%. ]", "Мод%. ", "мод%. ",
}
local numbers = {
	I = "1", II = "2", III = "3", IV = "4", V = "5",
	VI = "6", VII = "7", VIII = "8", IX = "9", X = "10",
	XI = "11", XII = "12", XIII = "13", XIV = "14", XV = "15",
	XVI = "16", XVII = "17", XVIII = "18", XIX = "19", XX = "20",
}

local function replace_number(left, right)
	local num, suffix = string.match(right, "^([IVX]+)(.*)")
	if not num then
		return left .. right
	end
	return left .. numbers[num] .. suffix
end

local function try_once(text, start)
	local length = string.len(text)
	for _, prefix in ipairs(prefixes) do
		if string.find(text, prefix .. "[IVX]+") then
			local i_start, i_end = string.find(text, prefix, start)
			if i_start and i_end and length > i_end then
				return replace_number(string.sub(text, 1, i_end), string.sub(text, i_end + 1)), true, i_end
			end
		end
	end
	return text, false, 1
end

mod:hook(LocalizationManager, "_lookup", function(func, self, key)
	local ret = func(self, key)
	if not key then
		return ret
	end
	if not string.starts_with(key, "loc_weapon_mark_") then
		return ret
	end
	local text = string.gsub(ret, " ", " ")
	local ok = true
	local start = 1
	while ok do
		text, ok, start = try_once(text, start)
	end
	return text
end)
