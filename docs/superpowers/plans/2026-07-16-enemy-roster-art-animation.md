# Enemy Roster Art and Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace procedural presentation for Skeleton, Poison Beast, Stone Golem, Dark Mage, Blood Slime, and Fire Golem with original production sprites and character-specific motion while preserving battle logic.

**Architecture:** Extend the existing `VisualRegistry` with sprite paths and motion profiles. Continue using the normalized `EnemyDisplay` interface and procedural fallback. Use one clean hero sprite per enemy plus the shared soft ground-shadow system; animation comes from profile-specific transforms, shader states, and `BattleFx`, so gameplay signals remain authoritative.

**Tech Stack:** Godot 4.7.1 compatibility renderer, GDScript, PNG alpha cutouts, existing enemy shader/tweens, built-in image generation, headless visual and logic tests.

## Global Constraints

- Preserve all battle JSON values and `BattleManager` behavior.
- Reuse the Cave Slime environment, UI, potion, and lighting system.
- Every enemy must remain readable at phone size and use the same warm-left/cool-right light direction.
- Enemy animation never mutates HP, armor, poison, locks, turn order, or rewards.
- Keep procedural fallback functional when an asset is missing.
- Target the existing normal/reduced-effects budgets.

---

### Task 1: Require Complete Roster Mappings

**Files:**
- Modify: `tests/visual_test.gd`
- Modify: `src/ui/visual_registry.gd`

**Interfaces:**
- Consumes: all keys in `GameState.enemies`.
- Produces: a non-empty loadable `sprite` path and `motion_profile` for every enemy ID.

- [ ] Add a visual test loop that checks `sprite` is non-empty, `motion_profile` is one of `elastic`, `brittle`, `pounce`, `heavy`, `caster`, or `inferno`, and `ResourceLoader.exists(sprite)` is true.
- [ ] Run the visual suite and verify six enemy entries fail for missing production sprites.
- [ ] Add the intended runtime paths and profiles to `VisualRegistry`; paths remain failing until assets are produced.

Exact mappings:

```gdscript
"slime": {"motion_profile": "elastic"},
"skeleton": {"sprite": "res://assets/art/enemies/skeleton/skeleton.png", "motion_profile": "brittle"},
"poison_beast": {"sprite": "res://assets/art/enemies/poison_beast/poison_beast.png", "motion_profile": "pounce"},
"stone_golem": {"sprite": "res://assets/art/enemies/stone_golem/stone_golem.png", "motion_profile": "heavy"},
"dark_mage": {"sprite": "res://assets/art/enemies/dark_mage/dark_mage.png", "motion_profile": "caster"},
"blood_slime": {"sprite": "res://assets/art/enemies/blood_slime/blood_slime.png", "motion_profile": "elastic"},
"fire_golem": {"sprite": "res://assets/art/enemies/fire_golem/fire_golem.png", "motion_profile": "inferno"},
```

---

### Task 2: Produce and Clean Six Enemy Cutouts

**Files:**
- Create: `assets/art/enemies/skeleton/skeleton.png`
- Create: `assets/art/enemies/poison_beast/poison_beast.png`
- Create: `assets/art/enemies/stone_golem/stone_golem.png`
- Create: `assets/art/enemies/dark_mage/dark_mage.png`
- Create: `assets/art/enemies/blood_slime/blood_slime.png`
- Create: `assets/art/enemies/fire_golem/fire_golem.png`

**Interfaces:**
- Consumes: approved battle concept, `docs/ART_PIPELINE.md`, exact registry paths.
- Produces: one alpha-clean production cutout per remaining enemy.

- [ ] Generate each enemy separately using the approved Cave Slime sprite as rendering and lighting reference. Use a flat `#ff00ff` key for Skeleton, Stone Golem, and Fire Golem. Use `#00ff00` for Poison Beast, Dark Mage, and Blood Slime.
- [ ] Require a complete centered silhouette, generous padding, no floor, no shadow, no detached particles, no UI, no text, and no watermark.
- [ ] Preserve these identities:
  - Skeleton: crooked armored dungeon skeleton, loose jaw, red-orange eye sparks, chipped sword, brittle readable limbs.
  - Poison Beast: hunched violet cave predator, feline/batlike silhouette, toxic saliva, fast forward posture.
  - Stone Golem: squat massive segmented rock guardian, blue runes, oversized fists, dusty weight.
  - Dark Mage: floating hooded caster, layered dark cloth, visible glowing eyes and hands, restrained violet glyph focus.
  - Blood Slime: dense crimson translucent slime, sharper aggressive face, internal bubbles, distinct from green slime.
  - Fire Golem: boss-scale magma-cracked stone titan, orange core, armored shoulders, large readable head and fists.
- [ ] Copy keyed sources to `tmp/imagegen`, remove their background using the documented `remove_chroma_key.py` command, and write only cleaned PNGs under `assets/art`.
- [ ] Inspect every output at original resolution for transparent corners, complete silhouette, consistent lighting, no key fringe, and no accidental text.
- [ ] Import resources with Godot editor headless and run visual tests until all roster paths load.
- [ ] Commit all six approved sprites and registry coverage.

---

### Task 3: Profile-Specific Motion

**Files:**
- Modify: `src/battle/enemy_display.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: `motion_profile` from `VisualRegistry.enemy(enemy_id)`.
- Produces: `motion_profile() -> String` and differentiated intro, idle, anticipate, attack, hit, and defeat transforms.

- [ ] Add failing tests that configure each enemy and verify `uses_sprite_art()` plus the expected `motion_profile()`.
- [ ] Store the profile during `configure_enemy`.
- [ ] Apply these motion rules:
  - `elastic`: squash/stretch and soft bounce.
  - `brittle`: short angular rotation, jawlike snap rhythm, sharp small shake.
  - `pounce`: low anticipation, forward/upward lunge, fast recovery.
  - `heavy`: slow settle, small idle amplitude, deep compression, strong recovery.
  - `caster`: vertical hover, slight rotation, slow anticipation, quick spell recoil.
  - `inferno`: heavy base plus stronger enrage pulse and longer boss intro.
- [ ] Keep normalized public method names unchanged.
- [ ] Run visual and logic suites; confirm no profile changes battle state.
- [ ] Commit motion-profile support.

---

### Task 4: Roster Screenshot Gate

**Files:**
- Modify: `docs/ART_PIPELINE.md` only if a new reusable rule is discovered.

**Interfaces:**
- Consumes: all roster art and motion profiles.
- Produces: local standardized screenshot evidence for battle indices 0 through 6.

- [ ] Capture each battle index with a four-second delay using `DevTools --battle-index=N`.
- [ ] Inspect every screenshot for scale, grounding, alpha, name/HP readability, armor/status overlap, and safe-area clipping.
- [ ] Correct registry scale values rather than editing individual screen layout.
- [ ] Run fresh `logic_test.tscn`, `visual_test.tscn`, `git diff --check`, and `git status --short`.
- [ ] Commit final registry scale corrections and any art-pipeline documentation update.
