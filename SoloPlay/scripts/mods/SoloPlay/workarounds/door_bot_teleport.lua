local mod = get_mod("SoloPlay")
local DoorExtension = require("scripts/extension_systems/door/door_extension")
local Blackboard = require("scripts/extension_systems/blackboard/utilities/blackboard")

local TELEPORT_NODE_NAMES = {
	"bot_teleport_location_01",
	"bot_teleport_location_02",
	"bot_teleport_location_03",
	"bot_teleport_location_04",
}

local function teleport_nodes(unit)
	if not Unit.has_node(unit, TELEPORT_NODE_NAMES[1]) then
		return
	end

	local nodes = {}
	for i = 1, #TELEPORT_NODE_NAMES do
		local name = TELEPORT_NODE_NAMES[i]
		if Unit.has_node(unit, name) then
			nodes[#nodes + 1] = Unit.node(unit, name)
		end
	end
	return nodes
end

local function teleport_node(nodes, index)
	-- Expanded bot and companion groups must share the level's existing safe destinations.
	return nodes[(index - 1) % #nodes + 1]
end

local function attach_companions(unit, companion_units, nodes, index)
	if not companion_units then
		return index
	end

	for i = 1, #companion_units do
		local companion_unit = companion_units[i]
		local blackboard = companion_unit and BLACKBOARDS[companion_unit]
		if companion_unit and Blackboard.has_component(blackboard, "movable_platform") then
			local component = Blackboard.write_component(blackboard, "movable_platform")
			component.node = teleport_node(nodes, index)
			component.unit_reference = unit
			index = index + 1
		end
	end
	return index
end

mod:hook(DoorExtension, "teleport_bots", function (func, self)
	if not mod.has_local_gameplay_authority() then
		return func(self)
	end

	local unit = self._unit
	local nodes = teleport_nodes(unit)
	if not nodes then
		return
	end

	local index = 1
	for _, bot_player in pairs(Managers.player:bot_players()) do
		local bot_unit = bot_player.player_unit
		if bot_unit then
			local node = teleport_node(nodes, index)
			local position = Unit.world_position(unit, node)
			local follow_component = Blackboard.write_component(BLACKBOARDS[bot_unit], "follow")
			follow_component.level_forced_teleport = true
			follow_component.level_forced_teleport_position:store(position)
			index = index + 1
		end
	end

	self:_teleport_companions(unit, index)
end)

mod:hook(DoorExtension, "_teleport_companions", function (func, self, unit, start_index)
	if not mod.has_local_gameplay_authority() then
		return func(self, unit, start_index)
	end

	local nodes = teleport_nodes(unit)
	if not nodes then
		return
	end

	local index = start_index
	for _, player in pairs(Managers.player:human_players()) do
		local player_unit = player.player_unit
		if player_unit then
			local spawner = ScriptUnit.extension(player_unit, "companion_spawner_system")
			index = attach_companions(unit, spawner:companion_units(), nodes, index)
		end
	end
end)
