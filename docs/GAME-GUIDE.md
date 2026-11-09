# Hyperscale: Datacenter Tycoon — game guide

Detailed rules reference for **1.2.0**. For a project overview, building and
testing, see the [README](../README.md). The in-game guide (F1 or ?) provides a shorter reference.

## Your first campus

1. Buy warehouse **04-06** for $1,200, clear it for $250, and build a server hall.
2. Buy neighboring open plots **03-06** and **04-07** for $800 each. Build a
   substation ($2,200) and cooling plant ($1,800).
3. Run time. A balanced starter hall provides 100 compute; this campus draws
   60 MW and 40 cooling units. Unreserved compute earns on the open market.
4. Review and sign GPN and Synthopic. Delivering two customers unlocks
   tier 2; four unlock tier 3; all eight complete Littlebrook and unlock repeat
   commissions. Expansion grants help fund each milestone.

Buying, clearing, building, road access, heritage hearings, upgrades and hardware
all have visible costs. Construction is not refunded on demolition. Roads and
water cannot be purchased. Clearing homes displaces families; parks and monuments
create separate lasting concerns.

## Explore Littlebrook

The 16×16 town has five districts, a river and bridges, homes and shops, industrial
land, protected parks and landmarks. Land prices and sensitivity differ by district.
Utilities reach 4 / 7 / 12 Manhattan blocks at tiers 1 / 2 / 3. Capacity is shared,
but each hall needs local power and cooling connections. Riverfront cooling plants
receive 25% more capacity; remote plots require charged road-access works.

Use **Map** for the clickable minimap, camera footprint, equipment list and three
saved bookmarks. Layers show electricity, cooling, noise, ownership and local
opinion. Disconnected-campus alerts focus a problematic hall. Placement previews
show footprints, utility links and an itemized bill before you build.

Forty-eight representative walkers navigate around the river using bridges.
Road traffic responds to campus delivery activity and obeys signals. Hover over a
walker for a thought based on their neighborhood's current concerns. Protest groups
with placards appear in demonstrating districts. Activity follows pause/speed;
reduced-motion settings stop decorative activity.

## Customers and finance

Up to three contracts can run at once. Their queue order controls scarce capacity;
use **Active → Up / Down** to change priority. Hardware converts physical compute
into delivered work differently for inference, training, critical services and
cyclical experimental workloads. Projects pay on completion. Services pay for
hourly delivery plus a completion bonus, requiring 90% inference, 99% critical,
or 85% experimental delivery. Critical failure fees are 20%; other fees are 10%.
Missed terms cost 5 reputation; cancellation costs 3. Failed customers can be retried.
Previously signed legacy contracts retain their original terms.

**Review & sign** shows allocation, expected completion/slack, contribution versus
spot sales, hourly cash flow, failure fees, utilities and known incident conflicts.
It does not extend deadlines or build capacity automatically. Experimental work
varies through a 12-hour cycle; review includes a conservative estimate.

Click cash for categorized accounts, daily reports, borrowing/repayment and hardware.
Loans have a $20,000 limit and cost 0.05% interest per hour ($2.50 per $5,000).
Loan principal and grants are separate from sales and operating profit. All cash
transactions reconcile to the cent. Balanced, refurbished, efficient and training
hardware differ in purchase/refit cost, capacity, throughput, power, cooling, noise
and wear. Refits stop a hall for two hours. Tier upgrades retain the chosen hardware.

The spot market pays $1.20 per compute-hour, with a town demand limit of
**300 + 3 × average AI adoption**. Higher adoption expands this limit; it does not
create capacity or replace customer contracts.

## Keep the lights on

**Operations** shows forecasts, active impacts, recovery, reserves and equipment.
Heat and planned grid work give 12 hours' warning; surprise faults do not.
Later heat and grid events can overlap. Equipment wears, derates below 50%
condition, and can break down below 30%. All incident schedules and random state
are saved. Forecasts and impacts can pause time automatically in Settings.

| Response | Cost and effect |
| --- | --- |
| Battery module | $1,800; 240 MW-h stored energy, 120 MW output; up to three |
| Generator | $2,600; 180 MW after one hour startup; up to three |
| Refuel | $50 per fuel unit, up to $600 per purchase; 36-unit total storage |
| Warm standby | One hour to prepare; $6/h and 0.1 fuel per generator/h |
| Mobile cooling | $750 for 24h, plus $12/h; 240 cooling and 20 MW demand; local staging/utility reach matters |
| Preventive crews | $3/h per building; 70% less wear; service visits still have fees |
| Manual service / repair | Two / four hours of real downtime; fee depends on building/tier and failure |
| Relocate backup hub | $500 to another owned substation |

