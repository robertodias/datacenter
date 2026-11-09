# Hyperscale: delivery phases 7–13

Original scope recovered from the planning conversation, 8 November 2026.
Completion requires implemented behavior and verified player journeys. External
Steam publishing and hardware/player tests must be reported separately from local
implementation; preparation alone does not count as those tests.

## 7. Feed the AI
- [x] Compute-funded Engineer, Commercial and Visionary research competes with customers.
- [x] Distinct strategic benefits, event-aware companion and adoption campaigns with consequences.
- [x] UI, save migration and exact research/event continuation.

## 8. People Behind the Machines
- [x] Technician, engineer and commercial staffing levels and priorities.
- [x] Visible repair vans, upgrade deliveries and fault response tied to actual jobs.
- [x] Citizens travel to destinations with routines and relevant thoughts/gatherings.

## 9. Three Towns, Three Dilemmas
- [x] Authored Littlebrook, hot/water-limited Sunsprawl and historic Oldbridge.
- [x] Town-specific briefs, intermediate objectives, finales and optional distinctions.
- [x] Campaign transition and continued sandbox play.

## 10. Your First Thirty Minutes
- [x] Skippable contextual guide, highlighted controls and objective checklist.
- [x] Buying, first online campus/revenue, customer, upgrade, forecast response and expansion dilemma.
- [x] Clock/pacing reviewed for human planning time.

## 11. A Town Worth Watching
- [x] Distinct original building families and recognizable upgrade stages.
- [x] Construction/demolition/delivery/repair/protest animation and legible weather.
- [x] Consistent interface, town/machinery/crowd/AI audio and adaptive music.
- [x] Scaling, remapping, contrast, reduced motion and non-color warnings.

## 12. The Tycoon Test
- [x] Full preservation, aggressive, premium-efficiency and cheap-redundancy strategies.
- [x] Balance recovery, margins, incidents, loans, objectives and described difficulty.
- [x] Decision pacing and cause/action feedback reviewed; distinguish automated evidence from external player testing.

## 13. Ready for Players
- [x] Tested Windows first launch/settings/save/update/logging and demo distribution.
- [x] Fullscreen/resolutions/migration/large-campus/long-session checks.
- [x] Steam page copy, gameplay footage, local achievements, future Cloud configuration plan, credits/instructions.

User-confirmed Phase 13 scope: standalone Windows demo and Steam release materials;
no Steamworks app exists yet. Steam SDK integration, account configuration and
publication are deferred. Only the current PC is available for playtesting, so
another physical monitor and modest-hardware tests remain unverified follow-ups.

## Phase 12 evidence
`test_balance.gd`: 114 checks passed across five fully paid campaign strategies,
with two research projects, employed teams, real incidents and loan repayment.
Minimum balances: preservation $1,696.76; redevelopment/commercial $1,893.20;
premium efficient $1,469.36; cheap redundancy/challenging $1,495.66;
relaxed commercial $9,762.56. All completed eight deliveries with no debt and no
additional capacity-wait loop. Paid rehousing is included in the redevelopment run.

These routes use 332–364 simulation hours (22.1–24.3 minutes at normal speed before
human planning/menu time). This is automated timing, not a measured human session.
The user is currently testing the phase 11 preview on the available PC; their
feedback has not yet been received. Current hardware: Ryzen 7 8700F, RTX 4060,
approximately 32 GB RAM and a 1920×1080 physical display.

The release soak passes 12 checks: a funded stress fixture with sixty tier-3
buildings runs 1,100 hours, preserves bounded histories and continues identically
for 100 hours after save/reload. The timed 1,000 ticks took 28,566 ms headlessly.
This measures simulation CPU work; it is not a graphics FPS measurement or a
financial viability claim. Local company achievements migrate from preview saves.

## Fictional-company update
Nine requested fictional sponsors now have biographies, mottos and playable missions.
Eight appear in the campaign; SmilingFace enters through Customer scout. Repeat
training commissions rotate through all nine. Company profiles and contract cards
use content-sized text; old active contracts receive current copy without changing
their signed economic terms or progress. See `FICTIONAL-COMPANIES.md` for details.

## Phases 7–8 implementation checkpoint
Research: six projects, physical compute allocation and cost/risk review, commercial
introductions/negotiated fees, adoption campaigns, factual companion journal and
save schema 8 migration. Workforce: three team roles, paid prioritized service,
engineering durations, new-contract terms, saved dispatches, visible vans/workers,
and destination-based resident routines. Schema 9 preserves teams and ongoing jobs.

