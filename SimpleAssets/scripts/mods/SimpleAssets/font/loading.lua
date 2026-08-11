local mod = get_mod("SimpleAssets")

local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")

local loading = {}

local RESOURCE_TYPE = "slug"
local RESOURCE_PREFIX = "simple_assets/font/"
local VARIANTS = {
	{
		suffix = "",
		render_flags = function()
			return Gui.MultiLine + Gui.FormatDirectives
		end,
	},
	{
		suffix = "_no_render_flags",
	},
	{
		suffix = "_masked",
		render_flags = function()
			return Gui.MultiLine + Gui.Masked + Gui.FormatDirectives
		end,
	},
	{
		suffix = "_write_mask",
		render_flags = function()
			return Gui.MultiLine + Gui.WriteMask + Gui.FormatDirectives
		end,
	},
}

local persistent = mod:persistent_table("external_fonts")
persistent.registrations = persistent.registrations or {}

local function variant_names(font_type)
	local names = {}

	for i = 1, #VARIANTS do
		names[i] = font_type .. VARIANTS[i].suffix
	end

	return names
end

local function validate_font_type(font_type)
	if type(font_type) ~= "string" then
		error(string.format("Font type must be a string, got %s", type(font_type)))
	end
	if font_type == "" then
		error("Font type must not be empty")
	end
end

local function validate_slug_path(asset_path)
	if type(asset_path) ~= "string" then
		error(string.format("Font asset path must be a string, got %s", type(asset_path)))
	end
	if not asset_path:lower():match("%.slug$") then
		error("Font asset path must refer to a .slug file")
	end
end

local function check_aliases(font_type, resource, resolved_path)
	local definitions = Managers.font and Managers.font._font_definitions
	local names = variant_names(font_type)

	for i = 1, #names do
		local name = names[i]
		local registration = persistent.registrations[name]

		if registration and (registration.resource ~= resource or registration.path ~= resolved_path) then
			error(string.format("Font type is already registered by another external font: %s", name))
		end
		if definitions and definitions[name] and not registration then
			error(string.format("Font type conflicts with an existing engine font: %s", name))
		end
	end
end

local function register_font(font_type, resource, resolved_path)
	if not Managers.font then
		error("Managers.font is not available")
	end

	check_aliases(font_type, resource, resolved_path)

	local definitions = Managers.font._font_definitions
	local names = variant_names(font_type)

	for i = 1, #VARIANTS do
		local variant = VARIANTS[i]
		local name = names[i]

		definitions[name] = {
			path = {
				resource,
			},
			render_flags = variant.render_flags and variant.render_flags() or nil,
		}
		persistent.registrations[name] = {
			path = resolved_path,
			resource = resource,
		}
	end

	return font_type
end

loading.load_font = function(font_type, asset_path)
	validate_font_type(font_type)
	validate_slug_path(asset_path)

	local resource_name = RESOURCE_PREFIX .. font_type
	local request = resource_loading.prepare(RESOURCE_TYPE, resource_name, asset_path)

	check_aliases(font_type, request.name, request.path)

	return resource_loading.load_prepared(request):next(function(resource_name)
		return register_font(font_type, resource_name, request.path)
	end)
end

return loading
