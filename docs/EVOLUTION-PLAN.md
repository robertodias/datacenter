# Evolution plan: phases 14–19

Drafted 9 November 2026 from player feedback. The goal: Hyperscale should feel like a real
town you reshape, with a finer grid, larger multi-tile buildings, area tools, visible
opposition and a marketing game. Today it feels like a board of 1×1 squares.

The four requests, and where they land:

| Request | Today | Phase |
| --- | --- | --- |
| Buildings occupy more grid cells | Every building is exactly one plot of a 16×16 grid | 14: Grid 2.0 |
| Select an area and act on it (clear houses, build many halls) | One plot per click | 15: Area tools and campus planner |
| People protest against datacenters | Hidden stress stages; static placard groups appear at stage 3 | 16: Living opposition |
| Invest in marketing, e.g. billboards with AI company names | Only research "AI open days" (adoption, not approval) | 17: Public image and marketing |

Phases 18 (bigger towns) and 19 (art integration) support them.

**Recommended order:** 15 → 17 → 16 → 14 → 18. Phase 19 runs in parallel with the art agent.
Area tools and marketing deliver value quickly on the current grid. The grid rebuild is the
riskiest change and should land once its design is settled and the matching art exists.

---

## Phase 14: Grid 2.0 (finer grid, multi-tile buildings)

**Problem.** One building per plot makes every house, school and datacenter the same size, so
the town reads as a checkerboard. In RollerCoaster Tycoon, Cities: Skylines or Car Park
Capital, footprints vary and that is a large part of what makes a place look real.

**Proposal: subdivide every plot into 2×2 tiles.**

- **Map:** Littlebrook becomes 32×32 tiles covering the same physical town. Each existing plot
  maps exactly onto a 2×2 block, so saves migrate deterministically.
- **Roads and river:**
  - Roads become 2 tiles wide (two lanes, with crosswalks at junctions).
  - The river becomes 2–4 tiles wide, with real banks.
- **Footprints:**

  | Building | Footprint (tiles) |
  | --- | --- |
  | Cottage / detached home | 1×1 |
  | Townhouse row | 1×2 |
  | Apartment block | 2×2 |
  | Shop | 1×1 or 1×2 |
  | Park, plaza | 2×2 |
  | School, town hall, clinic | 2×3 |
  | Landmark | 1×1 to 2×2 |
  | Server hall S / M / L | 2×2 / 3×2 / 3×3 |
  | Substation pad / yard | 2×1 / 3×2 |
  | Cooling block | 1×2 to 3×2 |

- **Capacity:** scales with footprint × tier. Bigger halls get a small efficiency bonus, but
  they need more land, make more noise and add more trips. Tier upgrades in place remain.
  "Expand" becomes a second growth path: rebuild as a larger footprint on adjacent owned tiles.
- **Land:** ownership and price are per tile, so you can buy exactly the land you need. A
  district's price per tile is about a quarter of today's plot price.
- **Adjacency:**
  - Halls that touch a utility skip road-access works.
  - Halls joined in a block share fire/security overhead (a small upkeep discount).
  - Joined halls also concentrate noise, which is a real trade-off.

**Systems touched (all of them).**
- `simulation.gd`: lots array, cell indexing, building records with an `origin` tile and a
  footprint.
- `town_rules.gd`: reach and noise distances in tiles.
- `civic.gd`: per-building noise source at the footprint centre; household counts per building.
- Pathfinding, minimap, overlays and bookmarks.
- Tutorial coordinates (warehouse 04-06 → tiles 06-10…07-11).
- The UI inspector, which shows the whole building.
- Every test fixture that uses plot indices (83/82/99…).

**Rendering.** Sprites become footprint-sized: a 2×2 hall uses a 512×384 canvas anchored at
its top corner. Depth sorting uses the footprint's front corner. Existing 256 sprites still
work for 1×1 tiles.

**Save migration.** Schema 12 → 13. Each old plot becomes a 2×2 block, and each building
becomes a 2×2 building of the same kind, tier and hardware. Houses keep their household count.
Results must be identical for 100 simulated hours before and after (the continuation test
pattern already exists).

**Staging, to reduce risk:**
1. **14a:** multi-plot footprints on the current 16×16 grid. This is the engine work: building
   records, footprints, depth, inspector, area occupancy.
2. **14b:** the 2× subdivision, migration and new tile art.

**Size:** large, the biggest phase. **Art dependency:** footprint-sized buildings (update to
the art brief).

