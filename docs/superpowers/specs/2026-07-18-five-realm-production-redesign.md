# Five-Realm Production Redesign

**Status:** Approved direction, implementation specification

**Date:** 2026-07-18

**Product:** Potion Rogue Sort Puzzle RPG
**Target:** Godot 4.7.1, offline-first Android portrait, 576×1280 and 720×1280 acceptance profiles

## 1. Objective

Turn the current three-area prototype into a production-grade five-realm roguelite without discarding the approved premium alchemy art direction. The release adds two complete areas and fifteen individually illustrated enemies while implementing all ten recommendations from the 2026-07-18 audit: solver-backed difficulty, an actually adaptive director, richer run grammar, meaningful meta progression, truthful copy/state, one visual system, stronger battle presentation, mobile accessibility, runtime hardening, and Android performance gates.

The work ships as independently testable vertical slices. At the end of every slice, existing saves resume, all existing content remains playable, and an Android build can still be produced.

## 2. Product principles

1. **Puzzle first.** Every combat effect must remain legible through the six-bottle sort board.
2. **No impossible boards.** Initial generation and every board mutation must be solver-safe.
3. **Mystery with information.** Routes hide exact guardians but disclose encounter class, risk, and reward category.
4. **Premium art, restrained chrome.** Illustration is the foreground; frames support it rather than consume space.
5. **Exact language.** Costs, rewards, status, difficulty, and online/offline behavior must match implementation.
6. **Offline and deterministic.** No account, ad, network, or analytics dependency is introduced.
7. **No potion glyphs.** Potion liquids remain clean. Accessibility uses contrast, outlines, explicit color names on selection, and optional non-liquid cues rather than symbols inside the liquid.

## 3. Delivery structure

### Slice A — Reliability and measurement

- Solver-verified initial board generation with a deterministic retry/fallback path.
- `BoardDifficulty` result containing `solvable`, `estimated_moves`, `visited_states`, and `band` (`easy`, `standard`, `hard`).
- Local deterministic balance simulator for enemy/area/kit/Ascension matrices. This is development tooling, not player telemetry.
- JSON content validation, save transaction generation/checksum, synchronized version metadata, and Android CI/release gates.
- Battle orchestration is split without changing shipped behavior.

### Slice B — Five-realm content expansion

- Frostbound Reliquary and Abyssal Apothecary.
- Fifteen individual enemy sprites, two portrait battle backgrounds, four looped music tracks, new hazards, signatures, boss phases, and route grammars.
- Existing players keep unlocked areas and Ascension. A player who already unlocked Ascension is never relocked; new players unlock it after all five realms.

### Slice C — Run and meta depth

- Runtime-aware future-floor generation, area grammar, miniboss checkpoints, secret routes, authored Ascension tiers, Mastery, improved Daily, run history, and semantic build synergy.

### Slice D — Visual, accessibility, audio, and performance finish

- Unified tokens/components, mobile-safe text/touch targets, screen-aware music, enemy-specific motion/VFX, accessible states, asset curation/compression, screenshot baselines, and Android profiling.

## 4. New areas

### 4.1 Frostbound Reliquary

- ID: `frostbound_reliquary`
- Order: 3; unlocks after `astral_foundry`
- Theme: a frozen cathedral vault where alchemical relics and their guardians are trapped in blue-white ice.
- Accent: ice cyan `#77D9F5`, moon silver, restrained violet shadows.
- Threat multiplier: `1.35`
- First-clear reward: `100` crystals
- Run grammar: eight depths including a mandatory miniboss checkpoint at depth 4, one optional recovery path before the boss, and boss at depth 8.
- Route landmarks: Frozen Nave, Shattered Choir, Reliquary Bridge, Lich Sanctum.
- Area modifiers: `permafrost` (one tube begins chilled and unlocks after a valid completion), `brittle_glass` (invalid pours briefly raise enemy pressure; never destroy a tube).
- Music: `frost` exploration and `frost_boss`, seamless loop, audible on phone speakers, compressed OGG in the final package.
- Boss: `winter_lich`.

### 4.2 Abyssal Apothecary

