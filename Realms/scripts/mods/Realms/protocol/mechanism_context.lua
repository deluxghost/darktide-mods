local mod = get_mod("Realms")
local MissionTemplates = require("scripts/settings/mission/mission_templates")

local MechanismContext = {}

local PREFIX = "realms-context:"
local PHASES = {
	preparing = true,
	started = true,
}

function MechanismContext.host_payload()
	local mechanism_manager = Managers.mechanism
	local mechanism_name = mechanism_manager and mechanism_manager:mechanism_name()

	if type(mechanism_name) ~= "string" then
		return nil, "Realms host mechanism is not ready"
	end

	local mechanism_data = mechanism_manager:mechanism_data()
	local mission_name = mechanism_data and mechanism_data.mission_name
	local mission_settings = mission_name and MissionTemplates[mission_name]
	local preparation_phase = mod._preparation.connection_phase()

	if not mission_settings or mission_settings.mechanism_name ~= mechanism_name then
		return nil, "Realms host mission context is unavailable"
	end
	if not PHASES[preparation_phase] then
		return nil, "Realms host preparation phase is unavailable"
	end

	return table.concat({
		PREFIX .. mechanism_name,
		mission_name,
		preparation_phase,
	}, ":")
end

function MechanismContext.decode_reply(mechanism_matched, reply_data)
	if not mechanism_matched or type(reply_data) ~= "string" or string.sub(reply_data, 1, #PREFIX) ~= PREFIX then
		return false, "Realms host did not provide a valid session context"
	end

	local mechanism_name, mission_name, preparation_phase = string.match(string.sub(reply_data, #PREFIX + 1), "^([^:]+):([^:]+):([^:]+)$")
	local mission_settings = mission_name and MissionTemplates[mission_name]

	if not mission_settings or mission_settings.mechanism_name ~= mechanism_name or not PHASES[preparation_phase] then
		return false, "Realms host mechanism context is invalid"
	end

	return {
		mechanism_name = mechanism_name,
		mission_name = mission_name,
		preparation_phase = preparation_phase,
	}
end

return MechanismContext
