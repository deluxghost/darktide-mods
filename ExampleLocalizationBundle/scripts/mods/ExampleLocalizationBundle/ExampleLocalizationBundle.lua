local mod = get_mod("ExampleLocalizationBundle")
local WTL = get_mod("WhatTheLocalization")

mod.localization_templates = {
    -- quick examples (psuedo loc keys)
    -- remove them before publishing your bundle
    {
        id = "example_1",
        loc_keys = {
            "loc_example_1",
        },
        -- "locales" field is omitted, this fix will apply to all locales
        handle_func = function (locale, value, context)
            -- we only change parts of the official translation,
            -- game updates would be unlikely to break the fix.
            return string.gsub(value, "wrong", "correct")
        end,
    },
    {
        id = "example_2",
        loc_keys = {
            "loc_example_2",
        },
        locales = {
            "zh-cn",
        },
        handle_func = function (locale, value, context)
            -- we replace the entire translation, sometimes it's necessary,
            -- but it needs to be reviewed between game updates.
            return "this_is_the_new_translation"
        end,
    },
    {
        id = "example_3",
        loc_keys = {
            "loc_example_3",
        },
        locales = {
            "en",
        },
        handle_func = function (locale, value, context)
            -- we can change the context params before returning,
            -- unchanged params will stay.
            context.stacks = tostring(tonumber(context.stacks) * 3)
            return "+{stacks:%s} blabla for {time:%s} on kill"
        end,
    },
    -- add your localization templates here
}

-- tell WTL to reload while toggling this bundle
function mod.on_enabled()
    if WTL then
        WTL.reload_templates()
    end
end

function mod.on_disabled()
    if WTL then
        WTL.reload_templates()
    end
end
