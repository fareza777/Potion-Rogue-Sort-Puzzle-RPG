# Systemic Polish Expansion Design

**Date:** 2026-07-19

**Status:** Approved design, pending written-spec review

**Product:** Potion Rogue: Sort Puzzle RPG

**Primary platform:** Android portrait

## Objective

Turn the current campaign into a more resilient, varied, and polished roguelite without replacing the existing deterministic run generator, battle controllers, save format, or authored art direction. The work covers the ten approved recommendations: board integrity, bounded remix performance, replay diagnostics, mobile layout coverage, adaptive difficulty, encounter variety, tactical remix economy, richer Areas presentation, staged battle animation, and adaptive audio/haptics.

## Success Criteria

- A battle can never remain in an unsolvable board state without offering a working recovery action.
- New Mix presents a visible result and completes within 250 ms on supported Android-class hardware.
- Identical run seed plus replay journal reproduces the same board, intents, rewards, and route choices.
- No primary control clips or becomes unreachable at 576x1280, 720x1280, or 1080x2400.
- Difficulty is decided before an encounter starts and never secretly changes enemy values mid-battle.
- Each area can produce at least three materially different encounter formats during repeated runs.
- Areas communicates scrollability, realm progress, lock state, first-clear reward, and selected destination.
- Battle motion has readable anticipation, action, impact, recovery, and death phases.
- Music transitions audibly between exploration, battle, danger, elite, boss, and victory without restarting the same track unnecessarily.
- Existing version 1.3.0 saves load without loss of campaign, build, settings, or active-run progress.

## Constraints

- Keep Godot 4.7.1 and GDScript; add no third-party runtime dependency.
- Preserve `RunRng`, `RunGenerator`, `CheckpointScheduler`, battle-controller composition, `FxPool`, `AudioManager`, and the current data-driven enemy/area catalogs.
- Keep New Mix understandable: its cost must be visible before tapping.
- Emergency recovery must never be blocked by insufficient mana.
- Potion liquids remain color-only; do not add symbols inside potion layers.
- Honor music, SFX, vibration, assist mode, and reduced-effects settings.
- Bound replay data and visual effects to protect APK size, save size, memory, and battery.

## Architecture

The expansion uses three vertical slices. Each slice exposes small, testable controllers instead of adding more responsibilities to `battle_screen.gd`.

### Slice A: Engine Integrity and Diagnostics

#### BoardIntegrityGuard

`BoardIntegrityGuard` owns post-mutation board validation. It consumes a board snapshot and returns one of three outcomes:

- `valid`: the state is playable and no intervention is required.
- `recoverable`: the state is not solvable with its remaining color counts, but a deterministic emergency redeal can be generated.
- `invalid`: the snapshot is malformed and must be rolled back to the last valid checkpoint.

Validation runs after enemy board commands, snapshot restoration, normal pours that complete a tube, and New Mix. It checks tube count, capacities, layer values, complete color sets, legal moves, and bounded solver output. It does not deal damage, advance turns, or alter battle values.

`PuzzleBoard` remains the mutation boundary. `BoardIntegrityGuard` reports a decision; `PuzzleBoard` applies a deterministic result through the existing factory path.

#### Remix execution

Catalog-backed deals remain synchronous because they are constant-time. Solver-backed remix jobs use `WorkerThreadPool` and carry a monotonically increasing generation ID. The UI accepts only the latest generation ID, preventing a stale result from overwriting a newer board or restored checkpoint.

While a job is active:

- Board input and the New Mix button are disabled.
- A short `BREWING...` state appears on the action.
- Battle timers and enemy countdowns do not advance until the result is committed.
- Failure or timeout restores the previous valid snapshot and consumes no move or mana.

#### ReplayJournal

`ReplayJournal` records compact deterministic events:

- run seed, area, ascension, and encounter node;
- selected tube and destination for each legal move;
- undo, skill, New Mix, and emergency recovery actions;
- generated board seed and accepted generation ID;
- route, reward, shop, and event choices;
- enemy-intent and reward checksums.

The active run checkpoint stores at most 300 events. Completed runs retain a compact summary and checksum, not the entire journal. A developer-only replay entry point replays the journal without exposing debug UI in release builds.

#### Mobile verification matrix

Headless UI tests instantiate main menu, Areas, map, battle, pause, reward, event, shop, and settings at three viewport sizes: 576x1280, 720x1280, and 1080x2400. Tests assert visible controls remain inside safe bounds, required scroll containers expose range, modal actions fit, and touch targets remain at least 56 logical pixels.

### Slice B: Gameplay Variety and Fairness

#### EncounterDirector

`EncounterDirector` creates an immutable encounter profile before battle construction. Inputs are area, floor, ascension, current HP ratio, previous encounter result, recent invalid-move count, and recent emergency-remix count. Outputs are enemy tier, encounter format, objective, modifier budget, reward multiplier, and an assistance tier.

Assistance is transparent and bounded:

- It may select an easier board band, increase attack countdown by one, or offer a recovery-biased reward.
- It never reduces current enemy HP, damage, armor, or intent after battle begins.
- Ascension floors remain authoritative; assistance cannot cancel an explicit ascension modifier.
- The encounter profile is stored in the checkpoint and replay journal.

#### Encounter formats

Five formats share the current battle scene and controller composition:

1. `duel`: defeat one enemy.
2. `survival`: survive a disclosed number of enemy actions.
3. `multi_wave`: defeat two enemies with HP, mana, board, and temporary effects carried between waves.
4. `protect_cauldron`: prevent a secondary durability meter from reaching zero while completing a potion target.
5. `elite_contract`: defeat an elite under one disclosed modifier for an increased reward.

