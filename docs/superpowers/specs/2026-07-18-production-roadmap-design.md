# Potion Rogue Production Roadmap Design

**Date:** 2026-07-18
**Status:** Approved design, pending implementation plan

## Purpose

Turn Potion Rogue from a functional sort-puzzle roguelite into a replayable,
premium-feeling mobile game. The work must improve tactical variety, run pacing,
visual and audio feedback, long-term progression, and engine reliability without
breaking existing saves or the offline-first Android target.

## Product Constraints

- Godot 4.3+ using GDScript and the GL Compatibility renderer.
- Portrait Android layouts must support both 720x1280 and 576x1280 viewports.
- The game remains fully offline with no account or backend requirement.
- Existing version 6 saves must migrate without losing crystals, upgrades,
  campaign clears, active runs, or exact mid-battle snapshots.
- Early encounters remain approachable: introductory enemies are Slime,
  Skeleton, Bone Rat, and similarly readable archetypes.
- Future route nodes reveal encounter class and risk, never the exact enemy.
- Potion colors remain visually clean; no symbols are rendered inside liquid.
- Every behavior change uses a failing automated test before implementation.
- The Android export must stay within the release asset and APK budgets.

## Delivery Model

The roadmap is delivered as five independently shippable vertical slices. Each
slice ends with focused tests, the complete regression suite, live portrait
captures, and an installable debug APK. A slice may refactor only the code it
needs; broad rewrites are not permitted.

## Milestone 1: Combat Identity and Run Director

### Enemy puzzle signatures

Enemy identity moves from stat variation to board interaction. Each regular
enemy receives one primary signature chosen from a bounded, data-authored set:

- **Seal:** temporarily locks the most recently used tube.
- **Corrupt:** replaces one exposed layer with unstable essence.
- **Split:** duplicates the top layer into an empty tube.
- **Siphon:** removes mana unless a specified color is completed in time.
- **Mark:** targets a visible tube and attacks harder if it remains unchanged.
- **Shift:** rotates exposed colors between selected tubes.
- **Ward:** requires a specified potion family or combo before HP damage lands.
- **Hunt:** reduces the attack countdown when the player makes an ineffective
  pour.

Intro enemies use only Seal, Mark, or a clearly telegraphed basic attack.
Advanced signatures unlock by area and floor. A signature must never create an
unsolvable board; the board solver validates the post-effect state before the
effect is committed and falls back to a harmless intent when invalid.

Enemy definitions reference signature IDs and tuning parameters in JSON. The
battle controller resolves effects; the battle screen only presents telegraphs
and feedback.

### Adaptive Run Director

Run generation remains deterministic for a given seed. A `RunDirector` assigns
encounter kinds after graph topology is built. Its inputs are seed, area,
floor, recent node history, current HP ratio, and build power score.

Rules:

- Every path to the boss contains at least three regular combat encounters.
- No path contains more than one non-combat node consecutively.
- Floors one and two use intro or tier-one enemies only.
- Elite encounters begin at floor three.
- Low HP may increase campfire probability but never remove the minimum combat
  cadence.
- Strong builds increase contract complexity before raw enemy damage.
- Run length is seven floors for the first clear and between eight and twelve
  floors for unlocked advanced expeditions.

The map reveals `BATTLE`, `ELITE`, `EVENT`, `REST`, `SHOP`, or `TREASURE`, plus a
coarse risk indicator. Exact enemy, reward, event, and modifier details remain
hidden until the node is entered.

### Boss board phases

Each boss keeps three authored HP phases. Entering a phase plays a short break
sequence, pauses input, announces the new rule, applies a validated board
transformation, and then resumes play. Each area's boss uses a distinct rule:

- Fire Golem heats tubes and rewards rapid Fire completions.
- Bloom Horror grows corruption that must be cleansed or isolated.
- Furnace Titan cycles color wards and shifts exposed layers.

Phase changes and transformations are part of the encounter snapshot so Save &
Exit restores the exact state.

## Milestone 2: Battle Presentation, Motion, and Audio

### HUD hierarchy

Battle UI is divided into five semantic bands: expedition header, enemy stage,
player status, tactical instruction, and alchemy board/actions. Enemy HP,
intent, and countdown form one enemy card; player HP, shield, status, mana, and
combo form one player card. Decorative frames may support these groups but may
not cross labels or consume touch space.

Minimum body copy is 14 px at the 720-wide design viewport. Interactive targets
are at least 48 logical pixels. Resource bars use shared ornate components with
icons, delayed damage fills, status chips, and numeric values. The 576-wide
profile reduces ornament and spacing before reducing type size.

### Animation state pipeline

Enemy presentation exposes `idle`, `anticipate`, `attack`, `hit`, `stagger`,
`phase_break`, and `death` states. Static artwork is animated with restrained
transform, squash, glow masks, directional motion, and layered effects rather
than frame-by-frame sprite requirements. Battle feedback includes:

