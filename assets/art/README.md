# Town map sprite set

Delivered **263 PNG sprites**: all **261 named keys** in `docs/ART-BRIEF-MAP.md`, plus `billboard_blank_x` and `billboard_blank_y` for fictional sponsor content. **Missing keys: none.** Every delivered key, file and animation anchor is listed in [manifest.json](manifest.json).

| Priority | Folder | Sprites |
| --- | --- | ---: |
| A | halls | 22 |
| A | utilities | 16 |
| A | construction | 6 |
| A | water | 24 |
| A | ground | 31 |
| A | vehicles | 56 |
| B | buildings/common | 43 |
| B | props | 46 |
| C | buildings/sunsprawl | 11 |
| C | buildings/oldbridge | 8 |

The vehicle list specifies 14 types/colour combinations × 4 directions = **56**, despite the brief's stated total of 72. All named combinations are delivered.

## Style and production method

The first sprite, `hall_balanced_t2_on`, locked the ivory, teal, mint and amber palette, upper-left lighting and architectural finish. It was fitted to the supplied 1024 template before producing the set. See `_preview/style-lock.png` and `_preview/master-template-check.png`.

Each original raster subject was created with the built-in image-generation tool. The shared prompt requested a transparent square canvas, parallel 2:1 dimetric projection, crisp miniature shapes readable at 65% zoom, upper-left sunlight, restrained lower-right contact shadows, and no text, numbers or logos. Each manifest entry's `notes` describes its subject. Campus variants referenced the locked master. Domestic and civic corrections used a traditional house reference; parks used the geometry template alone to avoid inheriting campus structures.

Technical processing cleaned alpha speckles, fitted slab corners to the template diamond, normalized ground/water edge colours, added transparent-edge RGB bleed, and reduced 1024 working images with Lanczos. Tall Oldbridge elevations were compressed above the base to preserve roof clearance. Vehicles were fitted to 128 canvases. Online/offline pairs share identical alpha and geometry; emissive areas are darkened in offline versions. Working PNGs are retained in `_preview/working/`.

Static fans remain in the images. Manifest `fans` lists [x,y,radius]; `steam` lists emission points; `hook` and `hub` mark the crane and turbine. Coordinates use final-canvas pixels. Billboard corners run top-left, top-right, bottom-right, bottom-left around the blank face. Sponsor names are intended to be rendered by the game.

## Grid decision

The selected **2×2 subdivision of each existing plot** is recorded as `source_plot_cells: [2,2]`; full-plot buildings also have `grid_footprint: [2,2]`. The source canvas and [128,136] plot anchor remain unchanged. Vehicle anchors are [64,84]. When composing vehicles at a plot centre, add [0,42] to that plot's top-corner position.

Construction with crews, the moratorium vote, and paying fictional sponsors are gameplay decisions for later integration. This delivery contains art only.

## Review and previews

Each folder has a labelled, native-size contact sheet under `_preview/`. Start with `town-final-context.png`; `vehicle-roof-correction.png` shows the corrected teal hatchback roof. Template, seam, scale and animation-anchor checks are also included.

Validated: 263 unique manifest keys and existing files, RGBA format, 256/128 canvas sizes, transparent backgrounds, plot horizontal/height bounds, exact opaque flat-tile diamonds, and identical on/off alpha. The native-size context and contact sheets were visually reviewed. In-game placement and animation still require integration testing.

Existing atlas PNG/JSON and both supplied templates retain their original SHA-256 hashes. No game scripts, scenes or project settings were edited for this delivery.
