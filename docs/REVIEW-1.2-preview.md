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

## Open design recommendations (not changed)

These change balance or game feel, so they are left for a decision:

1. **Critical services cannot recover from one lost hour.** Work equals compute × deadline,
   so 99% delivery allows 0.36h of shortfall; a single refit or heatwave hour fails the
   contract. Allow ~1.25× catch-up while behind, or set work to compute × (deadline − 1).
2. **Reputation is never used.** Missed/cancelled contracts lose reputation with no effect,
   so cancelling a doomed contract in its last hour is always right. Make it affect offers
   or fees, or remove it.
3. **Post-campaign commissions pay below spot** ($1.11 per work unit vs $1.20 spot) on
   balanced hardware. Raise rewards or scale them by tier.
4. **Negotiating about reliability is a free win:** the concern decays to 37.5% in 24h,
   below the 65% promise target, without any action. Judge promises on the cause, not decay.
5. **Generators act as permanent grid capacity** and avoid civic grid strain. Dispatch them
   only during grid incidents, or count their output as strain and noise.
6. **Civic standing never recovers on its own** and the trust concern applies town-wide.
7. **Backup is capped at 3 modules** regardless of campus size; late-game outages cannot be
   covered. Scale the cap with substations or tier.
8. **Preventive crews rarely pay off** ($3/h per building saves ~$0.43/h on a tier 1 hall).
9. **Oldbridge memorial** removes 1 heritage loss but demolition adds 2; guide says it restores one monument.
10. **Rescue grant** only needs cash below $2,000; **loans** have no term. Both make early
    borrowing the dominant opening.
11. **Engineers 2–3** only shorten 4h repairs; **technician capacity** counts manual/crew visits.
12. **Research share** can be raised after signing with no warning that contracts will miss targets.
13. **HUMAN_TOUCH achievement** counts manual visits; tag technician dispatches.
14. **Mobile cooling** ignores heat and Sunsprawl penalties and uses little water.
15. **Pre-v10 migrated saves** judge distinctions at load time rather than at the finale.

## Verification

All headless suites pass on this branch (946 checks, 0 failures): balance 114, civic 61,
clients 51, economy 168, front door 44, geography 46, interface 96, operations 39,
presentation 20, progression 63, release soak 12, research 50, scenarios 58, simulation 31,
tutorial 17, visual review 15, workforce 33, and the new review-fixes suite 28. Balance
routes stay solvent with the recruiting fee and corrected power accounting. The new HUD,
board, dialogs and title were rendered at 1920×1080 and inspected. Human playtesting and the
packaged-executable probes (`packaged_journey`, `fullscreen_probe`) were not rerun.