- 50-90 ms hit stop for heavy impacts.
- Bounded camera shake with a reduced-effects alternative.
- Potion projectile arcs and color-specific impact effects.
- Damage, block, healing, poison, and critical feedback with distinct timing.
- Phase introductions and victory finishers that never block save state.

All active tweens and effects are cancelled when changing scenes or restoring a
snapshot.

### Adaptive audio

Area music is delivered as seamless compressed loops with ambient, melody, and
percussion layers. Combat intensity selects layers; boss phases add stingers and
stronger stems. SFX ducks music briefly for high-value attacks. Audio resumes
correctly after Android focus loss, scene changes, pause, and Save & Exit.

User volume remains authoritative, including true mute. Runtime-generated stems
remain only as a fallback when packaged audio cannot load. Release validation
checks loop assets, duration, format, and total audio size.

## Milestone 3: Build Clarity and Endgame

### Build summary and reward comparison

The map and reward screens expose a dedicated build summary containing kit,
relics, mutations, upgrades, active combo recipes, and derived combat values.
Reward choices show before/after values and explicitly identify newly enabled
combos or conflicts. Recommendations are descriptive, never presented as the
only correct choice.

### Ascension

Clearing all three areas unlocks Ascension. Ascension levels add deterministic
rules in a fixed order: stronger contracts, elite affixes, reduced recovery,
advanced signatures, boss variants, and mixed-area expeditions. Difficulty
modifiers are visible before a run begins. Cosmetics and mastery marks are the
primary rewards; permanent raw power remains bounded to prevent grind gates.

Daily Challenge and seeded runs use the same generator and director interfaces,
ensuring a seed always represents the same topology and authored modifiers.

## Milestone 4: Engine Hardening

### Battle decomposition

`battle_screen.gd` becomes an orchestration shell. Presentation is moved into
focused components:

- `BattleHud` owns resource, intent, objective, mana, and combo presentation.
- `BattleOverlay` owns pause, result, reward, assist, and confirmation flows.
- `EnemyStage` owns enemy display and animation-state presentation.
- `BattleActionBar` owns Undo, New Mix, skills, ultimate, and Pause.
- Existing battle, objective, intent, modifier, combo, and skill controllers
  remain authoritative for game rules.

Components communicate through typed signals and immutable presentation
dictionaries. UI components never modify `RunState` directly.

### Save reliability

Save writes use a temporary file followed by atomic replacement. The most recent
valid save is retained as a backup. Loading validates schema and required types,
tries the backup after parse failure, and migrates only validated data. Repeated
setting changes are debounced while battle checkpoints remain immediate.

### Performance budgets

Release validation measures APK size, runtime asset size, maximum texture
dimension, and audio size. Frequently spawned battle effects are pooled. Large
backgrounds use appropriate mobile import compression; repeated UI ornaments are
atlased when that reduces draw calls without degrading sharpness. Profiling
targets stable 60 fps on a mid-range Android device with a 30 fps accessibility
fallback.

## Milestone 5: Regression, Balance, and Release

Automated screenshot scenes render the Hall, map, workshop, first battle, boss,
pause overlay, reward choice, settings, and build summary at 720x1280 and
576x1280. Tests fail when controls leave the viewport, minimum touch targets are
violated, or required labels overlap known safe regions. Golden-image review is
manual because small intended art changes must not fail CI automatically.

Seed simulation covers at least 1,000 runs per area and Ascension band. It
records combat count, non-combat streak, enemy tier, board solvability, incoming
damage, healing opportunity, run completion, and boss reachability. Balance
acceptance targets are based on first-clear and experienced-player cohorts,
without dynamic manipulation inside an active encounter.

Final release gates:

1. All focused and full regression suites pass without warnings.
2. Existing version 6 saves migrate and exact battle snapshots restore.
3. Every seeded path meets cadence and tier rules.
4. All supported viewport captures pass visual inspection.
5. Audio is audible by default and resumes after simulated focus loss.
6. APK installs, launches, saves, resumes, and exports with valid signing.

## Error Handling and Fallbacks

- Invalid enemy signatures resolve to the normal attack intent.
- Unsolvable board transformations are rejected before state mutation.
- Missing animation layers fall back to the existing static enemy presentation.
- Missing packaged music falls back to generated ambient stems.
- Invalid advanced-run data falls back to a seven-floor standard run.
- Corrupt primary saves load the backup; if both fail, the player is shown a
  clear recovery message before a new save is created.

## Out of Scope

- Online multiplayer, accounts, cloud saves, ads, and monetization.
- Replacing all existing enemy artwork.
- A real-time combat conversion.
- A complete rewrite of established battle controllers.
- Procedural generation of arbitrary enemy images at runtime.

## Success Criteria

- Consecutive enemies in the same area require visibly different decisions.
- A player can explain route risk and current build without opening external
  documentation.
- Boss phases change puzzle strategy, not only damage values.
- The Hall, map, workshop, battle, and overlays share one readable hierarchy.
- Combat feedback remains clear with reduced effects enabled.
- Music is continuously audible at the default setting and responds to battle
  intensity.
- Existing saves and all current release guarantees remain intact.
