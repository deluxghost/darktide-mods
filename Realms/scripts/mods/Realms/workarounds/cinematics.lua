local mod = get_mod("Realms")
local CinematicManager = require("scripts/managers/cinematic/cinematic_manager")
local CinematicSceneTemplates = require("scripts/settings/cinematic_scene/cinematic_scene_templates")

local Cinematics = {}

local function find_story(cinematic_manager, category, story_name)
	local stories = cinematic_manager._stories[category]

	if not stories then
		return
	end

	for i = 1, #stories do
		local story = stories[i]

		if story.name == story_name then
			return story
		end
	end
end

local function restore_story_options(story, cinematic_scene_name)
	local template = CinematicSceneTemplates[cinematic_scene_name]

	if not template then
		error(string.format("Cinematic scene template %s is unavailable", tostring(cinematic_scene_name)))
	end

	story.is_skippable = template.is_skippable
	story.wait_for_player_input = template.wait_for_player_input
	story.popup_info = template.popup_info
end

local function is_duplicate_level_load(cinematic_manager, cinematic_name, level_names, client_channel_id)
	local request_id = cinematic_name .. "_" .. tostring(client_channel_id)

	if not cinematic_manager._on_levels_spawned_callback[request_id] then
		return false
	end

	local loader = cinematic_manager._cinematic_level_loader

	if loader:currently_loading_cinematic_name() ~= cinematic_name then
		return false
	end

	for i = 1, #level_names do
		if not loader:has_level(level_names[i]) then
			return false
		end
	end

	return true
end

local function defer_story_sync(cinematic_manager, cinematic_scene_name, category, story_name, scene_unit_origin_level_id, scene_unit_destination_level_id, origin_level_name)
	local pending_syncs = cinematic_manager._realms_pending_story_syncs or {}

	pending_syncs[#pending_syncs + 1] = {
		category = category,
		cinematic_scene_name = cinematic_scene_name,
		origin_level_name = origin_level_name,
		scene_unit_destination_level_id = scene_unit_destination_level_id,
		scene_unit_origin_level_id = scene_unit_origin_level_id,
		story_name = story_name,
	}
	cinematic_manager._realms_pending_story_syncs = pending_syncs
end

local function flush_story_syncs(cinematic_manager)
	local pending_syncs = cinematic_manager._realms_pending_story_syncs

	if not pending_syncs then
		return
	end

	local remaining_syncs = {}

	for i = 1, #pending_syncs do
		local sync = pending_syncs[i]

		if find_story(cinematic_manager, sync.category, sync.story_name) then
			cinematic_manager:_client_cinematic_story_sync(
				sync.cinematic_scene_name,
				sync.category,
				sync.story_name,
				sync.scene_unit_origin_level_id,
				sync.scene_unit_destination_level_id,
				sync.origin_level_name
			)
		else
			remaining_syncs[#remaining_syncs + 1] = sync
		end
	end

	cinematic_manager._realms_pending_story_syncs = #remaining_syncs > 0 and remaining_syncs or nil
end

function Cinematics.install(Session)
	mod:hook(CinematicManager, "load_levels", function (func, self, cinematic_name, level_names, on_levels_spawned_callback, client_channel_id, hotjoin_only, load_only, preload_id)
		if Session.is_active_client() and is_duplicate_level_load(self, cinematic_name, level_names, client_channel_id) then
			return
		end

		return func(self, cinematic_name, level_names, on_levels_spawned_callback, client_channel_id, hotjoin_only, load_only, preload_id)
	end)

	mod:hook(CinematicManager, "_client_cinematic_story_sync", function (func, self, cinematic_scene_name, category, story_name, scene_unit_origin_level_id, scene_unit_destination_level_id, origin_level_name)
		if not Session.is_active_client() then
			return func(self, cinematic_scene_name, category, story_name, scene_unit_origin_level_id, scene_unit_destination_level_id, origin_level_name)
		end

		local story = find_story(self, category, story_name)

		if not story then
			defer_story_sync(self, cinematic_scene_name, category, story_name, scene_unit_origin_level_id, scene_unit_destination_level_id, origin_level_name)

			return
		end

		local result = func(self, cinematic_scene_name, category, story_name, scene_unit_origin_level_id, scene_unit_destination_level_id, origin_level_name)

		restore_story_options(story, cinematic_scene_name)

		return result
	end)

	mod:hook(CinematicManager, "register_story", function (func, self, params)
		local result = func(self, params)

		if self._realms_pending_story_syncs then
			flush_story_syncs(self)
		end

		return result
	end)
end

return Cinematics
