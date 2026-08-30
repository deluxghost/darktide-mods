local mod = get_mod("Realms")

local RealmsPreparationState = class("RealmsPreparationState")

RealmsPreparationState.NEEDS_MISSION_LEVEL = false

RealmsPreparationState.on_enter = function (self, parent, params, creation_context)
	local preparation = mod._preparation

	self._creation_context = creation_context
	mod._session.preparation_state_entered()
	preparation.enter_state()

	Managers.player:on_game_state_enter(self, {}, {
		mission_name = preparation.mission_name(),
		mission_giver_vo = "none",
	})
end

RealmsPreparationState.on_exit = function (self)
	mod._preparation.exit_state()
	Managers.player:on_game_state_exit(self)
end

RealmsPreparationState.update = function (self, main_dt, main_t)
	local ui_manager = Managers.ui

	if ui_manager then
		ui_manager:handle_view_hotkeys()
	end

	local context = self._creation_context

	context.network_receive_function(main_dt)
	Managers.player:state_update(main_dt, main_t)

	local next_state, state_context = Managers.error:wanted_transition()

	if not next_state and (IS_XBS or IS_GDK or IS_PLAYSTATION) then
		next_state, state_context = Managers.account:wanted_transition()
	end
	if not next_state then
		mod._preparation.ensure_view()
		next_state, state_context = mod._session.poll_preparation_transition()
	end

	context.network_transmit_function()

	return next_state, state_context
end

return RealmsPreparationState
