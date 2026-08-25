# SimpleAssets Documentation

`SimpleAssets` lets other Darktide mods load external assets and replace named engine resources at runtime without packaging them into bundle patches.

It supports:

- PNG, JPEG, and DDS files as texture objects;
- compiled Slug fonts and albums;
- PNG mouse cursors;
- IVF and Bink 2 BK2 videos.
- (unstable) compiled `.texture`, `.material`, `.particles`, `.unit`, and `.animation` resources as named engine resources;

## Getting started

- [Quick start](getting-started/quick-start.md)
- [Asset paths and resource names](getting-started/paths.md)

## API

- [Directories](api/directories.md)
- [Textures](api/textures.md)
- [Fonts](api/fonts.md)
- [Mouse cursors, videos, and Slug albums](api/ui-resources.md)
- [Compiled engine resources](api/engine-resources.md)
- [Resource replacement](api/resource-replacement.md)