---

## Phase 15: Area tools and campus planner

**Drag to select.** With Buy, Bulldoze or a build tool active, drag a rectangle on the map.
Shift-drag adds to the selection and Ctrl-drag removes from it. A summary card appears before
anything happens:

- **Buy area:** number of plots, total price, plots skipped (roads, river, protected sites)
  and why.
- **Bulldoze area:** demolition total, homes cleared, **families displaced**, parks and
  landmarks affected, approval cost per district, and protected sites skipped.
  - One confirmation covers the whole selection.
  - Large clearances warn that they will probably trigger a petition.
- **Build area / campus planner:**
  - The game packs the selected land with the chosen building and proposes the substations and
    cooling plants it needs.
  - The plan shows as **ghosts** with a bill: land, clearing, construction, access works.
  - It also shows projected compute, power and cooling balance, noise and civic impact.
  - Then **Build all**, or adjust the ghosts one by one.
- **Bulk actions on owned buildings:** upgrade all selected, service all, refit hardware,
  add acoustic barriers.

**Construction becomes real time.** With bulk building, instant construction feels wrong.
- Each building takes game hours to build: about 1h per tile, so a 2×2 hall takes 4h.
- Work is limited by **construction crews**, a new workforce role. Queued sites wait their
  turn; trucks and the crane animation reflect the actual queue.
- A site under construction draws no power and earns nothing. Deadlines keep running, so
  planning ahead matters.

**UI.** Selection rectangle and footprint outline on the ground; per-tile coloured badges for
blocked tiles; the summary card replaces the inspector while a selection is active; Esc
cancels.

**Size:** medium. It works on today's grid and is reused unchanged after Grid 2.0.

---

## Phase 16: Living opposition (protests you can see)

What exists: per-district concerns, stress stages (warning → petition → demonstration →
permit pause), negotiation, remedies, and static placard groups at stage 3+.

**New:**

- **Protest events in the world:**
  - Crowds gather at the town hall or outside the offending campus, march along roads, and
    carry placards whose slogans match the actual cause.
  - Example slogans: "Turn down the hum", "Homes, not server racks", "Who drank our river?".
  - Crowd size follows district stress; chanting is mixed into the ambience.
- **Real consequences:**
  - Sit-ins at a site gate slow construction and deliveries.
  - Marches cause traffic jams, which raise local trip pressure.
  - Media coverage spreads stress to neighbouring districts.
- **Town vote on a moratorium:**
  - Triggered when two or more districts sit at demonstration for 48h.
  - A 72h campaign follows. Turnout and result depend on approval, adoption, jobs and promises.
  - Losing freezes new hall permits town-wide for a period (not game over).
