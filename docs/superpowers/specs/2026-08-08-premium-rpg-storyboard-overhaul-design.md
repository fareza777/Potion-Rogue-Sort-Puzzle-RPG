# Potion Rogue Premium RPG Storyboard Overhaul

**Date:** 2026-08-08  
**Status:** Approved for implementation by the user's explicit “kerjakan semua” direction  
**Target:** Godot 4.x portrait Android build, fully offline

## Purpose

Raise Potion Rogue from a visually strong puzzle prototype into a cohesive premium RPG. The work preserves the deterministic puzzle, save, content, and campaign foundations while rebuilding the parts that currently feel generic, crowded, slow, or disconnected.

The signature addition is a deterministic **Cinematic Storyboard Director**. It assembles authored shot grammar from the current run state so every expedition has visual continuity without requiring cloud AI, pre-rendered video, or a large unique cutscene for every permutation.

## Product principles

1. The potion board remains the primary interaction and is never blocked by decorative guidance during normal play.
2. Information needed for the next decision is readable in one glance.
3. Illustration is the figure; ornate chrome is supporting structure.
4. Procedural systems select from authored, art-directed building blocks rather than generating arbitrary copy or layouts.
5. Every random result is deterministic from the run seed and node identity.
6. Existing saves migrate safely; an interrupted cinematic resumes at the underlying safe map or battle checkpoint.
7. Cinematics are skippable, respect Reduced Effects, and never conceal a purchase or mechanical cost.
8. All gameplay remains offline.

## Chosen approach

### Recommended: authored shot grammar with deterministic runtime assembly

Each story trigger produces a short sequence of `StoryboardBeat` dictionaries. A beat chooses a background, subject art, composition, caption, accent, camera motion, transition, ambience, and duration from a constrained authored catalog. The director uses the run seed, area, kit, node, enemy, HP state, battle result, and previous story tags to select compatible beats.

This provides variety while retaining deliberate composition. It also reuses realm backgrounds, enemy sprites, UI ornaments, and kit identities already in the package.

### Rejected: fixed pre-rendered videos

Videos offer strong control but repeat identically, increase package size, complicate aspect ratios, and cannot react to the current build or battle state.

### Rejected: fully simulated cutscenes

Freeform scene simulation would require character rigs, navigation, camera staging, and a large animation pipeline. It is disproportionate to a portrait puzzle RPG and would dilute polish.

## Workstreams

### 1. Engine stability and measurable performance

- New Mix must show feedback immediately and perform both integrity analysis and remix generation away from the render thread.
- The common two-, three-, and four-color states use verified catalogs or cached results before bounded search.
- Only the newest remix generation may apply; timeout restores the exact board and re-enables input.
- Battle presentation is progressively extracted from `battle_screen.gd` into focused coordinators without changing battle rules.
- Resource lifetime is explicit for remix jobs, cinematic tweens, audio players, and transient FX.
- Release validation distinguishes debug APK, release APK, and AAB artifacts and reports package composition.
- Mobile instrumentation records input acknowledgement, remix completion, scene-transition duration, frame p95, active FX, and texture/audio cache sizes during development builds.

### 2. Visual system and information hierarchy

- `UiThemeTokens` becomes the authoritative spacing, type, motion, contrast, and ornament system.
- Cinzel remains for display titles and major actions. Body, captions, and dense tactical readouts use the readable body font.
- Small type has a 14 px base at 720-wide design resolution; narrative body uses 17–18 px; key battle values use tabular treatment and high contrast.
- Ornate full frames are reserved for major screen boundaries, victory choices, and story title cards. Repeated rows use quiet inset surfaces.
- Formula Codex uses jewel sockets, formula silhouettes, category grouping, discovery progress, and meaningful locked states instead of black rectangles.
- Guide uses swipeable section tabs with edge cues, shorter paragraphs, interactive diagrams, and direct links to formula details.
- Battle HUD becomes three readable layers: expedition identity, enemy/player state, and one tactical strip for objective, intent, counter, mana, and reaction readiness.
- Skill buttons always explain cost, cooldown, and disabled reason.
- Map and area-selection content can be dragged anywhere inside their scroll surface and never begins with partially clipped nodes.
- Campaign purchase remains transparent but becomes a compact secondary card after the free realm is understood.

### 3. Gameplay depth

- Multi-wave encounters draw deterministic wave rosters from the realm pool. Later waves can change enemy identity, signature, intent package, and presentation rather than only scaling the same enemy.
- Encounter formations support `solo`, `reinforcement`, and `duo_pressure`. The initial implementation keeps one active target at a time so the potion rules remain stable; queued enemies are visible and alter intent timing.
- Events gain deterministic chains. A choice can set a run flag, unlock a later follow-up, change a future encounter modifier, or resolve through a kit/relic/formula condition.
- Every event choice previews its exact immediate cost and its known future consequence without revealing hidden story outcomes.
- Permanent progression shifts toward horizontal mastery: starting catalyst choice, formula discipline, scout token, one tactical mulligan, and kit talent variants. Raw damage upgrades remain but are no longer the only meaningful progression.
- Daily and Weekly modes remain fair by disabling permanent horizontal power that would invalidate comparable seeds.

