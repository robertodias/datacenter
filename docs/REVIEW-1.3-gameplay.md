# Gameplay and logic review: 1.3 (art integration build)

Reviewed 9 November 2026.

**Scope:**
- `simulation.gd`, `economy.gd`, `clients.gd` and `save_store.gd`;
- `operations.gd`, `civic.gd`, `workforce.gd` and `research.gd`;
- `scenarios.gd`, `town_rules.gd`, `achievements.gd` and `tutorial.gd`.

Each rule was checked against [GAME-GUIDE.md](GAME-GUIDE.md). Findings already fixed or listed
in [REVIEW-1.2-preview.md](REVIEW-1.2-preview.md) are not repeated.

**How findings were checked:**
- **Confirmed:** reproduced with a headless probe script against the current code. Every
  probe was run twice, by the reviewer and again independently.
- **Reading:** found from the code only.

**Status: all 17 findings fixed** (9 November 2026). Each has a regression check in
[`tests/test_gameplay_review.gd`](../tests/test_gameplay_review.gd), and the guide is updated.

| # | Fix |
| --- | --- |
| 1 | Demolishing the last building returns the rental. Older saves with an orphaned rental load, and the rental ends on load. |
| 2 | Only connected halls, and cooling plants that reach a substation, add demand. |
| 3 | Generators run on the real incident state (`incident_grid`), not Sunsprawl's weaker grid. |
| 4 | A promise target is `min(0.65·v, v − 2)`, so it always needs a real cut. |
| 5 | The rental moves with a relocated hall. Its 20 MW and $12/h are billed only while it works. |
| 6 | `power_plan` uses at most `module_limit` batteries and generators; surplus modules stay idle. |
| 7 | Contracts record the commercial teams that signed them. Dismissing teams withdraws their hours and fee discount. |
| 8 | `new_game` takes the achievements to carry; "Continue to …" passes them. |
| 9 | Building a substation reconnects backup equipment when no hub exists. |
| 10 | Upgrades clear `wear_warned`. A refit no longer restores condition (see 12). |
| 11 | Scout services pay rate 1.1 plus a $480 bonus (about $1.50 per unit), and companion deliveries give +3 reputation. |
| 12 | A refit keeps condition and costs `max(refit, build-price difference)`. |
| 13 | Completing "build" also completes "clear". |
| 14 | Repeat commissions open on `campaign_won`. |
| 15 | Demolition clears `permit`. |
| 16 | Scout services need 90% delivery, as the guide says. |
| 17 | A hall that is failed, refitting, in service or disconnected makes a quarter of its trips. |

## Critical: breaks saves or a core rule

### 1. A save becomes permanently unloadable after renting mobile cooling and clearing the campus

*Confirmed.* `rental_until` is never reset. When every building is demolished,
`demolish()` sets `rental_site=-1`, but `Operations.valid()` rejects
`rental_until>0 and rental_site<0`. Every later save is then refused as "damaged or from an
unsupported version". While the rental is still running, it also keeps billing $12/h and
adds 20 MW of demand with no buildings.

- Probe: `rental_site=-1 until=32` → `save true` → `load false`.
- Where: `operations.gd:227`, `simulation.gd:205-208`.
- Fix: end the rental when no staging site remains (`rental_until=0`). Make `valid()`
  tolerate an expired rental with no site, so existing saves load.

### 2. Disconnected halls and unpowered cooling plants still take power and cooling

*Confirmed.* `metrics()` adds each available building's demand before it checks connections.

- A hall out of reach of power or cooling produces nothing, yet it still takes 40 MW and
  40 cooling from the shared pool, and you pay for that electricity.
- Three far halls on the starter campus push demand to 180/120 MW and **halve the online
  compute of the connected halls** (100 → 50).
- The same happens whenever a substation fails and strands halls.
- An unpowered cooling plant adds 20 MW (energy $7.20 → $9.60/h).

Where: `simulation.gd:387-388`.

Fix: count a hall's demand only when it is connected and not refitting. Count a plant's draw
only when it reaches a substation.

### 3. Sunsprawl generators act as permanent power, with no incident