Area grammar controls allowed formats and minimum floor. Intro floors use duel only. Multi-wave and protect-cauldron cannot appear before floor three. Boss nodes retain authored boss-phase behavior rather than selecting these formats.

#### New Mix economy

New Mix has two explicit modes:

- `Standard Mix`: costs one combat move. The first standard mix per encounter has no mana cost; subsequent standard mixes also cost 20 mana.
- `Emergency Mix`: available only when `BoardIntegrityGuard` marks the board recoverable. It always costs one combat move, costs no mana, and deterministically creates a solvable two-or-more-color board.

If an asynchronous mix fails, no resource is charged. The button subtitle shows `1 Move`, `1 Move + 20 Mana`, or `Emergency • 1 Move` before activation.

#### Realm mastery and weekly challenge

Each area gains mastery XP from clear depth, elite contracts, boss clears, and ascension. Mastery unlocks cosmetic route-frame variants, codex detail, and one area-specific starting-choice option; it does not add permanent raw damage.

The weekly challenge derives a seed from ISO week plus a fixed game salt. It fixes area, kit options, route graph, and encounter profiles. Local best score records depth, completion time, damage taken, and emergency mixes. No network leaderboard is claimed or shown.

### Slice C: Presentation and Feedback

#### Areas presentation

The current vertical list remains the information architecture. It gains:

- a visible themed scroll thumb and `SWIPE TO EXPLORE` cue that disappears after the first scroll;
- card snapping after drag release;
- a selected-card state with accent glow and realm background preview;
- mastery progress, best depth, clear count, difficulty, and first-clear reward;
- one primary `ENTER EXPEDITION` action outside the card list, bound to the selected unlocked card.

Locked cards remain visible but cannot become the launch target. Back navigation remains persistent and reachable outside the scrolling content.

#### Potion interaction presentation

Selecting a tube highlights legal destinations and dims illegal destinations. A light arc previews source-to-destination direction. Invalid pours state one short reason: `COLOR MISMATCH`, `FLASK FULL`, or `SEALED`. Potion liquids use the existing colors and shader/particle treatment only; no glyphs or symbols are rendered inside layers.

#### BattlePresentationDirector

`BattlePresentationDirector` sequences presentation without owning combat rules:

1. anticipation;
2. action travel;
3. impact frame;
4. damage/resource update;
5. stagger or block response;
6. recovery;
7. death or next-turn handoff.

It coordinates `EnemyDisplay`, `BattleFx`, camera impulse, UI resource bars, audio cues, and haptics. Gameplay resolution remains synchronous and authoritative; presentation consumes an immutable result payload. Reduced-effects mode shortens motion, removes camera displacement, caps particles, and preserves timing clarity.

#### Adaptive audio and haptics

`AudioManager` gains a music-state API rather than screen-specific track restarts. States are `hall`, `exploration`, `battle`, `danger`, `elite`, `boss`, and `victory`. Transitions use short crossfades and retain playback when the requested state is unchanged.

Danger activates below 30% player HP. Boss phase transitions may raise intensity without replacing the base theme. Haptic patterns are centralized as `select`, `pour`, `blocked`, `player_hit`, `enemy_hit`, `elite_warning`, and `victory`, and remain disabled when vibration is off.

## Data and Save Changes

The save schema increments by one migration step and adds optional fields only:

- `area_mastery: Dictionary`
- `weekly_records: Dictionary`
- `seen_scroll_cues: Array`
- active-run `encounter_profile: Dictionary`
- active-run `replay_journal: Array`
- active-battle `mix_count: int`

Migration defaults keep old saves valid. Unknown fields remain tolerated by existing dictionary-based loading. Replay restoration validates its seed and checksum; on mismatch, the game loads the last normal checkpoint and discards only the invalid journal.

## Error Handling

- Malformed board snapshot: restore the previous valid encounter checkpoint and show `BREW RECOVERED`.
- Solver timeout or worker failure: retain the current board, charge nothing, re-enable input, and show `MIX FAILED — TRY AGAIN`.
- Missing encounter-format data: fall back to `duel` with the authored enemy.
- Missing mastery or weekly data: initialize defaults without blocking campaign access.
- Missing adaptive music layer: continue the currently valid track and log one development warning.
- Presentation interruption from pause or scene exit: cancel tweens, return pooled FX, and persist authoritative combat state.

## Testing Strategy

Every subsystem follows red-green-refactor with focused scenes:

- board integrity properties across malformed, partial, wild, locked, completed, and restored boards;
- deterministic worker results and stale-generation rejection;
- replay round-trip and checksum mismatch recovery;
- encounter-profile determinism, transparency, and ascension floors;
- each encounter format from start through reward or defeat;
- standard/emergency mix costs, failure rollback, and checkpoint restoration;
- mastery and weekly migration/determinism;
- viewport matrix and touch-drag Areas behavior;
- presentation ordering, interruption, reduced-effects caps, and FX-pool return;
- audio-state idempotence, crossfade routing, settings, and haptic suppression.

The complete existing `tests/*_test.tscn` suite remains a release gate. Android debug export and APK signature verification remain mandatory before handoff.

## Delivery Sequence

1. Board integrity, remix job boundary, replay journal, and viewport test harness.
2. Encounter director, encounter formats, remix economy, mastery, and weekly challenge.
3. Areas presentation, potion guidance, battle presentation director, and adaptive audio/haptics.
4. Full regression, balance simulation, Android build, signing verification, and device handoff.

Each sequence ends in a working game state and preserves current save compatibility.

## Non-Goals

- Online accounts, cloud save, multiplayer, or a claimed global leaderboard.
- Replacing all existing enemy sprites or backgrounds.
- Rewriting the battle engine into ECS.
- Adding a second currency solely for New Mix.
- Changing potion layers to icon- or symbol-based identification.
- Dynamically weakening an active enemy after the player takes damage.