- ID: `abyssal_apothecary`
- Order: 4; unlocks after `frostbound_reliquary`
- Theme: a submerged occult laboratory where failed elixirs have awakened deep-sea organisms.
- Accent: abyss teal `#43D6C5`, bioluminescent magenta, tarnished brass.
- Threat multiplier: `1.48`
- First-clear reward: `130` crystals
- Run grammar: nine depths, two alternating miniboss candidates, one guaranteed event, one secret high-risk treasure branch, and boss at depth 9.
- Route landmarks: Flooded Stacks, Pressure Gallery, Blackwater Vats, Leviathan Crucible.
- Area modifiers: `rising_tide` (a solver-safe board rotation on a disclosed countdown), `abyssal_ink` (temporarily dims one top layer while preserving selection feedback and accessibility labels).
- Music: `abyss` exploration and `abyss_boss`, seamless compressed OGG.
- Boss: `leviathan_apothecary`.

## 5. Fifteen-enemy roster

Every sprite is an individual full-body transparent PNG with no atlas slicing, no text, no border, no cropped weapon/limb, a 10% transparent perimeter, consistent three-quarter mobile-game perspective, and lighting that matches its area. Each enemy defines `display_scale`, `baseline_offset`, `impact_anchor`, `projectile_anchor`, and a motion profile so status labels never overlap the character.

### Frostbound Reliquary — seven enemies

| ID | Display name | Tier/role | Signature | Intent identity |
|---|---|---|---|---|
| `frost_mite` | Frost Mite | T1 intro, skitter | `freeze` every 4 moves, chills one legal tube for 1 move | attack / mark |
| `rime_squire` | Rime Squire | T1 armored duelist | `ward` with blue affinity | attack / guard |
| `icefang_wolf` | Icefang Wolf | T2 predator | `hunt`, pressure rises after repeated source selection | attack / double strike |
| `hoarfrost_witch` | Hoarfrost Witch | T2 caster | `shift`, solver-safe outer-tube rotation | attack / weaken / lock |
| `crystal_yeti` | Crystal Yeti | T3 heavy | `shatter`, damages shield and gains armor | attack / shatter / guard |
| `reliquary_seraph` | Reliquary Seraph | Elite spectral guardian | `siphon`, drains mana on countdown | drain / guard / attack |
| `winter_lich` | Winter Lich | Boss | three-phase frost dominion | lock / corruption / attack / enrage |

### Abyssal Apothecary — eight enemies

| ID | Display name | Tier/role | Signature | Intent identity |
|---|---|---|---|---|
| `ink_slime` | Ink Slime | T1 intro, elastic | `mark`, disclosed ink target | attack / weaken |
| `drowned_acolyte` | Drowned Acolyte | T1 brittle caster | `siphon`, small mana drain | attack / drain |
| `brine_stalker` | Brine Stalker | T2 predator | `hunt`, faster after invalid pour | attack / double strike |
| `abyssal_crab` | Abyssal Crab | T2 armored heavy | `ward` with green affinity | guard / attack / shatter |
| `lantern_horror` | Lantern Horror | T3 floating caster | `corrupt`, one top layer with clear outline | corruption / attack |
| `plague_alchemist` | Plague Alchemist | T3 tactical caster | `mutate`, solver-safe top-layer color exchange | poison / heal / attack |
| `deep_oracle` | Deep Oracle | Elite ritualist | `tide`, rotates eligible tubes on countdown | drain / lock / corruption |
| `leviathan_apothecary` | Leviathan Apothecary | Boss | three-phase pressure laboratory | attack / poison / shatter / enrage |

Early encounters may only draw from each area's intro/T1 pool. Elite, T3, and boss enemies cannot appear before their authored depth.

## 6. Bosses and board actions

### Winter Lich

1. **Frozen Regalia (100%)** — armor and clear frost telegraph; no board mutation.
2. **Shattered Choir (68%)** — activates `permafrost`; queues solver-safe `frost_bind` after the transition animation.
3. **Absolute Zero (34%)** — attack interval shortens by one, ultimate window opens, and one previously chilled tube is released to create a comeback line.

### Leviathan Apothecary

1. **Pressure Carapace (100%)** — armor and poison intent preview.
2. **Blackwater Surge (66%)** — activates `rising_tide`; queues solver-safe `tidal_rotate`.
3. **Abyssal Distillation (32%)** — interval shortens, ultimate window opens, and `mutate_pair` is allowed only if the solver validates the result.

All queued actions are stored in encounter snapshots. Resume cannot replay a previously applied boss action.

