# Hyperscale: Datacenter Tycoon: delivery through phase 6

Scope is the six phases agreed in this chat. A phase is complete only after its
features and the stated user journey have been verified in the current build.

## 1. The Front Door
- [x] Animated title screen, Continue with latest-save preview, New Company, Load, Settings, Credits, Quit.
- [x] New game: scenario brief, difficulty, company name, loading, paused arrival.
- [x] Persisted display/resolution/text scale, sound, controls, incident auto-pause preference (incident behavior verified in phase 5).
- [x] Keyboard-focusable controls, visible focus, distinct destructive flows and disabled save/action explanations; enlarged-text and minimum-display audit verified in the release.
- [x] Launch/start/save/return exercised in native Windows and test_frontdoor.gd; the final exported journey passes 41 checks.

## 2. Safe Harbor
- [x] Named manual saves, quicksave, three rotating autosaves, scenario-specific campaign saves.
- [x] Thumbnails, names, town/day/playtime/progression summaries and timestamps.
- [x] Overwrite/delete/unsaved-state prompts, recovery from damaged saves.
- [x] Persist full economy/contracts/equipment/unlocks, citizen and incident timers, random state, camera. Save schema 7 and exact continuation verified.
- [x] Atomic writes, version 1/2 migration and previous-good-file backups. Exact civic and incident continuation is verified in the final phase 6 release.

## 3. Littlebrook, a Real Place
- [x] Larger authored town: 256 parcels across Foundry Quarter, Old Littlebrook, Market District, Riverside Works and Civic Gardens; river/bridges and protected landmarks.
- [x] District prices, charged road-access works, river cooling bonus, neighborhood-scaled demolition approval and heritage hearings affect choices.
- [x] Clickable minimap/camera footprint, three saved bookmarks, equipment list, electricity/cooling/noise/ownership/opinion layers.
- [x] Click disconnected-campus alerts to focus causes; footprint ghosts, utility links and itemized land/clear/build/access/hearing costs before construction.
- [x] Verified remote halls stay offline until utility reach upgrades, riverfront cooling gains 25%, and redevelopment in sensitive districts costs more approval.

## 4. The Compute Economy
- [x] Inference, training, critical services and cyclical experimental workloads have distinct throughput, delivery targets and failure fees.
- [x] Player-set contract priorities change scarce-capacity allocations; review shows contribution vs spot, cash flow, delivery/slack, resource draw and penalties before signing.
- [x] Balanced/refurbished/efficient/training hardware changes cost, capacity, utilities, noise and workload throughput. Refits cause two actual hours of downtime; tier upgrades retain the hardware choice.
- [x] Categorized cash ledger, daily/history totals and cent-precise operating breakdown separate recurring/project/bonus income, upkeep, energy, staff, loans, principal, interest and construction.
- [x] Four entire campaign strategies pass without injected cash; financed training repays its loan. Windows preview checked 115% text, comparison, confirmation, refit and unsaved close.

## 5. Keep the Lights On
- [x] 12h heat/grid forecasts, unannounced grid faults, condition loss/derating, stochastic breakdowns, planned service and repair timers.
- [x] Forecast → active → two-hour recovery → result lifecycle; auto-pause preference is applied before the next affected hour, with persistent actionable alerts.
- [x] Operations tab and town button show headroom, charge, fuel, hub connection, battery/generator modules, warm standby, mobile cooling, preventive crews and equipment service.
- [x] Heat tint/shimmer, blackout tint, stopped failed machinery, condition/service markers and visible backup modules. Mobile cooling bridges local plant service; relocation restores a disabled backup hub. Later heat/grid events overlap.
- [x] Prepared/unprepared strict-service outcome comparison, complete paid campaign strategies, and exact combined-incident/random-state continuation verified in source and exported Windows build.