*Confirmed, by both reviewers.* Sunsprawl multiplies `weather.grid` by 0.9 every hour, and
`power_plan` lets generators run whenever `weather.grid<1`. Warm standby therefore fills any
deficit permanently.

- Probe: power 108/160 → 160/160 and compute 202 → 300, with 0 incidents.
- This breaks the guide's rule that generators are "never permanent capacity". It also
  makes the Sunsprawl 400-compute charter cheap.
- Generator output isn't counted as grid draw, so it also dodges the town's electricity
  concern.

Where: `simulation.gd:375-376`, `operations.gd:65`.

Fix: decide whether generators may run from the real incident state
(`Operations.conditions(ops).grid<1`), not from the town-adjusted weather.

## High: exploits and lost value

### 4. A negotiated promise can be kept by doing nothing, for repeatable standing

*Confirmed.* `promise_target` is `max(8, 0.65×value)`, so a concern at exactly 8 needs no
improvement at all.

- One demolished ordinary park leaves heritage at 8 forever.
- Negotiating then pays +3 town-wide standing, −10 stress and +6 opinion for $600.
- This repeats every 48h in every district: 69 → 72 → 75 → 78 → 81.

Where: `civic.gd:88-90`.

Fix: the target must be below the current value (for example
`min(0.65·v, v − 2)`). Refuse to negotiate when the concern is already at its floor.

### 5. Relocating the hall that stages mobile cooling strands the rental, which keeps billing

*Confirmed, by both reviewers.* `relocate_hall` never updates `ops.rental_site`, although
`demolish` does. After the move the rental cools 0, while it still charges $12/h and draws
20 MW. In the probe, compute fell from 100 to 0.

Where: `simulation.gd:851-869`.

Fix: move the rental with the hall. Bill the 20 MW and $12/h only while the rental actually
works.

### 6. The backup module cap can be bypassed by demolishing substations

*Confirmed, by both reviewers.* The cap of 3 modules per substation (up to 12) is checked
only when buying. Build 4 substations, buy 12 batteries and demolish 3 substations: all 12
batteries stay (1,440 MW output) on a limit of 3. Each extra 3 modules costs about $2,450.

Where: `operations.gd:84-88`, `simulation.gd:200-204`.

Fix: cap usable modules at `module_limit` in `power_plan`, or refuse the demolition. Capping
is friendlier: surplus modules go idle until another substation exists.

### 7. Hire, sign, fire: commercial staff's benefit is locked in at signing

*Confirmed, by both reviewers.* Commercial teams improve terms only while
`contract_definition` runs. Hire 3 teams ($216 fee), sign, then dismiss them at no cost.
Probe: the studio deadline went from 48h to 60h, fees from 10% to 7%, and wages afterwards
were $0/h. Keeping those teams for 72h would cost $1,296.

Where: `research.gd:141-145`, `workforce.gd`.

Fix: keep the benefit only while the teams stay employed, re-checking at delivery or
failure. Or require a minimum term or severance pay.

### 8. Continuing to the next town wipes earned achievements

*Reading.* "Continue to …" calls `start_company`, which calls `new_game`, and `new_game`
resets `achievements=[]`. LITTLEBROOK, SUNSPRAWL and OLDBRIDGE can never be held by one
company, so 10/10 is unreachable, although the guide says achievements are stored per
company.

Where: `simulation.gd:123`, `main.gd:1029-1032`, `scenario_panel.gd:16`.

Fix: carry achievements (and reputation, if intended) through the continue flow.

## Medium

### 9. Backup stays offline after rebuilding the substation

*Confirmed, by both reviewers.* The alert reads "offline until you build a substation", but
`build()` never re-attaches the hub. It stays offline indefinitely until the player pays
$500 to move the hub. Buying any new module re-attaches it for free.

Fix: when a substation is built with no hub and modules exist, attach them automatically.

### 10. The wear warning is never re-armed after a refit or upgrade

*Confirmed.* Refit (condition set to 100) and upgrade (at least 85) don't reset
`wear_warned`. A hall warned once can later wear down to 31% and fail with no second warning.

