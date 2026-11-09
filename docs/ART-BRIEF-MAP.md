# Art brief: town map sprites for Hyperscale: Datacenter Tycoon

You are producing **original isometric sprites** for the town map of *Hyperscale: Datacenter
Tycoon*, a Windows town-and-infrastructure management game (Godot 4.5). Your job is to
**deliver image files and a manifest only**. Do not edit any `.gd` script, scene or project
file: the game code is integrated separately.

Read this whole brief before generating anything. Consistency across the set matters more
than any single beautiful image.

---

## 1. What exists today (so you know what you are replacing)

- `assets/town_atlas.png` + `assets/town_atlas.json`: 50 sprites, each a **256 × 256 cell**,
  drawn in a clean flat-vector isometric style. Look at it first.
- Brand assets in `assets/branding/` (icon, logo, title illustration). The **palette** comes from
  there: deep teal, warm ivory architectural panels, luminous mint/cyan details, restrained
  amber-gold lights. The map art should feel like the same world as the title illustration,
  but stay crisp and readable at small size (it is **not** painterly).
- Weak spots to fix:
  - Server halls barely differ between hardware types.
  - Online and offline states look almost the same.
  - The river is a flat blue polygon.
  - Cars and people are tiny code-drawn boxes.
  - There are only 3 grass tiles and 4 trees.
  - The countryside around the town is empty.

---

## 2. Hard technical specification (every sprite)

| Rule | Value |
| --- | --- |
| File | PNG, RGBA, **transparent background**, clean edges (no white or black fringe) |
| Canvas | **256 × 256 px** for anything that stands on a plot. Vehicles: 128 × 128 (see §5) |
| Working size | Work at **1024 × 1024** on `assets/art/_templates/plot-template-1024.png`, then downscale ×0.25 with Lanczos. Check against `plot-template-256.png` |
| Projection | Parallel **2:1 isometric** (dimetric). Edges run at exactly ±26.565° (2 px across, 1 px up). No perspective, no vanishing points, no fisheye |
| Plot footprint in the 256 cell | Diamond with corners **top (128,136), right (212,178), bottom (128,220), left (44,178)**: the mint diamond in the template. The building's ground contact must fill this diamond (inset 4–10 px for a plinth or sidewalk edge). Nothing may extend past the diamond's left/right corners |
| Height | Roofline, antennas, chimneys and steam must stay **below y = 6** (coral line). Gold guides at 40 / 80 / 120 px above the top corner help keep tiers consistent |
| Scale | A resident is ~24 px tall in this cell. One storey ≈ 30–34 px. A door ≈ 22 px tall. A car is about one third of a plot edge |
| Light | Single sun from the **upper left**. Roof/top faces brightest. Left-facing (south-west) walls mid-tone. Right-facing (south-east) walls darkest. Keep this identical on every sprite |
| Shadow | Soft contact shadow only, falling to the **lower right**, kept inside the cell and no darker than 30% black. No long cast shadows (the map composites many sprites) |
| Text | **No letters, numbers, logos or signage text.** Use pictograms on shop signs (bread, cup, book, cross). No real brands |
| Readability | Must read at 0.65× zoom (~110 px wide on screen). Avoid details thinner than 2 px at 256 size; group small details into clear shapes |
| Originality | Original designs only. Do not imitate or trace art from any existing game (RollerCoaster Tycoon, SimCity, Car Park Capital or others) |

**Animated parts are added by code.** For anything with fans, paint the fan housings with
**static blades**. Then record each fan's centre and radius in the manifest (§7) so the game
can overlay spinning blades. Do the same for chimneys and cooling towers: record steam anchor
points rather than painting large steam clouds.

---

## 3. Priority A: campus buildings (biggest gameplay impact)

The player builds three kinds of campus building, each with three upgrade **tiers**. Server
halls also come in four **hardware types**. Each sprite needs an **`_on`** state (operating:
mint/cyan LED strips, lit glass, warm amber door lights) and an **`_off`** state (dark glass,
no glow, same geometry). Tiers must read as an obvious progression from far away:

- **T1:** a single low hall on its plot, about 1 storey.
- **T2:** larger, with an added wing or second block, about 2 storeys.
- **T3:** a landmark tower, about 4 storeys, up to the top guide.

