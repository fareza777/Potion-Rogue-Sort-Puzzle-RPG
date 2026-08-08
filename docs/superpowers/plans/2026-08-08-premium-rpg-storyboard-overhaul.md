# Premium RPG Storyboard Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a stable, readable premium RPG layer with non-blocking remix, deeper encounters/progression, and deterministic handcrafted cinematic storyboards throughout every run.

**Architecture:** Preserve `RunState`, `PuzzleBoard`, and `BattleManager` as gameplay state owners. Add pure deterministic directors for wave rosters, event continuity, mastery perks, and story sequences; add focused Control components for presentation. Every behavior change begins with a failing Godot test and every cinematic leaves the underlying map/battle checkpoint authoritative.

**Tech Stack:** Godot 4.7.1, GDScript, GL Compatibility renderer, JSON-authored content, portrait Android, offline local saves.

## Global Constraints

- No runtime network or cloud narrative dependency.
- Existing save files migrate without losing active runs, unlocks, purchases, settings, or crystals.
- New Mix acknowledges within one frame and never executes the bounded BFS on the render thread.
- Storyboards are deterministic, skippable, Reduced-Effects aware, and safe to interrupt.
- Potion symbols stay optional and off by default.
- Approved realm and monster art remains the visual source of truth.
- Every screen supports 576×1280, 720×1280, and 1080×2400.

---

### Task 1: Non-blocking remix analysis and recovery

**Files:**
- Modify: `src/puzzle/remix_job_controller.gd`
- Modify: `src/puzzle/board_integrity_guard.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/remix_job_controller_test.gd`
- Test: `tests/stuck_remix_and_area_scroll_test.gd`

**Interfaces:**
- Produces: `RemixJobController.request(snapshot: Dictionary, seed: int, band: String, capacity: int) -> int`
- Produces payload: `{generation_id, integrity, result, ready}`
- Consumes: `BoardIntegrityGuard.inspect(snapshot)` and `BoardFactory.remix(state, seed, band, capacity)` exclusively inside the worker.

- [ ] Write a failing test proving `request` accepts a board snapshot and returns both integrity and remix payload without calling integrity on the caller.
- [ ] Run `remix_job_controller_test.tscn`; verify the new payload assertion fails because the controller only accepts a state array.
- [ ] Move integrity inspection and remix generation into one worker task; retain generation-ID rejection, timeout, and mutex protection.
- [ ] Update BattleScreen so pressing New Mix immediately disables the board, displays `BREWING…`, and defers economy quotation until the payload arrives.
- [ ] Add failure assertions for timeout, insufficient mana, stale completion, one-color recovery, and exact snapshot restoration.
- [ ] Run remix, input workflow, snapshot, save recovery, and gameplay integration tests.

### Task 2: Authoritative premium UI tokens

**Files:**
- Modify: `src/ui/ui_theme_tokens.gd`
- Modify: `src/ui/ui_kit.gd`
- Create: `src/ui/components/quiet_surface.gd`
- Test: `tests/ui_component_test.gd`
- Test: `tests/responsive_layout_test.gd`

**Interfaces:**
- Produces: `UiThemeTokens.type_size(role)`, `space(role)`, `motion(name)`, and `ornament_level(role)`.
- Produces: `UiKit.body_label`, `UiKit.caption_label`, `UiKit.tactical_label`, and `QuietSurface`.

- [ ] Write failing assertions for one six-step spacing scale, six semantic type roles, 56 px touch minimum, and readable body/caption contrast.
- [ ] Run UI component tests and verify the new helpers are absent.
- [ ] Consolidate duplicate spacing constants and add semantic motion/ornament tokens.
- [ ] Add quiet inset surfaces without ornate frame textures and body-font label helpers.
- [ ] Replace raw small-font construction in bottom navigation, tactical readout, Guide, Codex, Settings, Events, and Workshop.
- [ ] Run responsive and accessibility tests at all target viewports.

### Task 3: Formula Codex and Guide redesign

**Files:**
- Modify: `src/ui/reaction_codex_screen.gd`
- Modify: `src/ui/guide_screen.gd`
- Create: `src/ui/components/formula_socket.gd`
- Create: `src/ui/components/formula_card.gd`
- Test: `tests/reaction_codex_test.gd`
- Test: `tests/guide_scroll_typography_test.gd`

**Interfaces:**
- Produces: `FormulaSocket.configure(essence: String, discovered: bool)`.
- Produces: `FormulaCard.configure(id: String, formula: Dictionary, discovered: bool)`.