Source checks: research 50, workforce 33, simulation 31, interface 95, front door 44,
geography 46; economy 168, operations 39, civic 61 passed after research integration.
Actual `Hyperscale Preview.exe`: research 50, workforce 33, packaged journey 41.
Enlarged 115% UI inspected at 1152×720; native dispatch and journal renders reviewed.
The first fullscreen invocation incorrectly included --front-menu; rerun uses the
probe's required town-view startup. Final all-phase build will reverify integration.

Paid research route completes all six projects with a $4,991.56 minimum cash balance
without disabling incidents or injecting cash. Research-off campaign strategies keep
their established viable balances. Human playtesting and commercial art review are
still separate later-phase requirements.

## Phase 9 source checkpoint
Three authored towns with scenario briefs, intermediate objectives, persistent finales,
optional distinctions and a save-aware next-town action. Sunsprawl removes river
cooling and applies measured heat/grid/water constraints. Oldbridge has denser land,
six monuments, higher prices and explicit preservation/trust requirements. Save schema
10 preserves sustainable-operation streaks and final distinctions.

`test_scenarios.gd`: 58 checks passed. Complete paid routes with live incidents:
Sunsprawl minimum $3,241.60; Oldbridge minimum $4,337.20. Both meet their real finales;
50-hour exact save continuation passes. 115% charter and both maps rendered/inspected.
Screenshots now wait 30 frames after resizing: the earlier four-frame capture was
premature and caught incomplete font repainting; the settled renders show all text.
The prior phase 8 exported fullscreen rerun passes all 35 checks.

## Phase 10 source checkpoint
Nine skippable/resumable action-based guide steps, static gold control highlights,
contextual shortcuts and a scrollable checklist. New-company guidance checkbox;
save schema 11 preserves guide preference and progress (older towns skip by default).
At 1× each simulation hour now takes four seconds; 3× and 6× remain available.
This supplies planning time without changing contract deadlines or simulation balance.
`test_tutorial.gd`: 17 checks passed, including actual build/customer/upgrade/forecast/
council actions, clock timing, skip/resume and save continuation. Minimum-size 115%
guide render inspected. A 30–45 minute human session remains a playtest target,
not a measured claim from these automated tests.

## Phase 11 source checkpoint
Original atlas now has 50 sprites, including six new neighborhood building families
and genuinely different tier 2/3 hall, power and cooling silhouettes. Town selection
uses those families, with courtyard GPU wings, a vertical neural core, industrial
service yards, high-voltage gantries and closed-loop cooling banks. Construction
cranes, deliveries, workers, fan motion, demolition dust and protests share the same
world scale and pause/reduced-motion controls. 115% settings and campus-tier renders
inspected; `test_presentation.gd` passes 20 artwork/audio-state checks.

Seven original synthesized audio assets and their reproducible generator are included:
three crossfaded music moods, town ambience, machinery, crowds and a short nonverbal
AI voice. Music responds to growth/incidents; ambience responds to actual operations.
Independent music/ambience settings and master mute persist. These are original indie
prototype assets; they are not claimed to be professionally recorded music/voice.

## Final Phase 13 verification
Version 1.2.0 is exported and packaged. All 19 suites pass against the final embedded
executable: 995 checks, zero failures and clean final logs. Eight further native
checks pass on the extracted executable in a binary-only folder, including new
company/loading, final customer content, credits and expanded in-game help.

The final 60-building native probe averages 52.8 FPS (49–55 sampled), at 1920×1080
and 6× speed on the available PC, with a preview and background development work
still present. The 1,100-hour state soak and exact 100-hour continuation pass; final
timed 1,000 ticks take 25,944 ms. This is local evidence, not a minimum-spec promise.

Distribution: `Hyperscale-Datacenter-Tycoon-1.2.0-Windows.zip` and the separate Steam
materials ZIP. Both archives pass CRC checks; the portable executable hash matches
the tested binary. Seven actual 1080p screenshots, four capsule drafts, approximately
51 seconds of H.264/AAC gameplay, store copy, local-achievement mapping and a future
Cloud plan are included. Nothing has been uploaded to Steam. See `RELEASE-1.2.md`.
