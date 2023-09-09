# How to make a localization bundle

Read Web version of this guide at: https://github.com/deluxghost/darktide-mods/blob/main/ExampleLocalizationBundle/README.md

## 1. Setup mod file structure

If you are a modder already, you may want to skip this step. Otherwise, you can do this manually for now:

1. Choose a mod name, we use `LocalizationFixForZH` as an example here, but you need your own mod name
2. Rename every files and folders of this example mod by changing all `ExampleLocalizationBundle` to your mod name (e.g. `LocalizationFixForZH`). You will get structure like this:
  ```
  LocalizationFixForZH
   |- LocalizationFixForZH.mod
   `- scripts
       `- mods
           `- LocalizationFixForZH
               |- LocalizationFixForZH.lua
               |- LocalizationFixForZH_data.lua
               `- LocalizationFixForZH_localization.lua
  ```
3. Edit following files with any text editor, find text `ExampleLocalizationBundle` and replace them all with your mod name (e.g. `LocalizationFixForZH`). You can use "Find & Replace All" feature of your text editor (in most cases the hotkey is Ctrl+H), enter `ExampleLocalizationBundle` in the "Find" or "Search" textbox and enter `LocalizationFixForZH` in the "Replace" textbox, then press "Replace All".
   - LocalizationFixForZH.mod
   - LocalizationFixForZH.lua
   - LocalizationFixForZH_data.lua
   - LocalizationFixForZH_localization.lua
4. You can now edit your mod description in file e.g. `LocalizationFixForZH_localization.lua`

## 2. Prepare localization fixes

Tips: Debug mode and `/loc` command of "What The Localization" mod is very helpful

You need these info for every fix:

- The localization key, e.g. `loc_trait_bespoke_armor_rending_bayonette_desc`
- The target locale, e.g. `en`, `fr`, `zh-cn`...
- How to fix it

## 3. Write localization templates in your mod

You need to add templates to the `mod.localization_templates` table in `LocalizationFixForZH.lua` file

A template looks like this:

```lua
{
    id = "pinning_fire_desc_fix_zh_cn",
    loc_keys = {
        "loc_trait_bespoke_stacking_power_bonus_on_staggering_enemies_desc",
    },
    locales = {
        "zh-cn",
    },
    handle_func = function(locale, value)
        return string.gsub(value, ": ", ":")
    end,
},
```

- `id`: A name for this fix
- `loc_keys`: Which localization key(s) you want to fix, could be multiple if the `handle_func` can fix them all
- `locale`: The target locale(s), could be multiple if the `handle_func` can fix them all, could omit if the `handle_func` can fix for all locales
- `handle_func`: How to fix the localization. Argument `locale` is the current locale, `value` is the official translation string. You need to return your new translation as string value

Add as many templates as you need until the work is finished

## 4. Test and publish

Make sure "What The Localization" and your new mod to the `mod_load_order.txt` and launch the game. If everything works as intended, you can publish it to Nexusmods or everywhere you want. The localization mod needs "What The Localization" to work, so you also need to add "What The Localization" as a dependency on your Nexusmods page
