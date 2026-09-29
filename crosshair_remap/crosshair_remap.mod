return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`crosshair_remap` encountered an error loading the Darktide Mod Framework.")

        new_mod("crosshair_remap", {
            mod_script       = "crosshair_remap/scripts/mods/crosshair_remap/crosshair_remap",
            mod_data         = "crosshair_remap/scripts/mods/crosshair_remap/crosshair_remap_data",
            mod_localization = "crosshair_remap/scripts/mods/crosshair_remap/crosshair_remap_localization",
        })
    end,
    packages = {},
}
