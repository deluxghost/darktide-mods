local utilities = {}

local SOUND_TYPE = {
	["nil"] = "2d_sound",
	["boolean"] = "start_stop_event",
	["number"] = "source_sound",
	["Vector3"] = "3d_sound",
	["Unit"] = "unit_sound",
}

utilities.userdata_type = function(value)
	if type(value) ~= "userdata" then
		return nil
	end

	if Unit.alive(value) then
		return "Unit"
	elseif Vector3.is_valid(value) then
		return "Vector3"
	end
end

utilities.sound_type = function(value)
	local value_type = utilities.userdata_type(value) or type(value)

	return SOUND_TYPE[value_type] or value_type
end

utilities.copy_list = function(list)
	local copy = {}

	for i = 1, #list do
		copy[i] = list[i]
	end

	return copy
end

return utilities
