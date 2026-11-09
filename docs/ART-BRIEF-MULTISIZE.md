# Art brief 2: multi-size buildings for Grid 2.0

**For:** the art agent that delivered `assets/art/` (263 sprites, November 2026).
**Status of that delivery:** fully integrated in the game. Every hall, utility, home, shop,
civic building, park, landmark, river tile, bridge, road, vehicle, construction stage and
prop now draws on the live map. Thank you: the style lock held across the whole set.

**What this brief adds:**
- Grid 2.0 splits every plot into 2×2 **cells**. The first delivery is the 2×2 size of
  everything.
- Buildings now need **other footprints**: small 1×1 homes and shops, 1×2 rows, 2×3 civic
  buildings, and bigger 3×2 and 3×3 server halls. Those sizes make the town look organic
  and turn campus growth into a land puzzle.
- It also lists a handful of small gaps found during integration (section 5).

Same style, palette, light and rules as `docs/ART-BRIEF-MAP.md` unless this brief says
otherwise. Keep using the locked master `hall_balanced_t2_on` as the style reference.

---

## 1. Geometry (exact)

A **cell** is half a current plot. At native sprite scale its ground diamond is **84 × 42 px**,
and the scale (pixels per metre) is unchanged from the first delivery.

A footprint is `w × h` cells:
- `w` runs along **x**: down-right on screen.
- `h` runs along **y**: down-left on screen.

With the **anchor A** at the footprint's top corner, the ground diamond is:

| Corner | Position |
| --- | --- |
| top | A |
| right | A + (42·w, 21·w) |
| bottom | A + (42·(w − h), 21·(w + h)) |
| left | A + (−42·h, 21·h) |

Canvas and anchor by footprint (templates in `assets/art/_templates/footprint-<w>x<h>.png`):

| Footprint | Canvas | Anchor A | Right | Bottom | Left | Tallest (coral line) |
| --- | --- | --- | --- | --- | --- | --- |
| 1×1 | 256 × 256 | (128, 136) | (170, 157) | (128, 178) | (86, 157) | y = 8 |
| 1×2 | 256 × 256 | (128, 136) | (170, 157) | (86, 199) | (44, 178) | y = 8 |
| 2×1 | 256 × 256 | (128, 136) | (212, 178) | (170, 199) | (86, 157) | y = 8 |
| 2×2 | 256 × 256 | (128, 136) | (212, 178) | (128, 220) | (44, 178) | y = 8 (the current set) |
| 3×2 | **384 × 384** | (192, 216) | (318, 279) | (234, 321) | (108, 258) | y = 16 |
| 2×3 | **384 × 384** | (192, 216) | (276, 258) | (150, 321) | (66, 279) | y = 16 |
| 3×3 | **384 × 384** | (192, 216) | (318, 279) | (192, 342) | (66, 279) | y = 16 |

**Rules:**
- The 2×2 row equals the current plot diamond, so the first delivery already is the 2×2 size.
- Ground contact fills the diamond: inset 4–10 px for a plinth or sidewalk.
- Nothing may cross the left or right corner. Stay below the coral line.
- One storey is about 28 px; the faint lines on the templates mark storeys.
- Fill the cell grid lines on the template with real ground detail: paths, gardens, parking.
  Do not leave blank lawn.

**Both orientations.** A footprint and its mirror (1×2 and 2×1, or 3×2 and 2×3) are **separate
paintings** with the same upper-left light. Do not flip an image, which would move the light.
Name them `_x` (long side along x) and `_y` (long side along y).

---

## 2. Priority A: server halls in three sizes

The current halls become size **S** (2×2). Add **M** (3×2, long side along x) and **L** (3×3).
- Bigger halls are **wider and longer, not just taller**: more roof plant, a loading dock,
  and a second entrance.
