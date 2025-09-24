local mod = get_mod("CorrectMissionVotingInfo")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")
local TextUtilities = require("scripts/utilities/ui/text")
local UIFonts = require("scripts/managers/ui/ui_fonts")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local MissionVotingView = require("scripts/ui/views/mission_voting_view/mission_voting_view")
local MissionDetailsBlueprints = require("scripts/ui/views/mission_voting_view/mission_voting_view_blueprints")

local AURIC_DANGER = DangerSettings[5]

mod:hook_safe(MissionVotingView, "_set_mission_data", function (self, mission_data)
	mod:dump(mission_data, "mission_data", 3)
	local auric = mission_data.challenge == AURIC_DANGER.challenge and mission_data.resistance == AURIC_DANGER.resistance
	local story = mission_data.category == "story"
	local event = mission_data.category == "event"
	local has_flash_mission = not not mission_data.flags.flash

	self._widgets_by_name.title_bar_bottom.visible = has_flash_mission or event or story
	local text = ""
	if event then
		text = Localize("loc_mission_board_mission_category_event")
	elseif story then
		text = Localize("loc_player_journey_campaign")
		local display_order = Managers.data_service.mission_board:index_in_campaign("mission", mission_data.map, mission_data.category, "player-journey")
		if display_order and display_order ~= "" then
			local roman_numaral = TextUtilities.convert_to_roman_numerals(display_order)
			text = string.format("%s %s", text, roman_numaral)
		end
	elseif auric and has_flash_mission then
		text = Localize("loc_group_finder_difficulty_auric") .. " " .. Localize("loc_mission_board_maelstrom_header")
	elseif has_flash_mission then
		text = Localize("loc_mission_board_maelstrom_header")
	end
	self._widgets_by_name.title_bar_bottom.content.text = text
end)

mod:hook_safe(MissionVotingView, "_set_rewards_info", function (self, mission_data)
	local main_mission_rewards_widget = self._widgets_by_name.reward_main_mission
	local rewards_string = " %d\t %d"
	local total_xp = math.floor(mission_data.xp)
	local total_credits = math.floor(mission_data.credits)
	if mission_data.extraRewards and mission_data.extraRewards.circumstance then
		local extraReward = mission_data.extraRewards.circumstance
		if extraReward.xp then
			total_xp = total_xp + math.floor(extraReward.xp)
		end
		if extraReward.credits then
			total_credits = total_credits + math.floor(extraReward.credits)
		end
	end
	main_mission_rewards_widget.content.reward_main_mission_text = string.format(rewards_string, total_credits, total_xp)
end)

mod:hook_require("scripts/ui/views/mission_voting_view/mission_voting_view_styles", function (MissionVotingViewStyles)
	MissionVotingViewStyles.blueprints.circumstance.rewards_text = table.clone(UIFontSettings.mission_detail_sub_header)
	MissionVotingViewStyles.blueprints.circumstance.rewards_text.text_horizontal_alignment = "left"
	MissionVotingViewStyles.blueprints.circumstance.rewards_text.text_color = Color.terminal_text_header(255, true)
end)

mod:hook_require("scripts/ui/views/mission_voting_view/mission_voting_view_blueprints", function (blueprints)
	local pass_template = blueprints.templates.circumstance.pass_template
	local exist = false
	for _, pass in ipairs(pass_template) do
		if pass.style_id == "rewards_text" then
			exist = true
			break
		end
	end
	if not exist then
		pass_template[#pass_template+1] = {
			value = "",
			value_id = "rewards_text",
			pass_type = "text",
			style_id = "rewards_text",
		}
	end
end)

mod:hook(MissionDetailsBlueprints.utility_functions, "prepare_details_data", function (func, mission_data, include_mission_header)
	local ret = func(mission_data, include_mission_header)
	if not ret then
		return ret
	end
	for _, data in ipairs(ret) do
		if data.template == "circumstance" then
			data.widget_data = data.widget_data or {}
			data.widget_data.extraRewards = mission_data.extraRewards
		end
	end
	return ret
end)

local function calculate_text_size(widget, text_and_style_id, ui_renderer)
	local text = widget.content[text_and_style_id]
	local text_style = widget.style[text_and_style_id]
	local text_options = UIFonts.get_font_options_by_style(text_style)
	local size = text_style.size or widget.content.size

	return UIRenderer.text_size(ui_renderer, text, text_style.font_type, text_style.font_size, size, text_options)
end

mod:hook_safe(MissionDetailsBlueprints.templates.circumstance, "init", function (widget, data, ui_renderer)
	local rewards = data.extraRewards and data.extraRewards.circumstance
	if rewards then
		local has_xp_reward = rewards.xp and true or false
		local has_salary_rewards = rewards.credits and true or false
		local experience = has_xp_reward and tostring(math.floor(rewards.xp)) or ""
		local experience_text = has_xp_reward and string.format(" %s", experience) or ""
		local salary = has_salary_rewards and tostring(math.floor(rewards.credits)) or ""
		local salary_text = has_salary_rewards and string.format(" %s", salary) or ""
		widget.content.rewards_text = string.format("%s \t %s", salary_text, experience_text)
	end
	local style = widget.style
	local text_x_offset = 60
	local text_padding = 10
	local rewards_text_style = style.rewards_text
	local _, body_text_height = calculate_text_size(widget, "body_text", ui_renderer)
	local reward_text_y_offset = style.body_text.offset[2] + text_padding + body_text_height
	rewards_text_style.offset = {
		text_x_offset,
		reward_text_y_offset,
		1,
	}
	local _, rewards_text_height = calculate_text_size(widget, "rewards_text", ui_renderer)
	local height = reward_text_y_offset + text_padding + rewards_text_height
	widget.content.size = { 475, height }
	widget.size = { 475, height }
end)