## 7. Solver-backed difficulty

- Introduce `BoardFactory` to own tutorial, normal, remix, and fallback board creation.
- `BoardSolver.analyze(state, limit)` returns solution availability and estimated move depth. Existing `has_solution()` remains as a compatibility wrapper.
- Normal boards retry deterministically up to a measured budget, reject already-complete boards, and target a difficulty band derived from area depth and Assist Mode.
- If no target-band board is found, use the closest verified solvable candidate; never fall back to an unverified shuffle.
- New Mix consumes exactly one move and uses the same verified factory.
- Balance simulation records generation failure rate, solver states, estimated moves, enemy turns survived, HP delta, and outcome.

## 8. Runtime-aware procedural director

Routes are generated in deterministic segments rather than all combat decisions being frozen at run start. Topology and seed remain stable, while unrevealed future nodes may choose authored variants from a deterministic context hash.

Director context includes:

- current HP ratio;
- average moves per completed battle;
- damage taken over the last two battles;
- current build score derived from actual effect tags;
- recent encounter-kind streak;
- current Ascension rule set;
- area grammar and depth.

The director may bias recovery, combat, elite, or reward categories within explicit bounds. It cannot silently reduce an already disclosed risk, change a selected node, or replace a boss. Every final graph remains reproducible from seed plus recorded decisions.

## 9. Ascension, Mastery, Daily, history, and build semantics

- Ascension remains 0–10 but uses authored tier rules:
  - A1–2: enemy intent variation and disclosed reward bonus.
  - A3–4: one area hazard and improved relic odds.
  - A5–6: elite affixes and a miniboss rule.
  - A7–8: boss phase variants and tighter economy.
  - A9–10: combined affixes with proportional score/crystal reward.
- Selector explains exact danger and reward delta.
- Mastery advances from actual objective/area clears and unlocks cosmetics, history badges, and alternative starting catalysts—not raw mandatory power.
- Daily is labeled `OFFLINE DAILY SEED`; it uses a canonical date string, shows `CLAIMED` after reward, and never claims a global leaderboard.
- Run History shows area, kit, Ascension, seed, depth, duration, result, and compact build summary.
- Build synergy is tag-driven. `BuildAnalyzer` reports actual interactions among kit, upgrades, relics, mutations, and catalysts. No “Mastery” label is awarded from item count alone.
- Reward cards generate exact numeric copy from structured effects and show relevant before→after deltas.

## 10. Engine architecture and persistence

- Reduce `battle_screen.gd` to a coordinator. Extract battle layout construction, reward/defeat overlays, battle persistence, and encounter presentation into focused components while keeping `BattleManager` pure.
- `ContentValidator` validates required fields, types, ranges, enums, asset existence, area enemy references, intent IDs, signature IDs, modifier IDs, event operations, and boss actions during tests/import.
- Save payload adds monotonically increasing `generation` and checksum. Loader chooses the newest valid primary/backup. Commit does not destroy the last valid primary before the replacement is durable, and every rename/copy result is checked.
- Existing save versions migrate idempotently. Existing unlocked/completed areas remain; new area unlocks derive from prior completions. Existing nonzero Ascension stays unlocked.
- `project.godot` and Android preset consume one release version source.

## 11. Audio behavior

- `AudioSceneRouter` maps Hall, area selection, map, event, reward, shop, normal battle, elite, boss phases, victory, and defeat to explicit music states.
- Returning from victory/defeat always starts or resumes exploration music; map and event screens never depend on the previous screen's player state.
- Saved Music/SFX/Reduced Effects values are applied to runtime state during autoload startup.
- New area ambience uses looped OGG; SFX synthesis may remain for small effects but is cached outside the critical first interactive frame.
- Ducking remains bounded and never changes saved volume.

## 12. Unified visual and accessibility system

