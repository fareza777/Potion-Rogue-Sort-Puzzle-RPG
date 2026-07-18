# Systems and clarity overhaul design

## Goal

Turn the current three-area campaign into a trustworthy, replayable mobile game: every action explains its cost and result, Continue resumes the exact phase, battle utilities have real rules, the major promised combat systems work, and the visual/accessibility/performance foundations are consistent enough to extend safely.

## Chosen approach

Use a phased vertical-slice overhaul inside the existing Godot architecture. Preserve the potion-sort combat and authored art, but introduce small stateful services and reusable UI components where the current 800-line screens mix presentation, persistence, and game rules. This is safer than a rewrite and more complete than patching labels around broken state.

## 1. Run lifecycle and persistence

`RunState` owns a persisted phase enum: `MAP`, `BATTLE`, `EVENT`, `REWARD`, or `COMPLETE`. The serialized boundary moves to version 4 and includes `phase`, `current_node_id`, `pending_reward`, event resolution state, and an optional encounter snapshot.

An encounter snapshot contains battle HP/status/counters, objective progress, intent state, skill charge/cooldowns, modifiers, undo count, and the complete puzzle board including undo history. Checkpoints occur when entering a node, after every legal battle action, after an enemy action, after an event choice, when showing a reward, and after claiming a reward.

Continue routes to the saved phase rather than always opening the map. `Save & Exit` from pause checkpoints the current battle and returns to the Hall. `Abandon Run` uses a confirmation screen, banks only the documented defeat amount, marks the run inactive, clears `active_run`, and disables Continue. Android Back opens pause in battle, goes back one screen in menus, and never silently advances a run.

Legacy version 2/3 active runs migrate to `MAP` without losing their graph or inventory.

## 2. Battle utility rules and objectives

New Mix is never free. It regenerates the board and consumes exactly one move through the same `BattleManager.on_move()` path as a pour. If the enemy counter reaches zero, the enemy acts before control returns. The button and tooltip show `COST: 1 MOVE`; it is disabled during transitions and after battle end.

Undo remains limited and refunds the move counter only when a real board undo succeeds. Pause has no gameplay cost.

Armor Break listens to actual armor loss and displays `Break N armor: current / target`. Brew Order always renders the required color sequence plus current position. Cleanse and Survive show their exact targets. Objective completion produces one explicit reward once.

Kit identities become mechanically distinct:

- Ember Adept ultimate: heavy fire damage, fully breaks remaining armor, and adds one red essence to the combo history.
- Verdant Warden ultimate: heals, grants shield, cleanses one curse, and prevents the next poison application.
- Void Brewer ultimate: applies strong poison, delays the enemy action counter, and converts one exposed layer to Wild Essence.

Descriptions, button states, tutorial copy, and actual effects use the same authored kit data.

## 3. Event and economy clarity

Event choices render as reusable `EventChoiceCard` components with four explicit rows:

- `COST`: crystals, HP, curse, or `FREE`.
- `GAIN`: exact numeric healing/crystals or the type of drafted reward.
- `RISK`: curse/damage/random result, or `NONE`.
- `RESULT`: a short plain-language summary.

Unaffordable choices are disabled and show the missing amount. Random drafts say `Choose 1 Mutation/Relic/Catalyst` before selection; after applying, the result panel names the exact item and shows HP/crystal/curse deltas. Event data gains authored `summary`, `cost_text`, `gain_text`, and `risk_text` fields so UI never guesses player-facing promises from implementation opcodes.

Banked crystals and run crystals use distinct icons and labels everywhere. All event costs spend run crystals only. The Hall shows banked crystals; map/battle show both. Continue, Hero, Save & Exit, Abandon, Map, and reward labels must match their behavior exactly.

## 4. Replay systems

Area mastery tracks three deterministic objectives per area: clear, boss clear with at least 50% HP, and clear with two optional objectives completed. Mastery rewards are granted once.

Daily Challenge uses an offline date-derived seed, one unlocked area, and fixed kit/modifier rules. It stores best score locally and does not require a server. Boss Rematch unlocks after first clear, starts a boss-only practice encounter, and grants no first-clear reward. Run History stores the last 20 runs with area, seed, kit, depth, result, duration, build summary, and crystals earned.

