# Vanilla Crosshair Styles

There are 10 predefined crosshair styles, plus 1 that removes crosshair. You can find their definitions in Darktide source code under directory [`scripts/ui/hud/elements/crosshair/templates/`](https://github.com/Aussiemon/Darktide-Source-Code/tree/master/scripts/ui/hud/elements/crosshair/templates)

## - `assault`
Three prongs and a center dot.
```
  |
  ·
/   \
```

Examples: autopistol, recon lasgun hipfire

## - `bfg`
"Price tag" style crosshair.

Examples: stub revolver hipfire, Lucius hipfire, plasma gun

## - `charge_up`
Two brackets and a center dot.
```
( · )
```

Examples: force staves

## - `charge_up_ads`
Two farther spaced brackets.
```
(           )
```

Examples: Lucius ADS

## - `cross`
Four prongs and a center dot.
```
   |
-- · --
   |
```

Examples: some lasgun and autogun hipfire

## - `dot`
Only a center dot.
```
·
```

Examples: melee

## - `ironsight`
Nothing, only your iron/reflex sight.

Examples: majority of ADS

## - `projectile_drop`
Ballistic compensation reticle thing.
```
\   /
  +
  +
  +
```

Examples: Ogryn grenade weapons

## - `shotgun`
Four corners.
```
┌   ┐

└   ┘
```

Examples: shotguns

## - `shotgun_slug`
Almost the same as `cross`.

## - `shotgun_wide`
`shotgun` but wider.

## - `spray_n_pray`
Two angle brackets and a center dot.
```
<·>
```

Examples: braced autoguns, Ogryn MG

## - `none`
Nothing, usually used when reloading. Technically not a crosshair style.

This disables hitmarkers. Use `ironsight` if you want to keep them.