- `UiThemeTokens` becomes the single source for palette, typography, spacing, radii, borders, shadows, motion duration, and touch targets. `UiKit` consumes tokens and does not introduce parallel constants.
- Target palette: no more than twelve semantic UI colors, excluding illustration pixels and encounter-specific accents.
- Critical mobile copy minimum: 13px at 720 baseline; route/tactical actionable copy minimum 14px. Decorative microcopy may use 12px only when not required for decisions.
- Every interactive target is at least 56×56px.
- Selected, focused, disabled, locked, active, and unavailable are visually distinct; active navigation is not represented as disabled.
- Boss armor/status moves into a backed status chip outside the sprite silhouette.
- Potion selection uses an ornate rim/glow and small pedestal response, not a large flat circle.
- Hall removes duplicate Upgrades/Settings affordances. `Hero` becomes `CREDITS` until a real Hero surface ships.
- Build details open on tap. No required mobile information exists only in a tooltip.
- Accessibility adds text-size (`100%`, `115%`, `130%`), high contrast, explicit selected-color name, full focus order, reduced effects, assist mode, vibration, and captions for important nonverbal combat cues. Potion liquids contain no glyphs.
- Empty, loading, recoverable error, success, focus, disabled, offline, and resumed states use reusable components.

## 13. Enemy animation and battle presentation

- Motion profiles expand to `skitter`, `duelist`, `predator`, `ritual`, `heavy`, `spectral`, `floating`, and `leviathan` with per-enemy amplitude/speed metadata.
- Each profile has idle, anticipate, attack, hit, signature, phase, and defeat motion. Transform animation remains lightweight; no skeletal runtime dependency is required.
- Attack/projectile VFX originate from authored anchors.
- Particle emitters are pooled, capped, and paused when obscured. Reduced Effects removes shake/hit-stop and lowers emission without removing telegraph clarity.
- Route glow is tween/property driven rather than full redraw at 25Hz.

## 14. Asset direction and pipeline

- New enemy generation uses the existing premium painterly mobile-RPG style as reference: sharp silhouette, readable face/weapon, dark-fantasy materials, rim light matching area, transparent/chroma background, no UI/text.
- Frost background: cathedral aisle, frozen reliquaries, cyan braziers, central dark stage, readable foreground floor.
- Abyss background: submerged brass laboratory, bioluminescent vats, teal/magenta side lights, central dark stage.
- Final runtime enemy assets are downscaled to the smallest size that remains sharp at maximum display scale; source masters stay outside export if retained.
- Remove unused atlases and legacy duplicate icons from export. Curate used resources, apply mobile texture compression after visual comparison, and convert long ambience to OGG.

## 15. Testing and release gates

### Automated correctness

- Existing 25 suites remain green.
- Add board difficulty/factory, director context, content validation, five-area campaign, enemy roster, boss action snapshot, Ascension rules, BuildAnalyzer, audio routing, save transaction, and UI semantics suites.
- Run at least 5,000 board generations per difficulty band and 10,000 route seeds across five areas in deterministic simulation.
- Combat simulation reports outcomes for every 42-enemy roster entry across representative depths and Ascension 0/3/6/10. Acceptance bounds are authored per tier; no early T1 enemy may exceed the target early-defeat rate.

### Visual/accessibility

- Pixel-diff baselines at 576×1280 and 720×1280 for Hall, five maps, five T1 battles, five bosses, pause, tutorial, reward, event, settings, history, and Ascension.
- Zero clipped sprites, status overlap, offscreen controls, or decision text below the minimum.
- Contrast checks for semantic text tokens; every actionable control passes the 56px target contract.

### Android/runtime

- Fresh import and headless test matrix.
- Debug APK export, package/version verification, v2/v3 signature verification, SHA-256 recording.
- Emulator smoke: cold launch, continue exact battle, background/restore, audio interruption, abandon/continue correctness, and five-realm unlock path.
- Performance target on the chosen low-end profile: stable 30 FPS minimum, 95th percentile frame ≤33.3ms, no unbounded cache growth, no audio dropout.
- APK target ≤70 MiB for this content expansion; unused source masters and atlases must not ship.

## 16. Non-goals

- No multiplayer, account, cloud save, ads, monetization, online leaderboard, equipment screen, or live-service backend.
- No landscape/tablet redesign beyond safe responsive containment in this release.
- No replacement of the approved Hall, bottle family, original 27 enemy art, or core four-potion rules unless required to fix a verified defect.
- No symbols inside potion liquid.

## 17. Completion definition

The redesign is complete only when all ten audit recommendations are implemented, both areas are unlockable and finishable, all fifteen enemies have individual verified assets and authored mechanics, old saves migrate safely, music remains continuous across every route, visual baselines pass at both widths, balance simulations meet authored bounds, the complete test matrix passes after merge, and a signed installable APK is delivered with hash and release notes.