### 3.1 Server halls: 22 sprites (`assets/art/halls/`)

| Hardware | Visual identity (keep the base silhouette per tier, vary materials and roof gear) | Tiers |
| --- | --- | --- |
| `balanced` | House style. Ivory panels, teal trim, mint vent bars, neat rooftop fan grid | t1, t2, t3 |
| `refurbished` | Converted old brick warehouse shell, patched metal panels, mismatched second-hand units, exposed ducts, amber/rust accents, slightly untidy roof | t1, t2, t3 |
| `efficient` | Sleek, low and light. White and pale glass, green or solar roof, fewer but larger fans, closed-loop pipes, calm teal accents | t1, t2, t3 |
| `training` | Dense, heavy and powerful. Graphite and dark steel, many fans, thick power conduits, warm orange heat glow in `_on` | t2, t3 only (unlocks at tier 2) |

Keys: `hall_<hardware>_t<tier>_<on|off>`, for example `hall_refurbished_t2_on`.

### 3.2 Substations: 6 sprites + 2 extras (`assets/art/utilities/`)

- `power_t1/t2/t3_<on|off>`:
  - **T1:** pad transformer inside a fence.
  - **T2:** two transformers and a small gantry.
  - **T3:** a high-voltage yard with tall gantries and an insulator tower.
- `_on` shows a few amber indicator lights and a faint mint glow on the bushings.
- Extras: `power_battery_module`, a small container-style battery block (the game places up to
  12 next to a substation), and `power_generator_module`, a diesel generator set with an
  exhaust stack (record a steam anchor point).

### 3.3 Cooling plants: 6 sprites + 2 extras (`assets/art/utilities/`)

- `cooling_t1/t2/t3_<on|off>`:
  - **T1:** two dry coolers on a plinth.
  - **T2:** a four-fan block with pipes.
  - **T3:** a closed-loop plant with tanks and big fans.
- Extras:
  - `cooling_riverfront_t1_on`: the same plant with an intake pipe toward the left/water side.
  - `cooling_mobile_chiller`: a rented trailer unit on wheels.

### 3.4 Construction and demolition (`assets/art/construction/`)

These feed the existing 3-second build animation and 2.5-second demolition animation.

| Key | Content |
| --- | --- |
| `site_foundation` | Cleared dirt pad with a concrete slab, stakes and a small site fence |
| `site_frame_low` | Steel frame about 1 storey high on the slab, with stacked materials |
| `site_frame_high` | Frame about 3 storeys high with scaffold and safety netting |
| `site_crane` | Tower crane on its own transparent canvas, mast on the right/back corner, jib pointing left. Record the hook point in the manifest |
| `rubble_0`, `rubble_1` | Demolition rubble piles (brick, beams, dust-coloured debris) |

---

## 4. Priority A: river, water and ground

Water and ground tiles are **flat** (no height). They fill the footprint diamond **exactly**,
edge to edge, so neighbouring tiles join seamlessly. Test by placing a tile next to itself on
all four sides.

### 4.1 River set (`assets/art/water/`)

- `water_0`, `water_1`, `water_2`: open water.
  - Deep teal-blue with subtle lighter ripples.
  - No strong directional flow lines, because code animates the flow.
- Bank pieces: a grass verge with a stone or reed edge, where land meets water on that side.
  - `water_bank_ne`, `_nw`, `_se`, `_sw`.
  - Outer corners `water_corner_n`, `_e`, `_s`, `_w`.
  - Inner corners `water_inner_n`, `_e`, `_s`, `_w`.
  - Direction names refer to the diamond's sides and corners **on screen**: top-right edge = ne,
    top-left = nw, bottom-right = se, bottom-left = sw.
- `bridge_road_x`, `bridge_road_y`: road deck crossing water, with parapets, in both directions.
  The x direction runs from upper-left to lower-right on screen.
- `bridge_foot_x`, `bridge_foot_y`: narrow pedestrian bridge.
- Riverside props, each on its own 256 canvas, positioned at the plot centre:
  - `prop_dock`, `prop_rowboat`, `prop_barge`, `prop_reeds`, `prop_ducks` (a tiny group).

