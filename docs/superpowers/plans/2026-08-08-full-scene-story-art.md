# Full-Scene Story Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace pasted storyboard subjects with a deterministic, premium full-scene story-art library for realm arrivals, encounters, events, and outcomes.

**Architecture:** Add an offline manifest and focused `StoryArtCatalog`, let `StoryboardDirector` resolve compatible paintings, and teach `StoryboardPlayer` to render full-scene beats without the isolated subject layer. Existing composition remains a safe fallback.

**Tech Stack:** Godot 4.7.1, GDScript, JSON-authored mappings, built-in image generation, 720 x 1280 WebP assets, headless Godot tests, Android debug export.

## Global Constraints

- No runtime network or generated prose.
- Preserve authoritative run, event, and battle checkpoints.
- Full-scene art additions remain at or below 14 MiB; the complete art tree remains below 55 MiB.
- Every final image has no generated text, UI, watermark, or collage border.
- Every target screen supports 576 x 1280, 720 x 1280, and 1080 x 2400.
- Existing untracked review screenshots remain untouched.

---

### Task 1: Story-art contract and failing tests

**Files:**
- Create: `tests/story_art_catalog_test.gd`
- Create: `tests/story_art_catalog_test.tscn`
- Modify: `tests/storyboard_director_test.gd`
- Modify: `tests/storyboard_player_test.gd`

**Interfaces:**
- Expects `StoryArtCatalog.resolve(trigger: String, context: Dictionary) -> Dictionary`.
- Expects resolved beats to expose `art_mode`, `scene_key`, and `focal_point`.

- [ ] Add literal assertions for five complete realm mappings, primary event coverage, deterministic exact/tier fallback, and invalid-content fallthrough.
- [ ] Add director assertions requiring full-scene battle/event beats with no pasted subject.
- [ ] Add player assertions requiring hidden subject and halo layers during full-scene playback.
- [ ] Run all three test scenes and verify failure because the catalog, manifest, and player behavior do not exist.

### Task 2: Generate and validate the illustration library

**Files:**
- Create: `assets/art/story_scenes/*.webp`
- Create: `data/story_art_manifest.json`

**Interfaces:**
- Manifest produces `areas`, `enemies`, `events`, and `fallbacks` dictionaries using `res://` paths.

- [ ] Generate representative Shadow Crypt arrival, enemy, and event scenes with the shared premium art bible.
- [ ] Inspect the representative assets and make one targeted style correction if needed.
- [ ] Generate the remaining realm, encounter, boss, and event scenes with one prompt per asset.
- [ ] Inspect every output for coherent action, subject integrity, clean lower caption zone, and absence of generated text/UI.
- [ ] Resize/crop to 720 x 1280 WebP, remove metadata, and verify dimensions and aggregate size.
- [ ] Author exact enemy/event mappings and realm/tier fallbacks in the manifest.

### Task 3: Deterministic art resolution

**Files:**
- Create: `src/story/story_art_catalog.gd`
- Modify: `src/story/storyboard_director.gd`

**Interfaces:**
- `resolve` returns `{path, scene_key, focal_point}` or `{}`.
- `StoryboardDirector._compose_beat` converts a valid resolution to `art_mode: "full_scene"`, assigns the path to `background`, and clears `subjects`.

- [ ] Implement the smallest catalog needed to satisfy exact, tier, realm, and missing-resource behavior.
- [ ] Apply the resolution to every story trigger without altering context or run state.
- [ ] Run `story_art_catalog_test.tscn` and `storyboard_director_test.tscn`; verify green.
- [ ] Refactor duplicated manifest/path validation while keeping tests green.

### Task 4: Premium full-scene renderer

**Files:**
- Modify: `src/ui/storyboard_player.gd`
- Modify: `tests/storyboard_player_test.gd`

**Interfaces:**
- Player exposes `active_art_mode() -> String` and applies beat `focal_point` to bounded background motion.

- [ ] Implement full-scene mode so subject and halo are hidden and the illustration drives motion.
- [ ] Add a quiet lower readability gradient, cinematic top shade, restrained gold continuation affordance, and focal-point-aware pan/zoom.
- [ ] Preserve tap guard, hold Skip, Reduced Effects, cleanup, and current audio states.
- [ ] Run player, storyboard visual, gameplay integration, exact snapshot, and save recovery tests.

### Task 5: Mobile art and release verification

**Files:**
- Modify: `project.godot`
- Modify: `tests/release_budget_test.gd` if the versioned art budget requires a literal update.
- Create: representative captures under ignored review output only.

**Interfaces:**
- Android debug artifact uses version `1.6.4`, code `29`.

- [ ] Import all WebP textures headlessly and reject missing/corrupt imports.
- [ ] Capture representative arrival, early encounter, boss, and event panels at 576 x 1280 and inspect them.
- [ ] Run the complete core and visual test matrices plus release validation.
- [ ] Export `builds/PotionRogue-v1.6.4-debug.apk` and verify package, version, signature, size, and SHA-256.
- [ ] Commit, merge into `main`, and push the verified result without adding the user's untracked screenshots.

## Plan self-review

- Every approved requirement maps to a task and an observable test or visual gate.
- Runtime generation, video playback, and broad gameplay rewrites remain out of scope.
- Exact enemy/event mapping, realm/tier fallback, and safe missing-art fallback are explicit and type-consistent.
- Generated assets are validated before runtime integration and counted before release.

