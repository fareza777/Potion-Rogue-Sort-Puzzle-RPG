# Potion Rogue Systemic Redesign — Design Specification

## Status and decision

The July 19 audit recommendations are approved for implementation by the user, with one added requirement: replace the first dungeon battle background with full-height artwork comparable to realms two through five.

Three delivery approaches were considered:

1. **Integrated staged redesign (selected):** repair correctness and performance first, then responsive UI, deeper run systems, presentation, accessibility, and release gates. This minimizes regressions and keeps every stage playable.
2. **Visual-first patch:** produces screenshots quickly but leaves save stalls, broken corruption, route determinism, and battle coupling in place.
3. **Engine-first rewrite:** maximizes architectural purity but delays visible improvement and risks save/run compatibility.

The selected approach implements all audit recommendations without replacing the working puzzle core or existing five-realm content.

## Product outcome

Potion Rogue remains an offline-first portrait color-sort roguelike. A completed redesign must:

- Preserve existing saves, active-run exact resume, five areas, 42 enemies, solver-safe potion boards, and current progression rewards.
- Fit 576×1280 and 720×1280 without horizontal clipping, hidden actions, map/header overlap, or text below 12px.
- Make seeded runs reproducible across route, encounter, reward, and event rolls.
- Keep ordinary touch interaction responsive during New Mix, saves, audio transitions, and final-potion victory.
- Increase replay depth through adaptive pacing, real build tags, authored Ascension rules, Mastery, Daily scoring, and a larger event pool—not by adding more enemies.
- Maintain dark-fantasy premium presentation while lowering APK/runtime cost.

## Architecture

### Battle boundaries

`battle_screen.gd` becomes a thin scene composition root. It delegates:

- `EncounterCoordinator`: owns battle controllers, board events, enemy actions, objectives, and snapshot assembly.
- `BattleHudPresenter`: builds/refreshes bars, tactical readout, power strip, messages, and action state.
- `BattleOverlayController`: pause, defeat, victory, relic/upgrade choice, abandonment confirmation.
- `BattleNavigation`: scene transitions and forced save boundaries.
- `BoardActionResolver`: the only production path for enemy, modifier, and boss board mutations; every command reports applied/error and preserves solver validity.

`BattleManager` remains pure combat logic. Existing public snapshot shapes remain version-compatible.

### Persistence

Moves append compact encounter deltas to an in-memory journal. A coalescing checkpoint scheduler writes at most once per short activity window. It immediately flushes atomically on enemy resolution, pause, app background, scene transition, reward selection, defeat, and boss phase boundary. Save recovery and backup behavior remain intact.

### Procedural state

One serialized run-owned RNG supplies topology, enemy assignment, event choice, rewards, and future-floor adaptation. The run director consumes current HP ratio, build tags, recent encounter families, previous noncombat sequence, floor, realm, and Ascension. Existing unrevealed future nodes may be resolved at checkpoint boundaries; already revealed/selected nodes never mutate.

### Presentation performance

- Audio assets load per active realm; synthesized fallback is created only after a missing-resource check.
- Screen music state is explicit for hall, map/event, battle, elite, boss, victory, and defeat.
- Battle particles, trails, rings, and float labels use bounded pools.
- Resource-bar textures are cached by palette/size.
- Idle processors stop while obscured and honor Reduced Effects.
- Export includes referenced production assets only.

## Responsive visual system

`UiThemeTokens` becomes authoritative:

- Spacing: 4, 8, 12, 16, 24, 32.
- Body type: 14, 16, 18; headings: 22, 28, 36, 52.
- Minimum interactive height: 56px; primary battle action target: 88px.
- Semantic colors: surface, text, text-muted, gold, danger, health, mana, plus one accent per realm.
- Normal text contrast target: at least 4.5:1.

Area cards reflow at narrow widths: crest and summary occupy one row; action spans the full card below. Horizontal scrolling is disabled. Map positions derive from actual grammar boss depth and reserve explicit header/footer bands. Long realm names wrap or scale inside known bounds.

The main menu has one destination per purpose. The primary command stack owns New Run/Continue/Upgrades/Settings; bottom navigation becomes Home/Areas/Build/History/Credits with no duplicate destination.

## Shadow Crypt background art

