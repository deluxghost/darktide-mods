local Damage = {}

Damage.profile = function (template, power, armor)
	local profile = table.clone(template)
	profile.power_distribution.attack = power
	for _, range in pairs(profile.armor_damage_modifier_ranged) do
		range.attack = table.clone(armor)
	end
	-- Target overrides otherwise retain the mission prop's original armor multipliers.
	for _, target in pairs(profile.targets) do
		target.armor_damage_modifier_ranged = nil
	end
	return profile
end

return Damage