### 4. Cinematic Storyboard Director

#### Triggers

- `run_intro`: after kit selection, before the first map.
- `realm_arrival`: first entrance into a realm for the current run.
- `route_choice`: optional one-beat foreshadowing after selecting a mystery path.
- `event_reveal`: when an event screen opens.
- `event_resolution`: after a choice, reflecting the actual mechanical result.
- `battle_intro`: before normal, elite, and boss encounters.
- `battle_escalation`: first enemy signature, low HP, new wave, or boss phase.
- `battle_victory` and `battle_defeat`.
- `run_epilogue`: boss clear, first-clear unlock, Ascension clear, or campaign completion.

#### Beat schema

Each beat contains:

```gdscript
{
    "id": "crypt_gate_reveal",
    "layout": "subject_right",
    "background": "res://assets/art/backgrounds/shadow_crypt_battle_v2.png",
    "subjects": [{"texture": "enemy:crypt_knight", "slot": "right", "scale": 0.86}],
    "eyebrow": "SHADOW CRYPT · DEPTH II",
    "title": "IRON REMEMBERS",
    "body": "A mailed guardian steps between the brewer and the lower vault.",
    "accent": "9f6bd2",
    "motion": "slow_push",
    "transition": "ink_wipe",
    "music_state": "battle",
    "duration": 2.8
}
```

#### Shot grammar

- Establishing shots contain no large character and favor a slow push through realm art.
- Reveal shots use one dominant subject, strong silhouette separation, and a short title.
- Decision shots place opposing consequences on different sides and keep the choice controls below the image.
- Escalation shots last under 1.6 seconds and never interrupt an active bottle pour.
- Victory shots move upward and brighten; defeat shots compress inward and desaturate.
- A sequence cannot repeat the same layout or transition twice in succession.
- Captions are authored templates with bounded substitutions; there is no freeform procedural prose.

#### Continuity

The director receives `story_tags` such as `wounded`, `curse_bound`, `formula_master`, `elite_hunter`, `first_clear`, and event-chain flags. It selects copy and subjects compatible with those tags. It records only compact beat IDs in the replay journal. Save files do not persist animation time.

#### Presentation

- 2.5D parallax uses background, atmospheric veil, subject, foreground ornament, and text layers.
- Motion uses transforms and opacity only.
- Standard transitions: `ink_wipe`, `ember_bloom`, `frost_shard`, `verdant_spore`, `astral_prism`, and `abyssal_tide`.
- Reduced Effects replaces camera movement and flashes with short crossfades.
- Tap advances after the minimum reading delay; hold Skip bypasses the remaining sequence.
- Story playback never takes control of the puzzle board mid-pour.

## Error and fallback behavior

- Missing storyboard texture: omit that subject and retain the caption card.
- Missing catalog entry: return an empty sequence and continue the gameplay transition immediately.
- Invalid enemy or area ID: use the active area's background and no subject.
- Storyboard already playing: queue one critical trigger; discard duplicate ambient triggers.
- Scene changes or application pause: cancel tweens, free transient controls, and leave the underlying checkpoint untouched.
- Remix worker timeout: restore snapshot, enable input, show a specific recovery message, and use a verified catalog on the next request.

## Accessibility and localization

- All new copy is addressed through stable story/copy keys even while English remains the initial shipped language.
- Indonesian is the first additional locale.
- Text scaling up to 130% preserves all primary actions.
- High Contrast applies to captions, intent text, formula sockets, and focus outlines.
- Potion sigils remain optional and default off.
- Cinematics provide tap-to-advance and skip; no essential mechanic is explained only through animation.

## Verification and acceptance

1. New Mix acknowledges input within one rendered frame and never runs the 50,000-state solver on the UI thread.
2. Exact battle snapshot recovery still passes after remix, story playback, wave changes, pause, and application restart.
3. Formula Codex has no black rectangular placeholders and no text/frame intersections at 576×1280, 720×1280, or 1080×2400.
4. Every primary screen passes the mobile layout audit and a real screenshot comparison.
5. A multi-wave encounter can present at least two distinct enemies from the correct realm pool.
6. At least five event families have a deterministic follow-up consequence.
7. At least five horizontal mastery unlocks alter decisions without directly multiplying damage.
8. Storyboard sequences are deterministic for identical context and vary for different node seeds.
9. All ten storyboard triggers degrade safely to immediate gameplay continuation.
10. Reduced Effects and Skip remove motion without changing game state.
11. No new external runtime dependency or network requirement is introduced.
12. Release validation reports the current AAB separately from stale debug APKs.

## Scope boundaries

- No 3D character rigs.
- No cloud narrative generation.
- No voice acting in this pass.
- No simultaneous free-targeting combat rewrite; queued formations preserve the existing potion interaction model.
- No replacement of approved monster or realm illustrations unless a visual defect is proven in capture.
