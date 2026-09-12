# Remove Banner and App Open Ads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new production AAB in which banner ads and App Open ads are disabled, menu layout no longer reserves space for a banner, and the remaining optional rewarded/interstitial behavior is preserved.

**Architecture:** Keep AdService as the single ad boundary. Disable banner and App Open at the release configuration and code policy level, remove banner-only layout reservation from the scene UI, and leave rewarded ads plus carefully paced interstitials unchanged. Validate the behavior through the existing Godot headless test suite, then build and stage the signed Android App Bundle for Play production.

**Tech Stack:** Godot 4.x, GDScript, Godot headless tests, Android AAB export, Google Play Console.

**Spec:** User request on 2026-08-25: remove banner ads, remove App Open ads, adjust the screen, build a new AAB, and publish to production.

## Global Constraints

- Banner ads must not show and menu screens must not reserve banner height.
- App Open ads must not load or present in release builds.
- Rewarded ads remain optional and available for the existing player actions.
- Existing interstitial pacing and safety gates remain unchanged.
- The production package id remains `com.farezagames.potionrogue`.
- Do not claim production publication until Play Console provides a fresh success state.

### Task 1: Add failing regression coverage for the disabled formats

**Files:**
- Modify: `tests/ad_service_test.gd`
- Test target: banner/App Open configuration and scene policy

- [ ] **Step 1: Write the failing assertions**

Assert that production configuration disables the `banner` and `app_open` sections, that `AdService.should_reserve_banner()` is false, that no banner scene is registered, and that App Open cannot be due.

- [ ] **Step 2: Run the focused test and verify it fails for the expected reason**

Run the repository's existing Godot headless test command for `tests/ad_service_test.gd`; the failure must be caused by the current enabled banner/App Open configuration, not a test syntax error.

### Task 2: Disable banner and App Open behavior and remove layout reservation

**Files:**
- Modify: `data/ads.json`
- Modify: `src/autoload/ad_service.gd`
- Modify: `tests/ad_service_test.gd`
- Inspect/modify only if needed: menu layout code using `AdService.banner_reserve_px()`

- [ ] **Step 1: Set release configuration to disable banner and App Open**

Set `banner.enabled` and `app_open.enabled` to `false`, while retaining the existing rewarded and interstitial IDs and pacing values.

- [ ] **Step 2: Make runtime policy explicit**

Ensure release runtime never requests or presents App Open ads and never shows/reserves a banner when those sections are disabled. Preserve safe no-op behavior on desktop/plugin-less builds.

- [ ] **Step 3: Remove banner-only screen spacing**

Update menu layout code so the bottom area uses normal content bounds when banners are disabled; battle, map, events, story, and tutorial layouts must remain unchanged.

- [ ] **Step 4: Run focused tests and the full existing test suite**

Run the focused AdService test, then the repository's complete headless Godot test command. All tests must pass with zero failures before building.

### Task 3: Build and verify the Android App Bundle

**Files:**
- Use existing release build scripts and export preset; do not commit keystore material or credentials.
- Output: a new signed `.aab` under the repository's existing `builds` directory.

- [ ] **Step 1: Confirm the current release version/code and signing path**

Read the project version, export preset, and existing build script without exposing credentials.

- [ ] **Step 2: Build the signed production AAB**

Run the repository's established release AAB script, incrementing the version code if required by Play Console.

- [ ] **Step 3: Verify the artifact**

Confirm the command exits successfully, the AAB exists, its version code is newer than the live version, and the artifact contains the updated ad configuration.

### Task 4: Upload and stage the production release

**Files/External state:**
- Google Play Console production release for `com.farezagames.potionrogue`.

- [ ] **Step 1: Open the existing Play Console production release tab**

Use the logged-in browser tab and select the production track for Potion Rogue.

- [ ] **Step 2: Upload the new AAB and complete release notes/checks**

Upload only the newly verified AAB and retain the existing English release notes unless Play Console requires a new note.

- [ ] **Step 3: Stop immediately before the final Publish/Start rollout action**

Request the required action-time confirmation with the exact track, version, and artifact path.

- [ ] **Step 4: Publish after confirmation and verify the result**

Click the final production action only after confirmation, then verify Play Console's success state and release status.
