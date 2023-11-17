# Crosshair Remap

Allows player to map a style of crosshair to another, including custom ones.

## Mod Behavior

1. Crosshair is unchanged when inspecting anything.
2. Melee weapons will use the ***Melee Weapons and Actions*** setting.
3. Ranged weapons: 
   1. Melee actions will use the ***Melee Weapons and Actions*** setting.
   2. Crosshair is unchanged when doing reload actions.
   3. Primary, secondary, and shotgun special actions will use the respective settings.
4. Others remain unchanged, except when no crosshair is present, at that time the ***When No Crosshair*** setting will be used.

## Map to Vanilla Crosshairs

Simply choose you desired crosshairs in the Mod Options.

For a list of vanilla crosshair styles, see [here](docs/vanilla_crosshairs.md).

## Map to Custom Crosshairs

Put your crosshair lua file(s) in `Warhammer 40,000 DARKTIDE/mods/crosshair_remap/custom_crosshairs/`, then add you filename(s) to `LIST.lua`. Your crosshair files will be loaded when the game boots. Remember to choose them in the Mod Options!

**NOTE:** The name of your file(s) must not be the same as [those predefined style names](docs/vanilla_crosshairs.md).

The mod comes with some custom crosshairs too. Take a look at the `custom_crosshairs/` directory.

## Making Custom Crosshairs

For now you can use in-game textures to compose your own crosshair.

WIP guide: [Making Crosshairs](docs/making_crosshairs.md)
