return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`WhatTheLocalization` encountered an error loading the Darktide Mod Framework.")

		new_mod("WhatTheLocalization", {
			mod_script       = "WhatTheLocalization/scripts/mods/WhatTheLocalization/WhatTheLocalization",
			mod_data         = "WhatTheLocalization/scripts/mods/WhatTheLocalization/WhatTheLocalization_data",
			mod_localization = "WhatTheLocalization/scripts/mods/WhatTheLocalization/WhatTheLocalization_localization",
		})
	end,
	packages = {},
}
