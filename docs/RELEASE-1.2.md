# Hyperscale 1.2.0 — release audit

Scope: phases 7–13, plus the requested nine fictional customer companies, delivered
as a standalone Windows demo and local Steam release materials. The owner confirmed
there is no Steamworks App ID and only the current PC is available. Steam integration,
publication and verification on another monitor/lower-spec computer are deferred,
not represented as completed work.

## Requirement evidence

| Phase | Implemented behavior | Verification |
| --- | --- | --- |
| 7 — Feed the AI | Six compute-funded projects, three branches, saved progress, capacity contention, commercial offers/outreach, event-aware journal | `test_research`: 50 checks, fully paid research route, exact save continuation; screenshot 04 |
| 8 — People Behind the Machines | Three specialist roles, wages, priority/affordability-aware dispatch, shorter engineering work, negotiated new terms, visible vans/workers and resident destinations | `test_workforce`: 33 checks; dispatch visuals reviewed; save/job continuation |
| 9 — Three Towns, Three Dilemmas | Distinct Littlebrook/Sunsprawl/Oldbridge geography, climate, charters, distinctions and save-aware transition | `test_scenarios`: 58 checks including paid finales and exact continuation; screenshots 05/06 |
| 10 — Your First Thirty Minutes | Nine skippable/resumable action-based steps, static highlights, four-second normal clock, updated in-game reference | `test_tutorial`: 17 checks; native minimum-size layout; human session duration is not inferred |
| 11 — A Town Worth Watching | 50 original sprites, six neighborhood families, distinct tier 2/3 silhouettes, construction/work/incident activity, adaptive score and ambience | `test_presentation`: 20 art/audio-state checks; 1080p game renders and recorded gameplay; UI/visual suites; reduced-motion behavior |
| 12 — The Tycoon Test | Paid preservation, redevelopment, efficient, refurbished/redundant and relaxed routes with research/staff/incidents/debt recovery | `test_balance`: 114 checks; all five complete, solvent and debt-free; `test_economy`: 168 broader economics checks |
| 13 — Ready for Players | Standalone executable/ZIP, save schema 12 and migration, local achievements, current-PC native verification, guide/credits/update instructions, store copy/media and future integration plan | Final suite report, extracted binary smoke, long-session and dense-render probes, media validation, archive CRC and embedded executable hash |
| Fictional companies | Nine profiles, eight campaign sponsors, research introductions and rotating repeat commissions, active-save narrative migration | `test_clients`: 51 checks; no real company names in gameplay source/assets; screenshot 07 |

The final suite report is `build/final12-tests.json`; the executable hash and test
coverage are recorded in `build/verification-1.2.0.json`. The release harness runs
19 suites (995 checks). Eight further checks exercise the extracted executable from
a folder containing only that executable, proving it does not depend on the source
tree, loose art files or documentation images. Initial package inspection correctly
distinguished the README's external screenshot from resources embedded in the game.

## Windows, saves and performance

Native tests cover title/loading/new game, settings, named saves and recovery,
unsaved-work prompts, contracts, civic recovery and current content in the exported
pack. Fullscreen passes 37 checks, including window/maximized restoration and F11
from native dropdowns/dialogs. Layout checks cover multiple viewport sizes and 115%
text. These are viewport checks on one display, not physical multi-monitor testing.

The long-session fixture builds sixty tier-3 facilities, runs 1,100 simulation hours,
keeps histories bounded, saves, and resumes identically for 100 hours. Its timed
1,000 ticks took approximately 26 seconds headlessly; this is CPU simulation work.

The native 60-building render probe at 1920×1080 and 6× simulation speed sampled
49–55 FPS, averaging 52.8, with up to 2,354 draw calls on the available Ryzen 7 8700F /
RTX 4060 / approximately 32 GB PC. A previous preview and background development work remained active. This is a funded
stress fixture, not a claim about financial viability or minimum specifications.
The release engine does not supply a useful static-memory reading, so none is claimed.

Earlier headless teardown warnings were traced to pending audio cleanup. Test scenes
now free themselves and allow the audio thread to drain before quitting. Native
captures and packaged journeys also exit cleanly. No gameplay state was reset to
hide a failing test.

## Media and distribution

The portable ZIP includes the embedded executable, player documentation, verification
manifest and engine license notices. `Play.cmd` selects 1.2.0; older previews remain
available separately. The 1.1.1 executable is preserved under `.tools/checkpoints`.
Source snapshot: `.tools/checkpoints/phase13-source.zip`.

`release/steam` contains original store copy, seven real 1080p screenshots, four
capsule drafts, a roughly 51-second H.264/AAC gameplay montage, achievement API-name
mapping and a future account-isolated Cloud plan. The media is local and unpublished.
Capsules are handoff drafts, not approved Steam assets. Gameplay is staged through
real simulation actions; no unavailable feature was added to a screenshot.

## Boundaries

The game is a compact indie demo, not a certification of commercial art quality,
accessibility compliance or broad hardware support. The owner tested the earlier
preview on this PC; no conclusions about their satisfaction or completion time are
assumed without feedback. There is no multiplayer, terrain editor, mod support,
external AI API connection, Steam SDK integration or additional-language support.
These are not advertised as included features.
