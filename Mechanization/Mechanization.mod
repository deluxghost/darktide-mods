return {
	run = function ()
		fassert(rawget(_G, "new_mod"), "`Mechanization` encountered an error loading the Darktide Mod Framework.")

		new_mod("Mechanization", {
			mod_script = "Mechanization/scripts/mods/Mechanization/Mechanization",
			mod_data = "Mechanization/scripts/mods/Mechanization/Mechanization_data",
			mod_localization = "Mechanization/scripts/mods/Mechanization/Mechanization_localization",
		})
	end,
	packages = {
		"content/levels/expeditions/opportunities/wastes/op_48m_power_station_002/world",
		"content/characters/enemy/valkyrie/third_person/attack_valkyrie",
		"content/levels/ui/mission_intro/mission_intro",
		"content/levels/ui/barber_character_mindwipe/barber_character_mindwipe",
		"content/levels/cinematics/c_cams/c_cam_no_mans_land/world",
		"content/fx/particles/explosions/tank_wall_explosion",
		"content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_charged",
		"content/fx/particles/weapons/rifles/lasgun/lasgun_beam_krieg_linger_bfg",
		"content/fx/particles/weapons/rifles/lasgun/lasgun_bfg_muzzle",
		"content/fx/particles/impacts/weapons/lasgun/lasgun_impact_surface_bfg_player",
	},
}
