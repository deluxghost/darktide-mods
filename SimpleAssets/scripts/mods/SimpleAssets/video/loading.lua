local mod = get_mod("SimpleAssets")

local native_runtime = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/runtime/native")
local resource_loading = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/loading")
local resource_replacement = mod:io_dofile("SimpleAssets/scripts/mods/SimpleAssets/resource/replacement")

local loading = {}

local VIDEO_TYPES = {
	[".bk2"] = "bk2",
	[".ivf"] = "ivf",
}

local function video_extension(path, name)
	if type(path) ~= "string" then
		error(string.format("%s must be a string, got %s", name, type(path)))
	end
	if path == "" then
		error(string.format("%s must not be empty", name))
	end

	local extension = path:match("(%.[^./\\]+)$")

	if extension then
		extension = extension:lower()
	end
	if not VIDEO_TYPES[extension] then
		error(string.format("%s must refer to an .ivf or .bk2 file", name))
	end

	return extension
end

local function start_video(request)
	return native_runtime.video_load(request.path)
end

local loaders = {}
local replacers = {}

for extension, resource_type in pairs(VIDEO_TYPES) do
	loaders[extension] = resource_loading.create_loader(resource_type, extension, start_video)
	replacers[extension] = resource_replacement.create_replacer(
		resource_type,
		extension,
		start_video,
		native_runtime.video_replace
	)
end

loading.load_video = function(asset_path)
	local extension = video_extension(asset_path, "Video asset path")

	return loaders[extension](asset_path)
end

loading.replace_video = function(target_resource_path, source_asset_path)
	local target_extension = video_extension(target_resource_path, "Target resource path")
	local source_extension = video_extension(source_asset_path, "Source asset path")

	if target_extension ~= source_extension then
		error("Video target and source paths must use the same .ivf or .bk2 extension")
	end

	return replacers[source_extension](target_resource_path, source_asset_path)
end

return loading
