local mod = get_mod("SoloPlay")

local ORIGINAL_BOT_COUNT = 3
local DISTANCE_EPSILON = 0.001
local units = {}
local tested_points = {}
local current_solution = {}
local best_solution = {}
local best_prefix_utilities = {}
local point_masks = {}

local function find_assignment(index, used_points, utility, data, best_utility)
	-- The same remaining assignment cannot improve an earlier, better prefix.
	local previous_utility = best_prefix_utilities[used_points]
	if previous_utility and previous_utility >= utility then
		return best_utility
	end
	best_prefix_utilities[used_points] = utility

	local num_units = #units
	if index > num_units then
		if utility > best_utility then
			for i = 1, num_units do
				best_solution[i] = current_solution[i]
			end
			return utility
		end
		return best_utility
	end

	-- Sum in the original order, allowing each remaining bot its best unused point.
	-- This bound stays optimistic even with floating-point rounding or duplicate points.
	local upper_bound = utility
	for i = index, num_units do
		local utilities = data[units[i]].nav_point_utility
		local maximum = -math.huge
		for j = 1, num_units do
			if not tested_points[j] and utilities[j] > maximum then
				maximum = utilities[j]
			end
		end
		upper_bound = upper_bound + maximum
	end
	if upper_bound <= best_utility then
		return best_utility
	end

	local utilities = data[units[index]].nav_point_utility
	for i = 1, num_units do
		if not tested_points[i] then
			current_solution[index] = i
			tested_points[i] = true
			best_utility = find_assignment(index + 1, used_points + point_masks[i], utility + utilities[i], data, best_utility)
			tested_points[i] = false
		end
	end
	return best_utility
end

mod:hook("BotGroup", "_assign_destination_points", function (func, self, bot_data, points, follow_unit, follow_unit_table)
	if not mod.has_local_gameplay_authority() or self._num_bots <= ORIGINAL_BOT_COUNT then
		return func(self, bot_data, points, follow_unit, follow_unit_table)
	end

	local distance = Vector3.distance
	for unit, data in pairs(bot_data) do
		local utilities = data.nav_point_utility
		table.clear(utilities)
		local position = POSITION_LOOKUP[unit]
		for i = 1, #points do
			utilities[i] = 1 / math.sqrt(math.max(DISTANCE_EPSILON, distance(position, points[i])))
		end
		units[#units + 1] = unit
	end
	for i = 1, #units do
		point_masks[i] = 2 ^ (i - 1)
	end

	find_assignment(1, 0, 0, bot_data, -math.huge)

	for i = 1, #units do
		local data = bot_data[units[i]]
		local hold_position = data.behavior_extension:hold_position()
		if hold_position then
			data.follow_position = hold_position
			data.follow_unit = nil
		else
			local point_index = best_solution[i]
			data.follow_position = points[point_index]
			if follow_unit_table then
				data.follow_unit = follow_unit_table[point_index]
			elseif follow_unit then
				data.follow_unit = follow_unit
			else
				data.follow_unit = nil
			end
		end
	end

	table.clear(units)
	table.clear(tested_points)
	table.clear(current_solution)
	table.clear(best_solution)
	table.clear(best_prefix_utilities)
end)
