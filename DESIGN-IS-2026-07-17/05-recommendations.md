# Ten Prioritized Recommendations

| # | Priority | Area | Recommendation | Expected result |
|---|---|---|---|---|
| 1 | P0 | Feature/engine | Replace the implicit single dungeon with data-driven area definitions, area-filtered procedural pools, authored bosses, unlocks, and replay. | Extends the game from one ending into a campaign without duplicating generator code. |
| 2 | P0 | Engine | Make save/resume a real state machine: versioned area ID, checkpoint after every battle/event/reward, best depth, completion, and migration tests. | No false “saved” claims, lost progress, or legacy-save breakage. |
| 3 | P0 | Gameplay | Repair and differentiate promised systems: wire armor-break progress, show brew sequences, implement genuinely distinct kit ultimates, and align skill descriptions. | More strategic battles and no impossible or misleading goals. |
| 4 | P1 | Visual/audio | Give each area a complete identity bundle—background, semantic palette, particles, route treatment, ambient track, boss intro, and phase lighting—from area data. | New levels feel authored rather than like recolored enemy lists. |
| 5 | P1 | Engine/performance | Cache audio stems/fallbacks, pool battle FX, throttle idle redraw, delete dead atlases, use dependency-based export, and enforce Android frame/RAM/APK budgets. | Lower startup/GC cost and about 4.6MB immediate APK savings before release optimization. |
| 6 | P1 | Visual system | Reduce 127 literal colors and 22 font sizes to semantic tokens, a 6-step type scale, a consistent spacing scale, and minimum 4.5:1 small-text contrast. | Cleaner hierarchy, easier theming, fewer clipping/contrast regressions. |
| 7 | P1 | Accessibility | Add explicit focus navigation, Android back handling, keyboard/controller potion selection, non-color potion patterns, readable control names, and visible focus. | Core play becomes usable beyond pointer-only, color-dependent interaction. |
| 8 | P1 | Architecture | Extract reusable scene components for headers, status bands, overlays, area cards, and route nodes instead of building every tree in 800-line screen scripts. | Faster feature work, smaller regression surface, testable components. |
| 9 | P1 | Economy/copy | Separate banked versus run currency, disclose every event cost/outcome, disable impossible choices, return result summaries, and fix Continue/Hero/Abandon labels. | Trustworthy decisions and fewer player misunderstandings. |
| 10 | P2 | Replay/quality | Add area mastery objectives, seeded challenge runs, boss rematches, run history, and automated device/performance/content validation before expanding enemy count again. | Long-term replay value and safer content growth without live-service dependency. |

Recommendation 1, the campaign foundation of 2, and the area-identity portion of 4 are the approved implementation scope for this delivery. The remaining items are sequenced follow-up work, not hidden scope additions.