Where: `simulation.gd:272`, `simulation.gd:777`.

Fix: clear `wear_warned` wherever condition is restored.

### 11. Scout services pay over twice the market rate, with reputation on top

*Reading, arithmetic from the code.* A scout service pays rate 2.1 plus a $900 bonus for
1,200 work: about **$2.85 per unit**, up to about $3.35 with reputation. It repeats every
24h forever and gives +10 reputation per delivery. Spot pays $1.20 and repeat commissions
were tuned to about $1.44.

Where: `research.gd:59`.

Fix: a rate near 1.3–1.4, or no reputation gain from companion contracts.

### 12. A refit works as a cheap repair

*Confirmed.* A refit sets condition to 100. That turns a $2,800 refit into a full repair of a
worn hall, cheaper than service on a failed tier-3 hall. Building refurbished and refitting
to efficient is also $50 cheaper than building efficient directly.

Where: `simulation.gd:767-777`.

Fix: keep the hall's condition through a refit (new racks, same building). Price the refit
at no less than the build-price difference.

## Low: rules versus text

| # | Finding | Status | Fix |
| --- | --- | --- | --- |
| 13 | Tutorial step "clear" stays open when the campus is built on vacant plots. The guide then asks the player to demolish the warehouse ($1,450) for nothing (`tutorial.gd:18`) | Confirmed | Mark "clear" done when "build" completes |
| 14 | Repeat commissions open at 8 deliveries, before Sunsprawl or Oldbridge charters are complete. The milestone says they open on completion (`simulation.gd:294`, `310`) | Reading | Gate on `campaign_won`, or reword |
| 15 | Demolishing a protected site leaves `permit=true`, so a memorial later built there skips the $4,000 hearing (`simulation.gd:197-199`) | Reading | Clear `permit` on demolition |
| 16 | Scout inference needs 95% delivery; the guide says inference needs 90% (`research.gd:59`) | Reading | 0.9, or document the stricter terms |
| 17 | Delivery trips are fixed per building, so failed or idle halls make as much traffic as busy ones. The guide says trips scale with activity (`civic.gd:60-68`) | Reading | Scale hall trips by online share |

## Design observation (not a bug)

The five balance strategies finish the Littlebrook campaign within a narrow window:
- 332–364 game hours;
- final cash $114k–$153k;
- lowest cash $1.5k–$1.9k on standard difficulty.

Strategy choice (preserve or redevelop, premium or cheap hardware) changes the route, but
not the pace or the outcome. Phase 15–17 decisions in [EVOLUTION-PLAN.md](EVOLUTION-PLAN.md)
(area tools, marketing, protests) are the natural place to widen that spread.

## Checked and found correct

**Contracts and money:**
- Contract deadlines are checked after exactly `deadline` ticks, and projects win a tie.
- Catch-up never takes another contract's reservation and stops at the 1.25× cap.
- No contract can be signed twice. Cancellation costs and reputation bounds are correct.
- There are no refund or downgrade paths.
- Loans, rescue, ledger and cash reconcile.

**Saves:**
- The save round-trip is byte-identical after 300 further ticks.
- Real saves from the archived v4, v6, v9 and v11 builds load, run and re-save cleanly.
- Backup, recovery and delete in `save_store` are correct.

**Operations:**
- The incident lifecycle always terminates. The forecast lead is 12h and outages are never
  forecast.
- Operations prices and durations match the guide's tables.
- Littlebrook and Oldbridge generators run only during grid incidents.
- Wear, derating, failure and predictive maintenance follow the guide.

**Civic:**
- Stage thresholds, stress, grace and the promise freeze are correct.
- Council costs and effects are correct, including barriers at ×0.4 on generator noise.
- Permit pauses are enforced on build, upgrade and relocation.

**Scenarios and achievements:**
- The Sunsprawl charter is reachable with tier-3 closed-loop cooling (about 42 water per
  hall).
- The Oldbridge distinctions are as written.
- Achievement conditions are correct, apart from #8 and the known HUMAN_TOUCH issue.

Probe scripts: the session scratchpad `review/` and `review2/` folders (not in the repo).