Generate a new portrait battle background and preserve the old PNG as a fallback/archival asset.

Art direction:

- Full-height ancient ossuary-alchemy crypt, visually dense from top to bottom like Verdant, Astral, Frost, and Abyss.
- Gothic bone-and-stone pillars, hanging chains, carved skull reliquaries, violet/blue soul flames, restrained amber torchlight, distant Crucible Gate.
- A circular combat sigil/stone dais around the enemy staging zone and detailed foreground floor framing the potion area.
- Central 42% remains lower contrast so monsters, bars, bottles, and copy stay readable.
- Symmetrical portrait composition; strong depth; no characters, UI, text, logos, cropped frames, or baked vignette that blacks out the bottom half.
- Final runtime source: portrait PNG matching the project background dimensions, optimized import size, no mipmaps if not beneficial on the fixed 2D presentation.

Acceptance is based on a 576×1280 battle capture, not the raw artwork alone.

## Gameplay and progression

### Build semantics

Every relic, mutation, catalyst, combo, and upgrade exposes structured tags and exact effect data. Build Summary computes genuine interactions and opens by tap. Reward cards show exact delta, affected potion/skill, and compatibility with the current build.

### Ascension, Mastery, and Daily

- Ascension levels gain named authored rules and disclose danger plus reward multipliers.
- Mastery advances from production run/area/objective milestones and unlocks cosmetic or side-grade rewards.
- Daily stores UTC identity, claimed state, score, depth, time/moves, streak, local best, and a deterministic modifier package. It does not claim global sameness without a server.
- Run History shows realm, kit, Ascension, outcome, seed, duration, and build summary.

### Content balance

Expand events from six to at least fifteen, distributed by realm/tag, with exact cost/reward previews. Add objective and combo variants only where they change puzzle decisions. Existing 42 enemies receive more distinct authored motion profiles and VFX anchors instead of expanding the roster.

## Accessibility and honesty

- Reduced Effects stops or simplifies enemy idle, menu motes, route pulse, tube shake/scale, message fade, hit-stop, and particles.
- Add text-size and high-contrast settings.
- Add complete focus order and visible focus style to menu, map, battle actions, settings, and rewards.
- Expose tap-open tactical/build details; tooltips are supplementary only.
- Replace or correct Hero/Credits, Offline, Daily reward, Ascension, Synergy/Mastery, and vague reward descriptions.
- Remove the dead `color_patterns` setting unless a complete non-color identification system is implemented.

## Error handling

- Unsupported board actions fail visibly in development/tests and return a typed result in production; they never silently mutate or silently no-op.
- Failed checkpoint writes keep the journal dirty and retry at the next forced boundary while preserving the last valid backup.
- Missing audio/art resources use explicit fallback and log the missing path once.
- Loading and recoverable-error overlays prevent duplicate input and offer retry/return actions.
- Saved runs from older versions migrate without losing area unlocks, active node, HP, rewards, or board state.

## Testing and release gates

All behavioral work follows red-green TDD. Required gates:

- Production-wiring test for every intent/signature/modifier/boss board action.
- Deterministic route + reward + event replay from serialized run seed/RNG.
- Save coalescing, forced-flush, crash recovery, and measured latency tests.
- 576×1280 and 720×1280 captures for hall, every area card set, each map depth, battle, boss, event, reward, pause, settings, loading, and error.
- Minimum touch size, contrast token, focus order, and Reduced Effects contracts.
- Audio first-use, music continuity, FX pool ceiling, idle processor, and generated-texture cache tests.
- Full existing 28-suite regression.
- Android export/signature validation and an APK ceiling of 65 MiB, with warning at 60 MiB.

## Delivery slices

1. Correctness and observability: board-action contract, corruption, CI/performance harness.
2. Runtime: save journal/scheduler, audio lazy loading, VFX/resource caching.
3. Responsive foundation: theme tokens, area selector, map grammar layout, touch/focus.
4. Battle decomposition while preserving snapshots and behavior.
5. Procedural RNG/director and progression depth.
6. Copy/accessibility/reduced motion.
7. Shadow Crypt artwork and enemy/realm presentation polish.
8. Asset cleanup, 65 MiB release budget, full regression, APK handoff.

Each slice ends in a playable, exportable build and an isolated commit.