These modes appear in the expedition screen through reusable mode cards and never overwrite a normal active run without confirmation.

## 5. Area presentation

Each area data entry owns semantic accent colors, particle preset, route line treatment, ambient track, boss track, boss intro title, and three phase-light colors. Battle/map/event screens consume that bundle.

Boss encounters receive an intro vignette, area-colored phase flash, and restrained camera/FX emphasis. Reduced Effects shortens or disables camera shake and expensive particles without removing gameplay feedback.

## 6. Visual system and reusable components

`UiThemeTokens` centralizes semantic colors, a six-step typography scale, spacing values, focus colors, corner sizes, and touch targets. Existing literal colors are migrated where touched; tests prevent new screen-level literal palette sprawl.

Create reusable components for:

- `ScreenHeader`
- `BottomNav`
- `ActionIconButton`
- `StatusBand`
- `ConfirmPanel`
- `EventChoiceCard`
- `RunSummaryCard`

Battle Undo/New Mix/Pause use a matched set of custom gold-brass control icons with consistent 64-pixel optical bounds. Hall Hero/Upgrades/Home/Map/Settings use five distinct custom icons with active jewel glow, disabled treatment, pressed feedback, and aligned captions. The active destination is visually obvious.

The redesign preserves the current dark-fantasy art direction, Cinzel display face, portrait layout, minimum 56-pixel touch target, and one-row potion board.

## 7. Accessibility and input

All interactive controls receive explicit focus neighbors, visible focus frames, readable tooltips/control descriptions, and keyboard/controller activation. Puzzle tubes support directional selection and confirm/cancel input.

Potion layers add subtle pattern/sigil overlays in addition to color: flame, leaf, wave, and spiral. Patterns remain readable under reduced effects and do not obscure liquid volume. Settings expose pattern intensity and Reduced Effects.

Android Back follows screen context: battle pause, close overlay, previous menu, then OS exit only from Hall.

## 8. Performance and package discipline

AudioManager caches melodic/percussion stems by `(area, layer)` instead of synthesizing them on every change. Battle FX reuse pooled particles/labels. Idle route/enemy controls stop redraw/process work when no animation is active.

Remove unused atlas files only after reference validation. Android export changes from `all_resources` to dependency-based export plus explicit include paths for JSON/audio/fonts. A validation script enforces budgets:

- 60 FPS target and 30 FPS reduced-effects floor.
- Battle steady-state memory budget documented and sampled.
- No background over 1440x2560.
- APK warning at 65 MB and failure at 80 MB for debug builds.
- No missing registered runtime resource.

## 9. Architecture boundaries

Screen scripts orchestrate components; they do not own serialization rules. `RunState` owns run phase and checkpoints, `EncounterSnapshot` owns battle serialization, `EventResolver` owns preview/apply/result summaries, and `MetaProgression` owns mastery/history/daily state.

Data APIs return typed dictionaries with stable keys. Invalid or corrupt snapshots fall back to the last safe map checkpoint with a user-facing recovery message; they never advance the node automatically.

## 10. Testing and delivery

Every behavior change follows red-green TDD. Required coverage includes:

- Abandon disables Continue and cannot advance a node.
- Save & Exit resumes the same enemy, board, HP, and move counter.
- Continue routes MAP/BATTLE/EVENT/REWARD correctly.
- New Mix consumes one move and can trigger an enemy action.
- Every event choice displays cost/gain/risk and returns exact deltas.
- Armor Break and Brew Order progress from real actions.
- Three ultimates produce distinct effects.
- Mastery rewards are idempotent; daily seed is stable; history caps at 20.
- Focus navigation, Android Back, potion patterns, and minimum touch targets.
- Audio cache reuse, resource reference validation, and package budgets.

Final QA captures Hall, expedition modes, event preview/result, resumed battle, each area map/boss, settings, and run history at standard and tall portrait sizes. Delivery produces a newly signed APK, reruns all suites after merge, pushes `main`, and preserves user attachments/local changes.

## Explicit non-goals

- No online account, leaderboard backend, ads, purchases, or live-service dependency.
- No replacement of the potion-sort core.
- No equipment system invented solely to mimic reference screenshots.
- No rewrite to another engine or UI framework.