- Tier still adds storeys and equipment, as in the S set.
- Each hardware keeps its identity:
  - balanced: ivory and teal;
  - efficient: green roofs, solar and pipework;
  - refurbished: red brick with an industrial retrofit;
  - training: graphite with an orange glow.

| Keys | Count |
| --- | ---: |
| `hall_<hardware>_m_t<1-3>_<on\|off>` for balanced, efficient, refurbished, training | 24 |
| `hall_<hardware>_l_t<1-3>_<on\|off>` for the same four | 24 |
| `hall_training_t1_on`, `hall_training_t1_off` (size S; training now needs a t1 too) | 2 |

**Requirements:**
- Record **every roof fan** in `fans` as `[x, y, r]`.
- `_on` and `_off` pairs must have identical alpha. Make each `_off` from its `_on`.
- M is only needed with the long side along x; the game rotates the plot instead.

## 3. Priority A: utilities in two more sizes

| Keys | Footprint | Count |
| --- | --- | ---: |
| `power_pad_t<1-3>_<on\|off>`: compact pad transformer, fenced | 2×1 | 6 |
| `power_yard_t<1-3>_<on\|off>`: big switchyard with gantries; t3 has the tall HV tower | 3×2 | 6 |
| `cooling_block_t<1-3>_<on\|off>`: a row of dry coolers | 1×2 | 6 |
| `cooling_plant_l_t<1-3>_<on\|off>`: large plant with towers (t2 and t3 show steam stacks) | 3×2 | 6 |
| `cooling_riverfront_t1_off` (S): the missing pair of the riverfront plant | 2×2 | 1 |

Record `fans` on every cooling sprite and `steam` points on the towers.

## 4. Priority B: a town of varied sizes

Same materials and colours as the matching 2×2 buildings, so a street can mix sizes.

| Keys | Footprint | Count |
| --- | --- | ---: |
| `home_cottage_0…5`: small one or two storey homes with a tiny garden | 1×1 | 6 |
| `shop_corner_0…5`: narrow shops with a flat above (bakery, café, books, grocer, pharmacy, hardware; pictogram signs) | 1×1 | 6 |
| `home_row_x_0…2`, `home_row_y_0…2`: a row of 3 terraced houses | 1×2 / 2×1 | 6 |
| `shop_row_x_0…1`, `shop_row_y_0…1`: high-street parade of 2–3 shops | 1×2 / 2×1 | 4 |
| `home_apartment_large_x`, `_y`: 4–5 storey block with balconies | 3×2 / 2×3 | 2 |
| `civic_school_x/_y`, `civic_town_hall_x/_y`, `civic_clinic_x/_y` | 3×2 / 2×3 | 6 |
| `ind_factory_large_x`, `_y` (sawtooth roof, yard) | 3×2 / 2×3 | 2 |
| `landmark_statue_s`, `landmark_obelisk_s`, `landmark_fountain_s` | 1×1 | 3 |
| `park_pocket_0…2`: tiny park with bench, tree and flowerbed | 1×1 | 3 |

**Per-town additions (priority C):**

| Keys | Footprint | Count |
| --- | --- | ---: |
| Sunsprawl: `home_stucco_small_0…2` | 1×1 | 3 |
| Sunsprawl: `shop_strip_x`, `shop_strip_y` (a strip mall) | 1×2 / 2×1 | 2 |
| Oldbridge: `home_townhouse_row_x_0…1`, `home_townhouse_row_y_0…1` | 1×2 / 2×1 | 4 |
| Oldbridge: `civic_guildhall_x`, `civic_guildhall_y` | 3×2 / 2×3 | 2 |
| Oldbridge: `landmark_cathedral_l` (the tallest sprite in the game, up to the coral line) | 3×3 | 1 |

## 5. Priority A: gaps found during integration

