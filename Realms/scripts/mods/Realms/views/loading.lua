local mod = get_mod("Realms")
local ConstantElementLoading = require("scripts/ui/constant_elements/elements/loading/constant_element_loading")
local MissionTemplates = require("scripts/settings/mission/mission_templates")

local Loading = {}
local Session
local Preparation

local function mission_intro_available()
	if not Session.is_active() or not Preparation.is_started() or Managers.ui:view_active("lobby_view") then
		return false
	end

	local mechanism_manager = Managers.mechanism

	if not mechanism_manager or not mechanism_manager._mechanism then
		return false
	end

	local mechanism_state = mechanism_manager:mechanism_state()

	if mechanism_state == "adventure_selected" or mechanism_state == "expedition_selected" then
		return false
	end

	local mechanism_data = mechanism_manager:mechanism_data()
	local mission = mechanism_data and MissionTemplates[mechanism_data.mission_name]
	local mission_brief_vo = mission and mission.mission_brief_vo

	return mission_brief_vo and mission_brief_vo.vo_events and #mission_brief_vo.vo_events > 0 or false
end

local function waiting_for_preparation()
	return Session.is_active() and not Preparation.is_started()
end

local function realms_view_settings(state_view_settings)
	local settings = table.clone(state_view_settings)

	for i = 1, #settings do
		local setting = settings[i]

		if setting.view_name == "mission_intro_view" then
			local original_validation = setting.validation_func
			local replacement = table.clone(setting)

			replacement.validation_func = function ()
				if waiting_for_preparation() then
					return false
				end

				local valid, context, settings_override = original_validation()

				if valid then
					return valid, context, settings_override
				end

				return mission_intro_available()
			end
			settings[i] = replacement
		elseif setting.view_name == "blank_view" then
			local original_validation = setting.validation_func
			local replacement = table.clone(setting)

			replacement.validation_func = function ()
				if waiting_for_preparation() then
					return false
				end

				return original_validation()
			end
			settings[i] = replacement
		end
	end

	return settings
end

function Loading.install(session)
	Session = session
	Preparation = mod._preparation

	mod:hook(ConstantElementLoading, "_update_state_views", function (func, self, state_view_settings)
		if not Session.is_active() then
			return func(self, state_view_settings)
		end

		return func(self, realms_view_settings(state_view_settings))
	end)
end

return Loading
