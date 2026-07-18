# Meta Progression and Audio Truth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Ascension, Mastery, Daily, history, build synergy, rewards, navigation, settings, and music behavior mechanically meaningful and exactly described.

**Architecture:** Pure analyzers/rule services produce display-ready view models. UI consumes these models without inventing labels. Audio routing becomes screen-state driven and persisted accessibility settings are applied once during startup.

**Tech Stack:** Godot 4.7.1, GDScript, JSON rules, local save migration, headless scene tests.

## Global Constraints

- No network/account/leaderboard claim; Daily remains offline and deterministic.
- Existing Ascension progress is preserved.
- Meta unlocks avoid mandatory power creep; cosmetics/start-choice diversity are preferred.
- Required mobile information cannot be tooltip-only.
- Saved settings and runtime behavior must agree after restart.

---

### Task 1: Authored Ascension rules

**Files:**
- Create: `data/ascension_rules.json`
- Create: `src/run/ascension_rules.gd`
- Modify: `src/run/threat_budget.gd`
- Modify: `src/run/run_director.gd`
- Modify: `src/run/reward_generator.gd`
- Modify: `src/ui/area_select_screen.gd`
- Create: `tests/ascension_rules_test.gd`
- Create: `tests/ascension_rules_test.tscn`
- Modify: `tests/meta_progression_test.gd`

**Interfaces:**
- `AscensionRules.for_level(level: int) -> Dictionary` returns `name`, `danger_copy`, `reward_copy`, `enemy_scale`, `elite_bonus`, `modifier_bonus`, `affixes`, `boss_variant`, `reward_multiplier`.
- `AscensionRules.apply_threat(base: Dictionary, level: int) -> Dictionary`.

- [ ] Write RED assertions for every level 0–10, the five authored bands, monotonic danger/reward, and exact selector copy.
- [ ] Confirm missing service/data failures.
- [ ] Move multiplier logic out of ThreatBudget and consume the normalized rule in director/reward generation.
- [ ] Replace `ASCENSION N/N` alone with selected rule name plus exact danger/reward summary.
- [ ] Run Ascension, generation, reward, campaign, migration, and UI suites.
- [ ] Commit: `feat: give Ascension authored rules and rewards`.

### Task 2: Mastery progression connected to play

**Files:**
- Create: `src/run/mastery_tracker.gd`
- Create: `src/ui/mastery_screen.gd`
- Create: `scenes/mastery.tscn`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/run/meta_progression.gd`
- Modify: `src/ui/area_select_screen.gd`
- Modify: `tests/meta_progression_test.gd`
- Create: `tests/mastery_test.gd`
- Create: `tests/mastery_test.tscn`

**Interfaces:**
- `MasteryTracker.record(area_id: String, objective_id: String, result: Dictionary) -> Dictionary`.
- `MasteryTracker.progress(area_id: String) -> Dictionary` with completed/total/rewards.
- Rewards unlock history badges and alternative starting catalysts; existing crystal reward remains once-only for migrated records.

- [ ] Add RED tests proving objective completion calls mastery once, replay is idempotent, five-area progress renders, and unlocks affect choice availability without increasing base HP/damage.
- [ ] Confirm current `complete_mastery()` is never wired and tests fail.
- [ ] Record mastery in battle completion before run history is finalized.
- [ ] Add a visible Mastery entry from expedition selection and clear empty/completed states.
- [ ] Run mastery, meta, campaign, battle, migration, and visual suites.
- [ ] Commit: `feat: activate realm mastery progression`.

### Task 3: Honest offline Daily and richer history

**Files:**
- Modify: `src/run/meta_progression.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/ui/area_select_screen.gd`
- Modify: `src/ui/run_history_screen.gd`
- Modify: `tests/meta_progression_test.gd`
- Modify: `tests/action_clarity_test.gd`

**Interfaces:**
- `MetaProgression.daily_view(date_text: String) -> Dictionary` returns seed, claimed, label, reward, modifier package, local best.
- History record version 2 includes `area`, `kit`, `ascension`, `duration_seconds`, `build`, `seed`, `depth`, `result`, `crystals`.

- [ ] Write RED tests for `OFFLINE DAILY SEED`, `CLAIMED`, stable canonical date, once-only reward, modifier package determinism, and fully populated history cards.
- [ ] Confirm current global-sounding/static labels fail.
- [ ] Record run start time and compact build snapshot; migrate old history records with safe defaults.
- [ ] Render all fields with a readable two-row card and no tooltip dependency.
- [ ] Run meta, history scene instantiation, lifecycle, migration, action clarity, and visual suites.
- [ ] Commit: `feat: make Daily and run history exact`.

### Task 4: Semantic build analysis and numeric reward copy

**Files:**
- Create: `src/run/build_analyzer.gd`
- Create: `src/run/effect_copy.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/ui/build_summary.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `data/upgrades.json`
- Modify: `data/relics.json`
- Modify: `data/mutations.json`
- Modify: `data/catalysts.json`
- Create: `tests/build_analyzer_test.gd`
- Create: `tests/build_analyzer_test.tscn`
- Modify: `tests/action_clarity_test.gd`