## 6. The Town Pushes Back
- [x] Approval and AI adoption are separate; neighborhood concerns derive from real conditions.
- [x] Displacement, noise/traffic, electricity/water pressure, employment/investment, failures and preservation matter.
- [x] Warning/petition/demonstration/permit escalation with specific demands.
- [x] Negotiation/redesign/investment/relocation/preservation/aggressive-expansion responses.
- [x] Visible protest and citizens' thoughts; verify causes, restrictions and recovery.

## Research and design references
Reviewed 8 November 2026; these are references, not claims that our game already
meets their standards.

- [OpenRCT2 main interface](https://docs.openrct2.io/en/latest/playing/main_interface/):
  a stable management toolbar, visible simulation controls and inspectable world.
- [OpenRCT2 options](https://docs.openrct2.io/en/latest/setup/options.html):
  explicit display modes and configurable experience.
- [OpenRCT2 changelog](https://openrct2.io/download/changelog): distinguish Load
  and Save so destructive actions cannot be mistaken for navigation.
- [Car Park Capital official listing](https://store.steampowered.com/app/3031880/Car_Park_Capital/):
  land transformation, citizen thoughts, demand creation and opposition belong in
  connected systems, not decorative meters.
- [Xbox Accessibility Guidelines](https://learn.microsoft.com/en-us/xbox/accessibility/guidelines):
  legible text, contrast, configurable input and predictable UI navigation.

Our usability targets: readable text and symbols (not color alone), visible
keyboard focus, reversible navigation, confirmed destructive changes, forecasts
with actionable responses, no hidden loss of work, and a useful save recovery path.

## Historical checkpoints (final evidence below)

- `test_frontdoor.gd`: 43 passing checks for company setup, save metadata/image,
  three-slot rotation, backup recovery, unsafe-path rejection, control persistence,
  camera/contract continuation and unsaved navigation.
- Existing simulation/progression: 31 + 63 checks pass after save-schema migration.
- Native Windows `fullscreen_probe.gd`: 30 checks pass with menus and native dropdowns.
- Windows preview exercised title → company setup → paused town → named save
  with thumbnail; settings screen visually inspected. Full scope remains active.
- Phase 3: `test_geography.gd` passes 46 checks, including genuine 100-parcel
  version 1/2/3 migrations, preserving occupied river parcels, permits, exact
  network round trips, saved map layers/bookmarks, and pedestrian bridge routes.
- Current suite: simulation 31, progression 63, front door 44, geography 46,
  interface/activity 95, economy 142, operations 39 and native fullscreen 32:
  492 passed, 0 failed. Earlier phase counts below are historical checkpoints.
- Native Windows atlas review: equipment list → disconnected campus, layer
  dropdown → electricity coverage; corrected map/clock overlap. F11 forwarding
  now also covers native map/settings dropdowns.
- Retained terrain canvas restored larger-map render performance: 74 FPS in
  the 1920×1080 graphical smoke test on the development RTX 4060. This is a local
  measurement, not a minimum-spec guarantee. Final phase 6 integration is open.
- `build/Datacenter Mogul Next.exe` exported successfully at v1.1.0-dev.
  `packaged_journey.gd` ran against that actual Windows executable: 21 checks,
  0 failures, covering title → new company → functioning campus → customer →
  named save with thumbnail → title → reload after clearing the live company →
  restored contract/camera/layer → atlas rendered at 115% text size. Output:
  `build/packaged-journey.log` and `build/packaged-atlas.png`.
- The phase 3 exported pack also passes the 46-check geography suite. Its
  evidence is retained here; later integration still requires re-verification.

### Phase 4 evidence
- `test_economy.gd`: 141 passing checks for differentiated hardware/workloads,
  priority under shortages, strict critical-service failure, loan limits and
  repayment, income vs financing, complete ledger reconciliation, daily reports,
  exact mid-refit/loan/priority continuation, version 4 contract grandfathering,
  corrupt-finance rejection, contract review and hardware navigation.
- Full campaigns (no injected cash): minimum cash balanced $9,940.20;
  refurbished $8,051.12; efficient $8,550.00; financed training $15,840.80.
  All eight customers delivered on every route; ending debt is zero in all four.
- Actual exported Windows EXE passes the same 141 economy checks and an expanded
  26-check `packaged_journey.gd`: title/new town, construction, contract, named
  save/thumbnail, reload, loan/refit save, exact restoration, completion and
  enlarged-text hardware/map renders. Logs: `build/packaged-economy.log` and
  `build/packaged-journey.log`; image: `build/packaged-economy.png`.
- Native Windows 115% preview exercised Finance → Jump to hardware → training
  comparison → refit confirmation. Corrected clipped navigation, cent rounding,
  and scroll position after applying a refit. Native close → Save & continue
  verified in the export; saved cash $24,624.51 exactly matches its ledger,
  preserving $5,000 debt and efficient hardware in the isolated QA directory.
- [OpenRCT2 finances](https://docs.openrct2.io/en/latest/playing/finances/)
  informed the separated income/expense categories, loan visibility and direct
  cash-button access. These references guide usability; they are not a claim
  that our game is better in every respect.
- At this phase 4 checkpoint, phases 5–6 and the final integration audit were
  still open. See the completed release audit below; this paragraph records history.

### Phase 5 evidence
- `test_operations.gd`: 39 passing checks for actual grid/thermal impacts,
  battery-to-generator transfer, stored-energy/fuel accounting, warmup timing,
  recharge/recovery/results, rental expiry projections, mobile cooling during
  plant maintenance, wear/derating/random failure, service/repair, preventive
  crews, hub relocation, strict-service outcomes, corruption rejection and both
  auto-pause preferences.
- A combined outage/heatwave save with fuel, charge, service and poor-condition
  equipment resumes exactly for 160 subsequent hours: lots, future random state,
  incident schedule/results, finances and cash match the uninterrupted town.
- All four campaign routes now pay for resilience using the same game actions
  as the player; no cash injection or incident suppression. Minimum balances:
  balanced $4,337.20; refurbished $1,442.40; efficient $3,569.36; training
  $7,333.20. All eight customers delivered; all ending loans repaid.
- Actual exported Windows EXE passes 39 operations and 142 economy checks;
  `packaged_journey.gd` passes 31 checks including combined live incident saves,
  exact restoration and generator takeover. Logs: `build/packaged-operations.log`,
  `build/packaged-economy.log`, `build/packaged-journey.log`. Rendered evidence:
  `build/packaged-operations.png` at 115% text size.
- Native exported build: Operations → equipment → cooling service confirmation
  ($500 / 2h) → 220 compute maintained through mobile cooling → service completed
  above 99% condition → automatic pause at grid recovery. Checked costs, timer,
  retained scroll position and disabled duplicate servicing. Urgent faults sort
  above future forecasts; small toolbar captions remain legible at 115%.
- Closed the instant-warm-standby shortcut: starting standby at impact still
  needs one hour. Batteries remain useful for unexpected startup gaps.
- [OpenRCT2 staff](https://docs.openrct2.io/en/latest/playing/staff/) informed the
  distinction between checking equipment, fixing failures and ongoing crew costs.
- Save schema 6 adds operations, gameplay random state and condition/service
  fields. Earlier towns receive healthy equipment and a fresh commissioning
  grace period. Civic state and final integrated phase 6 verification remain open.


## Phase 6 and final release evidence — 8 November 2026

The delivered title is **Hyperscale: Datacenter Tycoon**, version **1.1.0**.
The launcher selects `build/Hyperscale Datacenter Tycoon.exe`; the portable package
is `build/Hyperscale-Datacenter-Tycoon-Windows.zip`. Historical Mogul executables
remain available as checkpoints and are not the current launcher target.

- `test_civic.gd`: **61 checks**, including independent adoption/support,
  useful deliveries and skills driving demand, actual displacement and rehousing,
  jobs, residential versus industrial noise, acoustic barriers, physical relocation,
  parks, landmark restoration, permanent conservation, traffic/grid/water remedies,
  service failures versus successful backup, every escalation stage, permit blocking,
  waiver expiry, negotiations kept/broken, live availability previews and both pause
  preferences. Visible protest groups and minimum-display council layout verified.
- Save schema 7 adds full civic history, local opinion/adoption/stress, unmet needs,
  grievances, projects, agreements and permit timers. Version 1–6 migration remains
  supported. Exact civic plus incident continuation for 80 hours, operations-only
  continuation for 160 hours, malformed-state rejection, public-project site flags
  and conservation/barrier persistence all pass in the standalone export.
- **Five entire paid campaign strategies** deliver all eight customers and finish
  debt-free. The fifth first triggers a real displacement permit pause, negotiates,
  pays to rehouse all three families and resolves the protest before completing
  the campaign. No injected cash or incident suppression is used in these routes.
  Lowest balances: balanced $4,337.20; refurbished $1,442.40; efficient $3,569.36;
  financed training $7,333.20; financed civic recovery $2,781.56.
- Actual exported executable: simulation **31**, progression **63**, front door
  **44**, geography **46**, interface/activity **95**, economy **168**, operations
  **39**, civic **61**, native Windows fullscreen **35**, packaged journey **41**.
  **623 checks passed, zero failures**, excluding duplicated source runs.
- The packaged journey covers title → company setup/loading → working campus →
  customer → named thumbnail save → title → reload → loan/refit → combined incidents
  → active council agreement save/reload → actual rehousing → protest recovery.
- Native Windows inspection confirmed the long new title, logo, new-company flow,
  full-display F11 entry and exit, council causes/cost review/charged negotiation,
  disabled-action reasons, and scrolling response controls. Native fullscreen tests
  cover help, confirmations, hardware/map/council native dropdowns, maximized-state
  restoration and repeated keys. The old user-running game was left untouched.
- 115% text rendered and inspected at 1440×900 and minimum 1152×720. The help page
  now scrolls; the council shows labeled separate bars, numerical causes, demand,
  thresholds, timers and costs. Contract/finance/operations/map renders also reviewed.
  Layout tests cover 16:10, 16:9, 5:4, ultrawide and 4K; these synthetic dimensions
  are distinct from the native 1920×1080 display test.
- Final exported 1920×1080 render smoke: **68 FPS**, **1,668 draw calls** on the local
  RTX 4060. This is one measured scene, not a minimum hardware guarantee.
- Logs: `build/release-test_*.gd.log`, `build/release-fullscreen.log`,
  `build/hyperscale-journey.log`, `build/release-render.log`. Artifacts include
  `build/packaged-council.png`, `build/civic-minimum.png`, `build/civic-protest.png`,
  `build/help-guide.png`, `build/graphics-preview.png` and packaged finance/ops/map.
- Full requirement audit: [RELEASE-1.1.md](RELEASE-1.1.md). Binary/package hashes and
  check summaries are recorded in `build/verification.json`.

### What the research changed

[OpenRCT2's main interface](https://docs.openrct2.io/en/latest/playing/main_interface/)
keeps world inspection, finances, construction, simulation speed and guest needs
close at hand. We adopted stable management entry points and inspectable causes.
Our civic review adds an explicit cost, measurable promise and recovery threshold
before a response, making those particular decisions easier to evaluate.

[Car Park Capital's official listing](https://store.steampowered.com/app/3031880/Car_Park_Capital/)
connects land transformation, demand and citizen opposition. Our interpretation uses
separate AI adoption and neighborhood approval, with actual buildings and resource
use behind complaints, rather than one generic happiness purchase.

[Xbox Accessibility Guideline 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
emphasizes readable, configurable text. Our concrete changes are persistent text
size, bounded/scrollable help, visible focus and textual status/cost explanations.
This is targeted usability work, not a claim of full accessibility certification
or that the prototype exceeds either reference game in every respect.


## Subsequent review
Version 1.1.1 fixes map/inspector feedback and readability issues. See [REVIEW-1.1.1.md](REVIEW-1.1.1.md) for fixed findings, 293 targeted checks, render evidence and remaining art priorities. The six-phase completion above describes the functional prototype scope, not commercial art certification.
