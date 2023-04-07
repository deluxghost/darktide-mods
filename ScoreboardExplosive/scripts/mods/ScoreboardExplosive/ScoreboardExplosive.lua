local mod = get_mod("ScoreboardExplosive")
local scoreboard = get_mod("scoreboard")

mod:hook(CLASS.AttackReportManager, "add_attack_result", function(
		func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot,
		damage, attack_result, attack_type, damage_efficiency, ...
	)
	local player = scoreboard:player_from_unit(attacking_unit)
	if player then
		local account_id = player:account_id() or player:name()
		local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
		local breed = unit_data_extension and unit_data_extension:breed()
		if breed and unit_data_extension:breed_name() == "hazard_prop" and damage == 0 and attack_type == nil then
			scoreboard:update_stat("scoreboard_explosive_ignited", account_id, 1)
		end
	end
	return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, ...)
end)

mod.scoreboard_rows = {
	{
		name = "scoreboard_explosive_ignited",
		text = "explosive_ignited",
		validation = "DESC",
		iteration = "ADD",
		group = "team",
		setting = "explosive_ignited",
	},
}