Batteries bridge unexpected startup gaps. Generators consume fuel according to
output. Spare grid capacity recharges batteries and incurs energy cost. Backup gear
needs an operating hub. Cooling rentals can bridge a permanent plant's service.
Forecast projections account for known overlaps and rental expiry. Heat tint,
blackouts, stopped machinery, condition markers and backup modules show impacts
in the world. Prepared service delivery prevents civic reliability complaints;
a grid event alone does not generate complaints if customers keep receiving service.

## The Town Pushes Back

**Town council** is available beside Operations and through Company. Each district
shows approval, AI adoption, population/jobs, concern values, leading demand,
escalation stress, promises and permit timers. Support and adoption are independent:
residents can use AI at work while protesting the campus next door.

Actual home/park/landmark demolition creates displacement and heritage history.
Noise depends on equipment, hardware, tiers, distance and neighborhood sensitivity.
Trips scale with campus activity. Sustained actual grid draw and cooling water use
create town-wide resource strain. Jobs, public parks and preservation improve local
conditions. Failed local services and broken promises damage trust.

Pressure of at least 18 increases stress (twice as quickly at 30); pressure below
12 reduces stress by 2 per hour. A new town has a 12-hour civic grace period.
Stress stages: **warning 4 → petition 10 → demonstration 18 → permit pause 28**.
Permit pauses restrict new server halls and hall tier upgrades in that district.
Utilities, repairs, refits and civic remedies remain available. Address the actual
cause and let stress fall to lift restrictions.

| Council response | Consequence |
| --- | --- |
| Negotiate, $600 | Promise to reduce the leading concern to the shown target within 24h; freezes escalation, with a 48h meeting cooldown. Kept promises improve trust; broken promises worsen it. Existing permit pauses remain. |
| Acoustic barriers, $900/site | Reduce that site's noise contribution 60%; visible barriers remain at that parcel |
| Relocate a hall, $1,500 + access | Keeps tier, hardware and condition; needs owned vacant land and a destination permit; two hours offline; utility reach is checked in review |
| Delivery routing, $1,600 | Adds 10 trips/h of capacity in that district |
| Grid reinforcement, $2,200 | Raises the town electricity comfort budget by 120 MW |
| Water recycling, $1,800 | Raises the town water comfort budget by 50 units/h; efficient hardware/closed-loop cooling also reduce use |
| Home, $1,800 | Builds a real house at the chosen vacant parcel; rehouses one displaced family or welcomes new workers |
| Park, $1,000 | Creates a visible park, restores one removed green space and adds local comfort |
| Replacement monument, $2,500 | Builds a protected landmark and restores one lost monument |
| Preserve, $700 | Permanent conservation covenant on a park/landmark; standing +2; cannot later demolish it |
| Skills program, $1,000 | Two jobs and +12 adoption target per program, up to three per district |
| Expedite, $2,500 | 24h hall expansion waiver; standing -8, local grievance +12, stress +4. Heritage and conservation protections still apply. |

Resource comfort budgets express civic strain, not equipment capacity. You still
need enough substations and cooling plants. Public projects on unowned land stay
public. Projects on owned vacant land keep its ownership. A $1,000 community grant
(Company, once per 24h) restores standing; it does not remove displaced families,
noise sources or unmet promises. Council actions show their cost/consequence before
confirmation and explain unavailable actions.

## Three towns

| Town | Dilemma | Charter (finale) |
| --- | --- | --- |
| Littlebrook | Riverside town with industry, homes and local history | Deliver eight campaign customers |
| Sunsprawl | Dry suburb: no river cooling bonus, +10% cooling demand, −15% cooling output, −10% grid supply | Eight customers, plus 24 consecutive hours at ≥400 online compute, ≥95% uptime and ≤80 water units |
| Oldbridge | Dense historic town with six protected monuments; heritage demolition doubles lasting grievance | Eight customers, preserve three parks/landmarks, rehouse every displaced family, reach 65% approval |

Completing a charter offers the next town (Littlebrook → Sunsprawl → Oldbridge) and
play continues afterwards. Optional distinctions: no rescue grant, debt-free at the
finale, preservation and rehousing, and 48 sustainable hours. **Littlebrook Sandbox**
starts with $1,000,000 and has no required finale.

