# Code, rules and UI review — 1.2.0-preview.2

Reviewed 9 November 2026 on branch `ui-overhaul-and-review`. Scope: simulation and
economy logic, operations/civic rules against [GAME-GUIDE.md](GAME-GUIDE.md), and the
in-game interface, compared with classic tycoon conventions (RollerCoaster Tycoon,
Car Park Capital). Findings marked *confirmed* were reproduced with a probe script.

## Interface changes

The previous HUD used about 45% of the screen for chrome, every control was a text
button, and the map tools only selected plots (all actions went through the inspector).

| Area | Before | After |
| --- | --- | --- |
| Top bar | 90 px; large logo; numbers only | 56 px; town/company, clock, run/pause and speed, then icon stat chips with capacity gauges (gold near the limit, coral when exceeded) |
| Tools | Text buttons mixed with Save/Load/New town | Grouped icon dock: build tools, construction, management (Contracts, Company, Operations, Council, Research), system (Menu, Help, Sound) with shortcut badges |
| Map interaction | Clicking with a tool only selected the plot | Tools act on click; a cursor tag shows the price or the reason the action is refused |
| Inspector | Fixed 605 px panel, always open | Floating, content-sized, closable; type badge and condition gauge |
| Objective / alerts | Bottom strip; text cut off | Compact card top-left with two-line hint; warning-styled alert bar with icon |
| Layers | Dropdown plus a permanent hint bar | View cluster bottom-left; legend appears only while a layer is active |
| News | Gold text floating over the map | Centred news pill sized to the message; AI companion line in the dock |
| Management board | Same title for several tabs; text walls | Tab icons and titles per tab, run/pause state, accent-striped cards, contract terms as a fact row, locked offers dimmed (duplicate reason removed), Operations gauges, colour-coded incident cards |
| Native widgets | Godot grey dialogs, dropdowns, tooltips, scrollbars | One game theme (`ui_theme.gd`); confirm dialog with labelled buttons |

New files: `scripts/ui_icon.gd` (28 vector glyphs drawn in code), `scripts/ui_meter.gd`
(capacity gauge), `scripts/ui_theme.gd` (shared theme).

## Logic fixes applied

| Finding | Fix |
| --- | --- |
| Failed, serviced or refitting equipment still drew power and cooling, draining backup and throttling healthy halls (*confirmed*) | Demand counted only for available equipment |
| Upgrading a failed building charged full price and left it broken (*confirmed*) | Upgrades blocked while failed, in service or refitting |
| Broken promise could push district stress to 64+, making the save unloadable (*confirmed*) | Stress clamped to 60 |
| Mobile cooling kept working after its staging building was demolished (*confirmed*) | Rental requires a standing building; demolition moves the staging site |
| Backup modules could be bought for a demolished hub (*confirmed*); demolishing the hub silently disabled backup | Hub check on purchase; demolition reassigns the hub and alerts |
| Warm standby billed with an empty tank (*confirmed*) | Standby switches off with an alert; no charge without fuel |
| Technicians/crews started preventive service mid-incident, blacking out the campus (*confirmed*) | Preventive service waits while an incident is forecast, active or recovering; failures still repaired |
| Crew bookkeeping counted unavailable lots twice | Only real dispatches occupy the crew |
| Renewing mobile cooling discarded paid hours | Renewal extends the current rental |
| Expedite could be bought with no permit pause | Requires a paused district |
| Every routine alert auto-paused the game | Dispatches, reminders, kept promises and easing concerns no longer pause |
| Staff hired for one signature/repair and dismissed for free (*confirmed*) | Recruiting costs 12 hours of wages per team |
| Review & sign showed terms captured when the card was built | Review re-reads the live contract definition |
| Demolition erased acoustic barriers, contrary to the guide | Barriers stay with the parcel |
| Experimental cycle used the current hour in forecasts | Uses the evaluated hour |
| Sandbox paid the $10,000 finale grant | No grant in sandbox |
| Save summaries counted scout/vision/open commissions as deliveries | Counts campaign deliveries only |

Regression coverage: `tests/test_review_fixes.gd`.

## Design changes applied (follow-up)

| Issue | Change |
| --- | --- |
| Critical services could not recover from one lost hour | Services behind schedule catch up with spare (spot) compute, up to 125% of their hourly promise, never taking another contract's reservation. A long outage still forfeits the bonus. |
| Reputation was never used | Starts at 30; sets pay on newly signed contracts from -7.5% (0) to +17.5% (100). Cancelling in the final quarter costs 5, like a missed deadline. Older saves are lifted to the new baseline. |
| Post-campaign commissions paid below spot | Reward raised to $26,000 for 18,000 work (about $1.44 per unit). |
| Reliability promises were free | Negotiation requires an ongoing disruption; the promise is judged against the value the concern would fade to by itself (no further disruption). |
| Generators acted as permanent grid capacity | Generators run only during grid incidents. |
| Backup capped at three modules | Three battery and three generator modules per owned substation, up to 12. |

## Map changes

- Selection, hover and placement outlines and the town boundary are drawn at ground level,
  beneath buildings, trees and people; only the floating marker stays on top.
- The countryside outside the 16 x 16 town is veiled and its scenery dimmed, with a gold
  double border, so the playable area reads at a glance (as with land beyond a park
  boundary). It is decoration that fills any screen, not more city.
- The camera keeps the middle of the view inside the town footprint (scaled with zoom),
  so you cannot pan off into empty countryside but can still reach edge plots.

## Remaining recommendations (not changed)

1. **Civic standing never recovers on its own** and the trust concern applies town-wide.
2. **Preventive crews rarely pay off** ($3/h per building saves ~$0.43/h on a tier 1 hall).
3. **Oldbridge memorial** removes 1 heritage loss but demolition adds 2; guide says it restores one monument.
4. **Rescue grant** only needs cash below $2,000; **loans** have no term.
5. **Engineers 2–3** only shorten 4h repairs; **technician capacity** counts manual/crew visits.
6. **Research share** can be raised after signing with no warning that contracts will miss targets.
7. **HUMAN_TOUCH achievement** counts manual visits; tag technician dispatches.
8. **Mobile cooling** ignores heat and Sunsprawl penalties and uses little water.
9. **Pre-v10 migrated saves** judge distinctions at load time rather than at the finale.

## Verification

All 18 headless suites pass after the follow-up (960 checks, 0 failures), including
balance (five full-campaign strategies stay solvent), economy 170, progression 64 and
review fixes 39. Tests that encoded the old "one lost hour always fails" rule now check
both cases: a short interruption is recovered from spare compute, a long one still fails.
A test export embeds the brand icon and product name in the Windows executable. Title,
loading, pause, HUD, zoomed-out map and selection were rendered at 1920×1080 and inspected.
`packaged_journey` / `fullscreen_probe` were not rerun against a new export, and there has
been no human playtest yet.