| Keys | Why | Count |
| --- | --- | ---: |
| `site_foundation_m/_l`, `site_frame_low_m/_l`, `site_frame_high_m/_l`, `rubble_m/_l` | Construction and demolition for M and L footprints (3×2 and 3×3). The crane is reused. | 8 |
| `site_foundation_s1`, `rubble_s1` | Construction and demolition for 1×1 cells | 2 |
| `lot_owned_cell`, `lot_unowned_cell` | Ownership is per cell in Grid 2.0 | 2 |
| `road_x_dry_0`, `road_y_dry_0`, `junction_dry_0`, `crossing_x_dry`, `crossing_y_dry`, `lot_owned_dry` | Sunsprawl: the green verges stand out against the dry town | 6 |
| `road_bus_stop_y` | Only the x lay-by exists | 1 |
| `fan_rotor_0` (128 canvas, centre (64, 64)): 3-blade rotor seen from above at the 2:1 projection, transparent around it | The game spins a rotor over each recorded fan. Today it draws simple blade lines over the painted fan. | 1 |
| `wind_turbine_mast` plus `wind_turbine_rotor` (rotor on a 128 canvas, hub at the centre) | So the countryside turbines can turn; the current sprite has the blades painted on | 2 |

---

## 6. Manifest

Extend `assets/art/manifest.json`. **Do not change existing entries.** New fields:

```json
{
  "key": "hall_efficient_m_t2_on",
  "file": "halls/hall_efficient_m_t2_on.png",
  "category": "hall",
  "canvas": [384, 384],
  "anchor": [192, 216],
  "footprint": "cells",
  "grid_footprint": [3, 2],
  "fans": [[x, y, r]],
  "steam": [],
  "notes": "...",
  "priority": "A"
}
```

- `grid_footprint` is `[w, h]` in cells. Leave `source_plot_cells` out of the new entries.
- Keep `fans`, `steam`, `hook` and `hub` as in the first delivery.
- Add a contact sheet per folder to `_preview/`.
- Add a context check `_preview/grid2-context.png`: a mixed street of 1×1, 1×2, 2×2, 3×2 and
  3×3 sprites on one cell grid.
- Then run `godot --headless --path . --script res://dev/pack_town_art.gd` to confirm that
  everything packs.

**Totals:**
- Priority A: 50 halls + 25 utilities + 22 gap items = **97**.
- Priority B: **38**.
- Priority C: **12**.
- Grand total: **147**.

If time is short, deliver in order:
1. The M halls.
2. The 1×1 homes and shops.
3. The M and L construction stages.
4. The L halls.

---

## Message to paste to the art agent

> Your 263 sprites are in the game and look great; thank you. Next is Grid 2.0, where every
> plot becomes 2×2 cells. Your first set is the 2×2 size of everything. Now I need the other
> sizes. Please follow `docs/ART-BRIEF-MULTISIZE.md`.
>
> The exact geometry is in section 1:
> - a cell diamond is 84 × 42 px;
> - 1×1, 1×2 and 2×1 use the 256 canvas with anchor (128, 136);
> - 3×2, 2×3 and 3×3 use a 384 canvas with anchor (192, 216).
>
> Templates for every footprint are in `assets/art/_templates/footprint-<w>x<h>.png`. Paint
> mirrored footprints separately so the light stays upper-left; never flip.
>
> Priority A:
> - M (3×2) and L (3×3) server halls for all four hardware types, t1–t3, on and off;
> - `hall_training_t1`;
> - two new sizes for substations and cooling;
> - construction stages and rubble for M, L and 1×1;
> - per-cell lot tiles;
> - Sunsprawl dry roads;
> - `road_bus_stop_y`;
> - a fan rotor and a split wind turbine so they can spin.
>
> Then priority B: 1×1 cottages and corner shops, 1×2 rows, 3×2 civic buildings and
> apartments. Then the per-town extras.
>
> Extend the manifest without changing existing entries, add `grid_footprint` [w, h] to every
> new sprite, record fans and steam, and add the contact sheets and a mixed-size context
> check. Art only: no game scripts.
