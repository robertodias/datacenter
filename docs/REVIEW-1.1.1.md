# UI, map and art review — 1.1.1

Reviewed 8 November 2026. Scope: latest civic/UI additions, map and world rendering,
inspector feedback, and the exported Windows build. This is a targeted review;
it does not replace the earlier complete simulation/campaign audit.

## Findings fixed

| Priority | Finding and trigger | Fix |
| --- | --- | --- |
| P2 | Atlas legend stayed on the previous layer after using its selector; its pause/running description also went stale. | Live legend and time status update without rebuilding the panel or losing focus. |
| P2 | Minimap used an axis-aligned bounding rectangle of inverse-projected camera corners, overstating visible land when zoomed. | Ordered camera polygon clipped to map boundaries. Parcel coordinates and H/P/C equipment symbols added. |
| P2 | Expiring an expedited permit left an enabled construction/upgrade control until reselection. The simulation rejected the action, but UI advertised availability. | Refresh inspector when the selected district's permission changes. Regression covers the actual expiry tick. |
| P2 | At 115% text, empty-land equipment description overlapped the hardware heading; a full permit error overflowed the inspector. | Compact resource description and bounded actionable permit text. Permanent conservation no longer advertises an impossible construction quote. |
| P2 | Citizen thoughts used fixed 10px text and unclamped coordinates. | Wrapped 16px base text follows text preference, has a solid panel, and stays inside the world area below the toolbar. |
| P2 | Relocated halls left acoustic barriers in simulation state, but empty parcels did not render them. | Independent depth-sorted barrier drawing on retained vacant sites. |
| P3 | Map instructions were low contrast over grass/roads; Atlas equipment heading overlapped the warehouse shortcut's layout bounds. | Dark legend backing; non-overlapping heading bounds. |

Main changes are in scripts/main.gd, map_tools.gd, minimap.gd and town_view.gd.
No economy, civic rule, save-schema or customer-balance changes were made.

## Verification

The rebuilt standalone executable passed 293 targeted checks:
- Geography/map 46; interface/activity 95; civic 61.
- New visual-review regressions 15, including minimum/wide viewport tooltip bounds,
  diagonal camera footprint, enlarged inspector layout and permission expiry.
- Packaged journey 41; native Windows fullscreen 35.

The initial packaged journey invocation omitted its required --front-menu switch;
that invocation failed the title assertion. The corrected invocation passed all 41.
Final logs: build/review-*.gd.log. Screenshots: build/review-atlas.png,
build/review-thought.png, and the updated packaged UI/world renders. Inspected the
rendered legend, projected footprint, text wrapping and inspector separation.

One 1920×1080 render smoke measured 56 FPS / 1,669 draw calls on the development
RTX 4060. Earlier runs measured 68 FPS; these short runs do not isolate a regression
or establish a minimum-spec target. Stable frame-time profiling across busy late-game
scenes and additional GPUs remains a release-quality task.

## Art assessment and remaining priorities

The original atlas has coherent isometric projection, a consistent warm town palette,
readable roof/wall shading, animated machinery, street activity and visible infrastructure
incidents. It is a strong prototype foundation. The review does not certify the art as
commercial-release quality or full Xbox accessibility compliance.

1. Give server-hall tiers distinct footprints/silhouettes and industrial service yards.
   Current upgrades share a base building with added modules and tier markers; differences
   are harder to read at overview zoom than they should be.
2. Expand district-specific house/shop/industrial variants and street props. Repeated
   roofs and facades are conspicuous in large residential blocks. Preserve the established
   atlas palette, lighting direction and pixel density when adding art.
3. Profile dense late-game scenes and test additional display scaling/hardware. Review
   diagnostic overlays at overview zoom, where building occlusion and many values compete.
4. A future UI layout pass should replace more absolute paragraph rectangles with content-
   sized containers, particularly before adding more languages or larger text settings.

## Reference checks

[OpenRCT2 main interface](https://docs.openrct2.io/en/latest/playing/main_interface/)
informs stable world-management controls, map access and inspectable resident needs.
[Xbox Accessibility Guideline 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
emphasizes readable configurable text. This pass applies those principles to real
feedback bugs; it does not claim blanket superiority over established tycoon games.
