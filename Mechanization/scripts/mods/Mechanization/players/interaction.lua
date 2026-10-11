local Interaction = { elapsed = 0 }
local HOLD_TIME = 1

Interaction.reset = function ()
	Interaction.elapsed = 0
	Interaction.context = nil
	Interaction.held = false
	Interaction.consumed = false
	Interaction.unit = nil
end

Interaction.update = function (unit, context, held, blocked, dt)
	local previous = Interaction.held
	if unit ~= Interaction.unit or context ~= Interaction.context or blocked then
		Interaction.elapsed = 0
		-- A held key belongs to the context in which it was pressed.
		Interaction.consumed = previous or blocked
	end
	Interaction.unit = unit
	Interaction.context = context
	Interaction.held = held
	if not held then
		local tap = previous and not Interaction.consumed and Interaction.elapsed < HOLD_TIME and context ~= nil
		Interaction.elapsed = 0
		Interaction.consumed = false
		return tap and "tap" or nil
	end
	if not context or Interaction.consumed then
		return
	end
	Interaction.elapsed = Interaction.elapsed + dt
	if Interaction.elapsed >= HOLD_TIME then
		Interaction.consumed = true
		return "hold"
	end
end

Interaction.blocks_input = function (unit)
	return Interaction.unit == unit and (Interaction.context ~= nil or Interaction.held and Interaction.consumed)
end

Interaction.progress = function ()
	return math.clamp(Interaction.elapsed / HOLD_TIME, 0, 1)
end

return Interaction