### 4.2 Ground (`assets/art/ground/`)

- `grass_0` … `grass_5`: subtle variation (tufts, clover, worn patches). Never busy.
- `meadow_0`, `meadow_1`: grass with tiny wildflowers.
- `lot_owned`, `lot_unowned`: buildable plot. Owned shows a crisp mint-edged border inset; unowned
  shows a faint ivory survey border.
- `dirt_0`: cleared construction ground.
- `plaza_cobble_0`, `plaza_cobble_1`: Oldbridge squares.
- `dry_grass_0` … `dry_grass_3`, `sand_0`: Sunsprawl.
- `farm_rows_0` … `farm_rows_2`, `orchard_0`, `field_fallow_0`: countryside outside the town.
- Roads, matching the current layout:
  - `road_x_0`, `road_x_1`, `road_y_0`, `road_y_1` (two wear variants each direction).
  - `junction_0`.
  - `crossing_x`, `crossing_y` (zebra crosswalk).
  - `road_bus_stop_x` (a lay-by).

---

## 5. Priority A: vehicles (`assets/art/vehicles/`)

- **Canvas** 128 × 128. The vehicle's **ground contact centre sits at (64, 84)**.
- Body length along the travel axis is about 34 px for a car and about 50 px for a bus.
- Each vehicle needs **4 directions**, named by screen direction of travel:
  - `se`: down-right, moving +x along the road.
  - `nw`: up-left.
  - `sw`: down-left, moving +y.
  - `ne`: up-right.
- Keep the upper-left light on every direction (do **not** mirror without relighting).

| Type key | Description |
| --- | --- |
| `car_hatch` | Small hatchback, 4 colour variants (`_a`…`_d`: brick red, ivory, teal, mustard) |
| `car_sedan` | Sedan, 2 colour variants |
| `car_suv` | Small SUV, 2 colour variants |
| `van_delivery` | White delivery van, neutral (no logo) |
| `van_maintenance` | Campus maintenance van: teal with mint stripe and roof light bar (used for repair dispatches) |
| `truck_box` | Box truck for equipment deliveries |
| `bus_city` | Single-deck town bus |
| `bike` | Cyclist on a bike, 2 variants |

Key format: `<type>[_<variant>]_<dir>`, for example `car_hatch_b_sw`. That makes
4 × (4 + 2 + 2 + 1 + 1 + 1 + 1 + 2) = **72 sprites**. If time is short, deliver `se` and `ne`
first; the other two can follow.

---

## 6. Priority B and C: a richer town

### 6.1 Town buildings, B (`assets/art/buildings/common/`)

All are 1-plot footprints and must include their own small front garden or sidewalk inside the
diamond.

| Group | Keys |
| --- | --- |
| Homes | `home_detached_0…5`, `home_terrace_0…3`, `home_apartment_0…2` (2–3 storeys) |
| Shops with flat above (pictogram signs) | `shop_bakery`, `shop_cafe`, `shop_books`, `shop_grocer`, `shop_pharmacy`, `shop_hardware` |
| Civic | `civic_town_hall`, `civic_school`, `civic_library`, `civic_clinic`, `civic_fire_station`, `civic_post_office`, `civic_chapel` |
| Industrial | `ind_warehouse_0…2` (shown with a for-sale board as a pictogram), `ind_workshop`, `ind_depot`, `ind_factory_small`, `ind_brewery` |
| Parks (protected green space) | `park_playground`, `park_garden`, `park_pond`, `park_sports_court` |
| Landmarks (protected monuments) | `landmark_statue`, `landmark_clock_tower`, `landmark_fountain`, `landmark_bandstand`, `landmark_obelisk`, `landmark_old_mill` |

### 6.2 Per-town sets, C

- `assets/art/buildings/sunsprawl/`: a dry suburb.
  - Stucco and adobe homes with flat or terracotta roofs: `home_stucco_0…3`.
  - `shop_diner`, `civic_water_tower`, `prop_solar_carport`.
  - Palms and cacti props: `prop_palm_0/1`, `prop_cactus_0/1`.