- **News ticker:** local headlines, good and bad, each linked to its cause ("Clinic stays open
  through blackout thanks to campus batteries").
- **People, not just numbers:**
  - Named residents (the walkers already have names) post complaints tied to a building.
  - Displaced families visibly move out in a van.
  - Supporters rally too: workers and AI enthusiasts appear when you hire locally and serve
    the town well.
- **New responses:**
  - **Meet the organisers:** a dialogue with 2–3 choices, each with a stated cost and a
    measurable promise.
  - **Community benefits agreement:** a recurring payment to a district fund that raises comfort.
  - **Night curfew:** cap hall output at night for less noise and less revenue.
  - **Public tour:** costs an hour of operations and builds trust.

**Rule kept from today:** every protest is tied to a measurable cause, shown in the Council
panel. Nothing is random punishment.

**Size:** medium. **Art:** crowd and placard sprites, a moving van, a news icon set.

---

## Phase 17: Public image and marketing

**New stat: public image (0–100).** It is town-wide sentiment toward your company:
- **Raised by:** marketing, kept promises and reliable service.
- **Lowered by:** displacement, outages, broken promises and misleading ads.
- **Effects:**
  - Image moves every district's approval target up or down by as much as ±10 points.
  - It raises or lowers protest turnout.
  - It also affects the moratorium vote.
  - It never removes the cause of a concern.

**Billboards.** Placeable roadside structures: a 1×1 tile you own next to a road, or one of the
town's rentable billboard spots.

| Campaign | Effect | Cost |
| --- | --- | --- |
| **Company PR** ("Powering Littlebrook's clinic") | +image and +approval within about 6 tiles | Weekly fee; diminishing returns per district |
| **Customer co-branding** (GPN, Synthopic, Noodle and the other fictional clients) | The sponsor **pays you** weekly; +AI adoption (more spot demand); small −approval in sensitive districts (ad clutter) | Requires an active or past contract with that company; one sponsor per board |
| **Recruitment** | Lower staff wages for new hires; supporters appear at rallies | Weekly fee |

- **Honesty matters.** A claim like "Always on" during an outage, or green messaging while
  water strain is high, triggers a **greenwashing backlash**: −image, and protesters target
  the board.
- **Vandalism.** Boards can be vandalised during demonstrations: repair or remove.

**Other channels** (Company → Marketing panel, with campaign cards showing cost, duration,
target district and expected effect, and a results log):
- local newspaper and radio;
- sponsoring a school STEM lab (+adoption and +approval in that district);
- a local sports team (town-wide image);
- a job fair (hire locals: +approval, supporters);
- AI open days, moved here from research.

**Balance rules:**
- Marketing can offset up to a capped share of pressure. It decays without upkeep.
- The more you spend while root causes stay high, the faster image drops ("all talk").
- Fictional company names only; no real brands.

**Size:** medium. **Art:** billboard structures in 2 sizes, about 12 ad designs (one per
fictional client plus your company), and newspaper, radio and STEM-lab icons.

---

## Phase 18: Bigger towns and expansion

- **Regional land rights**, in the spirit of buying land outside a park's boundary: the veiled
  countryside around the town becomes purchasable in blocks once campaign milestones are met.
  It brings new districts with their own sensitivity: farmland, an industrial estate, a
  lakeside.
- **Living population:** housing demand grows with jobs and adoption. Empty land near the
  centre slowly fills with new homes, which compete with your campus for land.
- **Larger maps** for Sunsprawl and Oldbridge (40×40 tiles after Grid 2.0), with performance
  budgets tested on the release soak.

**Size:** medium–large. It depends on Grid 2.0.

---

## Phase 19: Art integration (in parallel with the art agent)

> **Status (9 Nov 2026): first delivery integrated.**
> - `dev/pack_town_art.gd` packs the 263 sprites into `assets/town_art_*.png` and
>   `assets/town_art.json`. The map draws them with mipmaps.
> - Covered: per-plot variants, sprite traffic, river banks and bridges, construction
>   stages, rubble, fans that spin from the manifest anchors, and generator and battery
>   modules.
> - Tests: `tests/test_town_art.gd`.
> - The multi-size follow-up is `docs/ART-BRIEF-MULTISIZE.md`.

- Pack the sprites from `assets/art/` into the atlas from the manifest.
- Pick deterministic per-plot variants.
- Replace code-drawn cars with sprites.
- Use the river tile set.
- Spin fans at the manifest anchors.
- Show distinct hardware types, plus on/off states.
- **Coordination note:** the current art brief (`docs/ART-BRIEF-MAP.md`) is written for 1×1
  plots.
  - Valid now and unaffected by Grid 2.0: vehicles, water, ground, props, construction stages.
  - **Hold** campus and town *buildings* until the Grid 2.0 footprints are decided. Otherwise
    they will be redrawn at new sizes.
  - Next revision of the brief: multi-tile canvases, billboards and ads, crowd and placard
    sprites.

---

## Cross-cutting work in every phase

- **Saves:** each phase bumps the schema with a tested migration and exact continuation.
- **Tests:** each phase gets new suites. The balance suite runs a full campaign using the new
  tools (area build, marketing).
- **Tutorial:** add guide steps for drag selection, the planner and marketing.
- **Accessibility:**
  - Area summaries are readable text, not colour only.
  - Protest audio respects the ambience volume.
  - Crowd motion respects reduced motion.
- **Performance:** a 32×32 grid has 4× the tiles. Static ground stays on the retained canvas,
  and depth sorting is limited to visible tiles.

## Decisions needed from you

1. **Grid approach:**
   - **(A, recommended)** subdivide every plot 2×2 (finer, denser, more organic town).
   - **(B)** keep the 16×16 plot grid and only add multi-plot buildings (cheaper, less change).
2. **Construction time:** build in game hours with construction crews (recommended with area
   tools), or keep it instant with the visual animation only?
3. **Moratorium vote:** include a town-wide vote that can freeze expansion for a while (not
   game over)?
4. **Sponsor billboards:** use the nine fictional client companies as sponsors that pay you.
5. **Where to start:** Phase 15 (area tools) is the quickest visible win on the current grid.