- [ ] Write a failing test that rejects plain `ColorRect` formula sockets and requires named jewel socket controls.
- [ ] Verify the test fails on the current black rectangle implementation.
- [ ] Build textured/outlined jewel sockets with unknown silhouettes, accessible tooltip copy, and no raw black blocks.
- [ ] Recompose cards onto quiet surfaces with category, formula length, title, effect summary, and discovery state.
- [ ] Add Guide tab edge fades and selected-tab centering while retaining whole-surface swipe.
- [ ] Capture Guide and Codex at all target viewports and verify no clipped tabs, frame/text intersections, or invisible Return action.

### Task 4: Battle hierarchy and presentation split

**Files:**
- Modify: `src/ui/tactical_readout.gd`
- Modify: `src/ui/battle/battle_hud_presenter.gd`
- Create: `src/ui/battle/battle_power_strip.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/action_clarity_test.gd`
- Test: `tests/battle_composition_test.gd`

**Interfaces:**
- Produces: `BattlePowerStrip.update_model(model: Dictionary)` with mana, reaction history, skill cost, cooldown, ultimate charge, and disabled reason.
- BattleScreen continues owning gameplay orchestration but delegates Control mutation to presenters.

- [ ] Write failing tests requiring one tactical strip and explicit disabled-reason copy for both active skill and ultimate.
- [ ] Verify existing HUD fails the semantic model assertions.
- [ ] Recompose objective, intent, damage, countdown, enemy trick, and reaction counter into a two-row tactical readout.
- [ ] Extract the mana/reaction/skill/ultimate Control construction into `BattlePowerStrip`.
- [ ] Reduce ornate frames around subordinate rows and reserve the major banner for turn state.
- [ ] Run battle input, presentation, composition, natural UI, and mobile viewport suites.

### Task 5: Deterministic real wave rosters

**Files:**
- Modify: `src/run/encounter_director.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/encounter_director_test.gd`
- Test: `tests/encounter_format_controller_test.gd`

**Interfaces:**
- `EncounterDirector.build_profile` receives `area_id` and `enemy_id`.
- Profile produces `wave_enemy_ids: Array[String]` and `formation: String`.
- `BattleManager.setup_next_wave(wave_number: int, enemy_id: String)` carries player HP/shield while replacing enemy identity.

- [ ] Write a failing deterministic test requiring two realm-valid, distinct enemy IDs for a multi-wave seed.
- [ ] Verify the old profile lacks `wave_enemy_ids`.
- [ ] Select wave candidates from the current area's floor-appropriate pools, exclude the defeated enemy when possible, and store the result in the encounter profile.
- [ ] Update next-wave setup, sprite, tactical controllers, signature controller, and intent controller for the new enemy.
- [ ] Add queued-enemy preview copy without introducing simultaneous free targeting.
- [ ] Run encounter, enemy signature, snapshot, run determinism, and balance smoke tests.

### Task 6: Event continuity and horizontal mastery

**Files:**
- Modify: `data/events.json`
- Modify: `data/perma_upgrades.json`
- Modify: `src/run/event_resolver.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/shop_screen.gd`
- Test: `tests/encounter_test.gd`
- Test: `tests/meta_progression_test.gd`

**Interfaces:**
- RunState produces `story_flags: Dictionary`, `pending_followup_event: String`, and `horizontal_perk(id: String) -> bool`.
- EventResolver produces `resolve_event_id(base_id: String, run: Node) -> String`.
- Event effects add `set_story_flag` and `queue_followup` operations.

- [ ] Write failing tests for serialized story flags, deterministic follow-up selection, and five non-stat mastery perks.
- [ ] Verify old save/run snapshots omit the new fields but still restore successfully.
- [ ] Add five follow-up event records and exact mechanical consequence summaries.
- [ ] Add five one-level horizontal mastery entries: Field Satchel, Scout Lens, Formula Primer, Emergency Cork, and Wayfinder Seal.
- [ ] Apply their effects only in normal/rematch modes and expose the category clearly in Workshop.
- [ ] Run event, lifecycle, save migration, meta progression, and visual tests.

### Task 7: Pure deterministic Storyboard Director

**Files:**
- Create: `data/storyboards.json`
- Create: `src/story/storyboard_context.gd`
- Create: `src/story/storyboard_director.gd`
- Create: `src/story/storyboard_catalog.gd`
- Test: `tests/storyboard_director_test.gd`

**Interfaces:**
- `StoryboardContext.from_run(trigger: String, overrides := {}) -> Dictionary`.
- `StoryboardDirector.compose(trigger: String, context: Dictionary) -> Array[Dictionary]`.
- Every beat validates `id`, `layout`, `background`, `title`, `accent`, `motion`, `transition`, and `duration`.