- `assets/art/buildings/oldbridge/`: a dense historic town.
  - Narrow 3-storey brick terraces with slate roofs: `home_townhouse_0…3`.
  - `civic_guildhall`, `landmark_cathedral` (tallest allowed, up to the coral line).
  - `bridge_stone_arch_x`, `bridge_stone_arch_y`.

### 6.3 Props and life, B (`assets/art/props/`, 256 canvas, item placed at the plot centre)

- **Trees:**
  - Deciduous `tree_round_0…5` (vary size and greens).
  - Conifers `tree_pine_0…2`.
  - `bush_0…2`, `hedge_x`, `hedge_y`, `flowerbed_0/1`.
- **Street:**
  - `bench`, `picnic_table`, `bus_shelter`, `bike_rack`, `bin`.
  - `street_lamp_classic`, `street_lamp_modern`.
  - `traffic_light`, `mailbox`, `hydrant`.
- **Campus:**
  - `ev_charger`, `pallet_stack`, `cable_drum`, `transformer_box`.
  - `solar_array`, `security_gate`, `fence_mesh_x`, `fence_mesh_y`.
- **Countryside:**
  - `farm_barn`, `farm_silo`, `haybales`, `wind_turbine` (tall; record the hub anchor so blades
    can spin).
  - `cell_tower`, `rock_0/1`, `forest_clump_0…2` (3–5 trees in one sprite, for outside the town).

---

## 7. Manifest and previews (required)

Deliver `assets/art/manifest.json`, an array with one entry per sprite:

```json
[
  {
    "key": "hall_efficient_t2_on",
    "file": "halls/hall_efficient_t2_on.png",
    "category": "hall",
    "canvas": [256, 256],
    "anchor": [128, 136],
    "footprint": "plot",
    "fans": [[96, 70, 8], [124, 84, 8]],
    "steam": [],
    "notes": "two-storey GPU wing on the right"
  }
]
```

- `anchor` is the plot's top corner (always [128,136] on 256 canvases) or the vehicle ground
  contact point ([64,84] on 128 canvases).
- `fans` is a list of `[x, y, radius]` in canvas pixels for each spinning fan. `steam` and `hook`
  (crane) and `hub` (wind turbine) are `[x, y]` points.
- Also export one **contact sheet per folder** (`assets/art/_preview/<folder>.png`). It shows
  every sprite on a mid-grey background, labelled underneath, at 100% size.
- Add a short `assets/art/README.md`. List what was generated, the prompts or method used, and
  anything you could not deliver.

---

## 8. Recommended process (for image generation)

1. **Lock the style first.**
   - Generate a single master: `hall_balanced_t2_on`.
   - Fit it onto the 1024 template so the slab corners land on the mint diamond.
   - Downscale it and compare it next to the current atlas and the title illustration.
   - Only then continue.
2. **Derive, don't reinvent.**
   - Build each hall tier from the master silhouette, and each hardware type by changing
     materials and roof gear.
   - Build each `_off` state from its `_on` image by removing the glow, so the geometry stays
     identical.
3. **Post-process every image:**
   - Remove the background to true alpha.
   - Align the footprint to the template within **±2 px** at 256.
   - Normalise brightness so the left wall and right wall values match the master.
4. **Check in context.**
   - Place new sprites on the template grid next to neighbours: a house, a road tile, a tree.
   - Check that scale and light agree.

### Acceptance checklist

- [ ] Every file is 256 × 256 (vehicles 128 × 128), transparent, with no fringe.
- [ ] Footprints sit on the template diamond (±2 px); nothing crosses the left or right corners
  or rises above y = 6.
- [ ] Light comes from the upper left on every sprite, including all four vehicle directions.
- [ ] T1, T2 and T3 are distinguishable at 0.65× zoom; the four hardware types are
  distinguishable at 1× zoom.
- [ ] Each `_on`/`_off` pair has identical geometry.
- [ ] Water and ground tiles tile seamlessly with themselves and with each other.
- [ ] No text, logos or real brands.
- [ ] `manifest.json`, contact sheets and `README.md` are delivered; every key in this brief is
  present or listed as missing.

---

## 9. Out of scope

- Do not edit `assets/town_atlas.png/json`, scripts, scenes or project settings.
- No UI icons, fonts, title art or store assets (already done).
- No animation frames. Motion is code-driven from the anchors you record.
