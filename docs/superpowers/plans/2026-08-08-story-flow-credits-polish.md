# Story Flow and Credits Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver one generated entry painting per encounter and release-ready Credits/rating links while leaving Guide and onboarding untouched.

**Architecture:** Narrow the existing storyboard call sites without changing the storyboard engine or its art catalog. Centralize the production Play Store URL in `AppLinks` and reuse it from Credits and Settings.

**Tech Stack:** Godot 4.7.1, GDScript, scene-based headless tests, Android export.

## Global Constraints

- Do not modify Guide or onboarding files.
- Do not change combat balance, enemy art, or generated paintings.
- Preserve untracked build and screenshot files.

---

### Task 1: Enforce one full-screen painting per encounter

**Files:**
- Modify: `tests/gameplay_integration_test.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/battle_screen.gd`

- [ ] Add failing checks: exactly one `battle_intro`, no `route_choice`, one `event_reveal`, no `event_resolution`, and no in-battle `battle_escalation` call.
- [ ] Run `res://tests/gameplay_integration_test.tscn` and confirm the old multi-trigger behavior fails.
- [ ] Remove only the duplicate full-screen calls while retaining phase transition FX, enemy warnings, wave intro animation, outcome art, sound, and music.
- [ ] Re-run the test and require zero failures.
- [ ] Commit as `fix: prevent duplicate encounter story art`.

### Task 2: Make Credits and rating links release-ready

**Files:**
- Create: `tests/credits_store_test.gd`
- Create: `tests/credits_store_test.tscn`
- Modify: `src/autoload/app_links.gd`
- Modify: `src/ui/credits_screen.gd`
- Modify: `src/ui/settings_screen.gd`

- [ ] Add a failing test for the exact creator line, production Play Store URL, absence of old internal copy, and `RateOnPlayStoreButton` on both screens.
- [ ] Run `res://tests/credits_store_test.tscn` and confirm it fails.
- [ ] Add `AppLinks.PLAY_STORE_URL`, simplify Credits, and add rating buttons wired through `OS.shell_open`.
- [ ] Re-run the new test and require zero failures.
- [ ] Commit as `feat: add release-ready credits and rating links`.

### Task 3: Regression, Android build, and delivery

**Files:**
- Produce untracked: `builds/PotionRogue-v1.6.4-debug.apk`.

- [ ] Run a headless editor parse check and the targeted gameplay/Credits/storyboard tests.
- [ ] Confirm `git diff -- src/ui/guide_screen.gd src/guide/guide_content.gd tests/guide_content_test.gd tests/guide_navigation_test.gd` is empty.
- [ ] Run all non-long `tests/*_test.tscn` scenes and require exit zero.
- [ ] Export Android Debug to `builds/PotionRogue-v1.6.4-debug.apk`, validate it, and calculate SHA-256.
- [ ] Run `git diff --check`, commit any legitimate import sidecars, push `main`, and report the APK path.