- [ ] Write failing tests for all ten triggers, same-context determinism, different-node variation, no adjacent layout/transition repetition, and missing-content fallback.
- [ ] Verify the tests fail because the story module and catalog do not exist.
- [ ] Author realm grammar, kit voice, event/battle/victory templates, and bounded substitutions in JSON.
- [ ] Implement deterministic filtering and weighted selection using the run/node seed.
- [ ] Validate texture references through VisualRegistry and omit invalid subjects safely.
- [ ] Run the director tests repeatedly with fixed seeds to prove stability.

### Task 8: Storyboard player and gameplay integration

**Files:**
- Create: `src/ui/storyboard_player.gd`
- Create: `src/autoload/storyboard_service.gd`
- Create: `scenes/storyboard_player.tscn`
- Modify: `project.godot`
- Modify: `src/ui/kit_select_screen.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/storyboard_player_test.gd`
- Test: `tests/gameplay_integration_test.gd`

**Interfaces:**
- `StoryboardService.play(trigger: String, overrides := {}) -> bool` awaits completion and returns whether a sequence played.
- `StoryboardPlayer.play(sequence: Array[Dictionary])` emits `finished(skipped: bool)`.

- [ ] Write failing tests for layer construction, skip, Reduced Effects, queue behavior, cleanup, and untouched RunState phase.
- [ ] Verify the player scene/service are missing.
- [ ] Build five-layer portrait composition with safe-area captions, tap advance, hold Skip, progress pips, parallax, and realm-specific transitions.
- [ ] Integrate run intro, route selection, event reveal/resolution, battle intro/escalation, victory/defeat, and epilogue at safe transition boundaries.
- [ ] Record beat IDs in replay journal without persisting animation time.
- [ ] Run exact mid-battle save/continue and abandon/continue regression suites.

### Task 9: Mobile visual and runtime release gates

**Files:**
- Modify: `src/testing/mobile_layout_audit.gd`
- Create: `src/testing/runtime_budget_probe.gd`
- Create: `tests/storyboard_visual_test.gd`
- Modify: `tests/mobile_viewport_matrix_test.gd`
- Modify: `tools/validate_release.ps1`
- Test: `tests/release_pipeline_test.gd`

**Interfaces:**
- Runtime probe reports `input_ack_ms`, `remix_ms`, `scene_ms`, `frame_p95_ms`, `peak_nodes`, and cache counts.
- Release validator reports APK and AAB independently and chooses the configured export artifact as the release target.

- [ ] Write failing tests requiring all primary scenes, Codex, Guide, event, and storyboard to pass the viewport matrix.
- [ ] Add capture-state checks that detect raw black formula blocks, clipped controls, and undersized action targets.
- [ ] Add bounded development telemetry with no production network output.
- [ ] Correct artifact selection and add release/debug labels plus native/assets composition output.
- [ ] Run release, presentation, responsive, and accessibility suites.

### Task 10: Premium audiovisual polish and final delivery

**Files:**
- Modify: `src/autoload/audio_manager.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/battle/enemy_display.gd`
- Modify: `src/ui/ambient_particles.gd`
- Modify: `project.godot`
- Test: `tests/audio_test.gd`
- Test: `tests/presentation_budget_test.gd`

**Interfaces:**
- AudioManager accepts story states `story_explore`, `story_danger`, `story_victory`, and `story_defeat` while preserving area identity.
- Story transitions request named haptic/audio cues through existing pools.

- [ ] Write failing audio-state and bounded-cache tests before adding new states.
- [ ] Add cinematic stems/stingers by reusing authored OGG ambience and bounded synthesized accents.
- [ ] Add anticipation, contact, recovery, and victory motion phases with Reduced Effects alternatives.
- [ ] Capture menu, areas, map, battle, Guide, Codex, event, Workshop, and every storyboard layout at 576×1280.
- [ ] Iterate until screenshots show no clipping, placeholder blocks, text/frame collisions, or unbalanced empty space.
- [ ] Run the complete test matrix, build signed AAB and debug APK, install/smoke test when an Android target is available, then commit and push the verified branch.

## Plan self-review

- Every requirement in the design specification maps to Tasks 1–10.
- New production interfaces have an explicit failing-test step before implementation.
- Story playback never becomes a save-state owner.
- The wave implementation preserves the single active target and therefore does not require a puzzle/combat rewrite.
- Existing uncommitted release/audio edits are preserved and incorporated rather than overwritten.