**Interfaces:**
- `BuildAnalyzer.analyze(kit_id: String, upgrades: Array, relics: Array, mutations: Array, catalysts: Array) -> Dictionary` returns item counts, tags, actual interactions, score, title, and detail lines.
- `EffectCopy.describe(item: Dictionary, current_stats: Dictionary) -> Dictionary` returns exact summary and before/after lines.

- [ ] Add RED cases where item count without shared tags does not claim synergy, real Fire/Poison/Shield chains are named, catalysts/mutations appear, and `add`/`multiply` effects render exact values.
- [ ] Confirm count-based BuildSummary fails.
- [ ] Normalize missing data tags/effect metadata; do not infer mechanics from prose.
- [ ] Make BuildSummary tappable and open a compact loadout sheet with every item/effect.
- [ ] Use EffectCopy on upgrade/relic/catalyst/mutation choice cards.
- [ ] Run analyzer, reward, action clarity, battle, map, accessibility, and visual suites.
- [ ] Commit: `feat: expose real build synergy and reward values`.

### Task 5: Screen-aware audio router and persisted settings

**Files:**
- Create: `src/audio/audio_scene_router.gd`
- Modify: `src/autoload/audio_manager.gd`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/area_select_screen.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/shop_screen.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `tests/audio_test.gd`
- Modify: `tests/mobile_feedback_regression_test.gd`

**Interfaces:**
- `AudioSceneRouter.enter(screen_id: String, area_music := "dungeon", encounter_kind := "") -> String`.
- Stable screen IDs: `hall`, `expedition`, `map`, `event`, `shop`, `reward`, `battle`, `elite`, `boss_1`, `boss_2`, `boss_3`, `victory`, `defeat`.
- `AudioManager.apply_saved_settings() -> void` applies music, SFX, and reduced-effects runtime state during startup.

- [ ] Write RED tests reproducing victory→map silence, event silence, restart Reduced Effects mismatch, mute persistence, and no player/cache growth across repeated routing.
- [ ] Confirm current code fails these paths.
- [ ] Route each screen explicitly and remove screen assumptions based on the previously playing track.
- [ ] Keep bounded crossfade/ducking and apply settings before the first scene builds particles/FX.
- [ ] Run audio, settings, battle, lifecycle, mobile, and visual suites.
- [ ] Commit: `fix: make audio and effects follow screen state`.

### Task 6: Truthful Hall and navigation semantics

**Files:**
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/components/bottom_nav.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `tests/action_clarity_test.gd`
- Modify: `tests/ui_component_test.gd`

- [ ] Add RED checks that no `Hero` action opens Credits, no hardcoded live-status `OFFLINE` claim exists, Upgrades/Settings are not duplicated, active navigation is selected rather than disabled, and every visible label maps to its destination.
- [ ] Confirm failures against current Hall.
- [ ] Keep four primary commands; bottom navigation becomes `CREDITS`, `MASTERY`, `HOME`, `MAP`, `SETTINGS` only where it adds a distinct destination, or remove redundant entries from the command stack according to the final one-action-per-destination rule.
- [ ] Ensure every remaining control is ≥56px and has a focus state.
- [ ] Run action, UI component, accessibility, mobile, and visual suites.
- [ ] Commit: `fix: align Hall labels with real destinations`.

### Task 7: Slice C gate

- [ ] Run fresh import, every test scene, and save migration twice.
- [ ] Perform live flows: Daily first/claimed, Mastery first/replay, history old/new, build detail, reward choice, muted restart, victory→map/event audio.
- [ ] Capture expedition, Mastery, history, build sheet, settings, and Hall at both widths.
- [ ] Commit gate fixes as `test: verify truthful meta progression`.
