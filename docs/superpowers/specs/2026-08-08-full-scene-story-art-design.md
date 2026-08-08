# Potion Rogue Full-Scene Story Art Expansion

**Date:** 2026-08-08  
**Status:** Approved by the user's explicit request for many premium generated story illustrations  
**Target:** Godot 4.7.1 portrait Android, fully offline

## Outcome

Replace the visible pattern of a reused dungeon background with an isolated bottle or enemy sprite with premium, full-frame narrative illustrations. Encounters and events open as short, tappable illustrated story panels; the final tap hands control to the existing battle or event workflow without changing run state.

## Approaches considered

### Chosen: authored full-scene illustration library with deterministic selection

Generate a coherent portrait art library for the five realms, representative enemy encounters, bosses, and recurring event families. A small manifest maps runtime context to compatible scenes. The run seed selects variants deterministically, while exact enemy/event identity remains in authored captions.

This is the best match for the user's request because every frame reads as one intentional painting, works offline, remains responsive, and can be compressed predictably for Android.

### Rejected: continue runtime sprite compositing

Compositing is compact and flexible, but it is the specific visual pattern the user rejected. It remains only as a missing-asset fallback.

### Rejected: fixed video cutscenes

Video can look polished but repeats identically, increases package and decode cost, and is harder to adapt to the current realm, node, enemy, and event.

## Visual direction

- High-end hand-painted dark-fantasy mobile RPG key art; cinematic, readable, and painterly rather than photorealistic.
- One coherent art bible: aged gold, deep violet, realm-specific accent light, tangible stone/glass/metal, atmospheric depth, and strong silhouette separation.
- Full portrait composition with the important action in the upper and middle field and a calm lower zone for the caption card.
- No generated text, logos, UI, borders, watermarks, duplicated anatomy, collage panels, or floating game elements.
- Scenes depict an action: entering, discovering, confronting, bargaining, surviving, or claiming a victory. They are not character cutouts on decorative backgrounds.

## Asset library

The first production set contains:

- Five realm-arrival paintings.
- Twenty encounter paintings: four representative threat tiers per realm, including each realm boss.
- Ten event paintings covering the primary event families and their follow-ups.

All final runtime assets are resized to 720 x 1280 and encoded as WebP. The total new source-art budget is capped at 14 MiB, preserving the existing 55 MiB project-art release gate.

## Runtime architecture

### `StoryArtCatalog`

Loads `data/story_art_manifest.json` and resolves a full-scene path from:

```text
trigger + area_id + enemy_id/event_id + enemy tier + run seed
```

Resolution order:

1. Exact enemy or exact event mapping.
2. Realm and tier mapping.
3. Realm default story painting.
4. Existing realm background with the current subject-compositing fallback.

The catalog validates every resource path and never blocks gameplay if content is missing.

### `StoryboardDirector`

Every composed beat receives:

- `art_mode: "full_scene"` when a compatible painting resolves.
- `background`: the resolved story illustration.
- `subjects: []` for full-scene art.
- `scene_key`: stable identity for replay/debugging.
- `focal_point`: optional normalized camera anchor.

Different trigger beats may use different crops and motion profiles, but the director avoids immediately repeating the same scene within a sequence when alternatives exist.

### `StoryboardPlayer`

Full-scene mode hides the subject and halo layers, applies a subtle safe-area gradient behind captions, and animates the painting itself with a bounded pan/zoom. Tap advances after the existing reading guard; hold Skip remains available. The final beat closes cleanly before battle/event input is enabled.

Reduced Effects uses a short crossfade without camera movement.

## Story flow

- `run_intro` / `realm_arrival`: realm establishment painting.
- `route_choice`: realm journey painting, never a pasted bottle.
- `battle_intro`: exact enemy painting when available, otherwise the matching realm/tier encounter painting. The player taps through it before battle begins.
- `event_reveal`: exact event-family painting before the choices appear.
- `event_resolution`: the same event family can use a consequence crop and color treatment without replaying an identical composition back-to-back.
- `battle_victory`, `battle_defeat`, `run_epilogue`: realm-compatible narrative painting with outcome motion and grading.

## Performance and failure behavior

- All images ship locally and are imported before export; no runtime image generation or network access.
- Story textures are loaded through the existing bounded resource cache.
- Only the active painting is visible; no 35-image preload.
- Invalid manifest entry falls through to the existing safe storyboard presentation.
- Interrupted playback never changes `RunState.phase` and never skips a battle checkpoint.

## Acceptance criteria

1. Every realm resolves arrival, early, advanced, elite, and boss-compatible full-scene art.
2. Every primary event resolves a full-scene art family.
3. `battle_intro` and `event_reveal` begin with `art_mode == "full_scene"` for valid content.
4. Full-scene playback hides isolated subject/halo layers and shows a loaded full portrait texture.
5. Identical context produces identical art; different valid contexts can produce a compatible variant.
6. Missing art never blocks map, event, or battle progression.
7. Captions remain readable at 576 x 1280, 720 x 1280, and 1080 x 2400.
8. New story art stays within the 14 MiB addition budget and the full art tree stays below 55 MiB.
9. The complete storyboard, gameplay integration, save recovery, viewport, and release tests pass.
10. A new Android debug APK is built and its package, version, signature, size, and SHA-256 are reported.