## Research

Allocate 0 / 10 / 25 / 50% of online compute to one project. Research draws physical
compute **before** customers, so it competes with contracts; completed projects stop drawing.

| Branch | Project (work) | Effect |
| --- | --- | --- |
| Engineer | Right-sized inference (600) | Halls use 10% less electricity and cooling |
| Engineer | Predictive maintenance (1,600) | Wear 35% slower; warnings below 65% condition |
| Commercial | Customer scout (600) | Local inference customers (SmilingFace first); 20% lower fees on new contracts |
| Commercial | AI open days (1,600) | $1,200 district campaigns: 48h stronger adoption and +15 compute demand |
| Visionary | Experimental scheduler (600) | Experimental throughput floor 90% (was 65%); research commissions |
| Visionary | Water recovery loop (1,600) | Cooling uses 35% less water, plants draw 10% more power |

The second project in each branch requires the first. A companion journal comments on
what is actually happening in the campus.

## Staff

Hire zero to three teams per role. Wages are hourly; service visit fees still apply.

| Role | Wage/h per team | Effect |
| --- | --- | --- |
| Technicians | $7 | Each team auto-dispatches one service visit at a time for failed equipment or condition below 45% |
| Engineers | $9 | Each team removes one hour from new service visits and refits (minimum one hour) |
| Commercial staff | $6 | Each team adds four hours to new project deadlines and cuts new failure/cancellation fees 10% |

Dispatch priority: Failures first, Utilities first or Halls first. Repair vans,
deliveries and workers in the world correspond to real queued jobs.

## Guided introduction and achievements

New companies can enable a skippable, resumable nine-step guide (inspect, buy, clear,
build, first revenue, first customer, upgrade, forecast preparation, neighborhood
dilemma). Controls it refers to are highlighted, and a checklist tracks progress.
At 1× one simulation hour takes four seconds; F4 cycles to 3× and 6×.

Ten local achievements are stored per company save and disabled in sandbox:
First watt, Trusted provider, Neural scale, Feed the AI, The human touch, Town steward,
Keep the lights on, and one per town charter. **Company → Companies** profiles the nine
fictional customer firms ([FICTIONAL-COMPANIES.md](FICTIONAL-COMPANIES.md)).

## Controls, display and help

| Control | Action |
| --- | --- |
| Q / B / X | Inspect / buy / bulldoze |
| 1 / 2 / 3 | Build hall / substation / cooling |
| C / G | Contracts / company |
| Space / F4 | Pause or run / speed |
| F5 / F9 | Quicksave / load browser |
| F1 or ? | Scrollable game guide |
| F11 or Alt+Enter | Enter/exit fullscreen |
| Escape | Close a panel; otherwise exit fullscreen or open pause menu |
| Home / wheel / middle-drag | Whole town / zoom / pan |
| Tab / Shift+Tab / Enter | Move focus / reverse / activate |
| R | One-time $8,000 rescue if cash is below $2,000 |

F11 restores the prior window size, position and maximized state and works over
native dialogs and dropdowns. The world fills the entire viewport, including wide
screens. Settings persist display mode, resolution, 85/100/115% text, sound/volume,
remappable core controls, reduced motion and incident auto-pause. Windows shortcut
key repeats cannot toggle fullscreen twice during one transition.

## Saves and compatibility

Named manual slots, quicksave, scenario campaign checkpoints and three rotating
autosaves include thumbnails and summaries. Autosaves rotate every 15 seconds
outside menus. Save/load and delete/overwrite flows are distinct; leaving unsaved
work offers Save & continue, Discard, or Keep playing. Damaged saves can recover
from their previous-good backup. Writes use a temporary file then rename.

Save schema **12** stores economy, contracts/priorities, unlocks, lots, hardware,
refits, condition, service, incidents and random state, civic history, promises,
permit timers, adoption, public projects, research, staff and dispatches, scenario
progress, guide progress, achievements, camera, layers and bookmarks. Version
1–11 saves migrate. Older towns start citizen history from their current geography;
past displacement is not invented. Their first operational commissioning period
is preserved or initialized as appropriate. Invalid saves leave the live town intact.

Files remain in **%APPDATA%\Datacenter Tycoons\** so earlier towns keep loading
after both renames. Named slots are under `saves`; the original `town.json` remains
supported. Original prototype files are backed up before first migration overwrite.
QA runs use separate slots/settings under this directory.
