# Potion Rogue Expansion V6 Design

## Goal

Make the shipped build easy to understand on first launch, audibly alive, and substantially less repetitive across runs. Preserve the existing single-row potion board and premium dark-fantasy identity while expanding the encounter roster and improving information hierarchy.

## Tutorial

The first new run enters a deterministic guided encounter. A `TutorialDirector` owns ten explicit steps: battle goal, enemy vitality, intent preview, selecting a source flask, selecting a destination, undo, completing a potion, mana gain, active skill, and map path selection. Each step uses a dimmed overlay, spotlight rectangle, animated pointer, short Indonesian-friendly English copy, and a single clear action. Input outside the highlighted target is blocked when required.

The player may skip from every tutorial step. Completion and skip are persisted separately. Settings provides `REPLAY TUTORIAL`, which resets only tutorial progress and starts the guided encounter without resetting account progression. Tutorial state is saved at safe boundaries and never leaves the battle board locked after interruption.

## Music and Audio

Music must be immediately audible at the default 80% setting. The audio system exposes five perceptibly different layers: hall/explore, normal battle, elite, and three boss intensity phases. Existing ambience becomes a low bed rather than the whole soundtrack. Runtime-generated melodic and percussive stems add harmonic movement without requiring external licensed music.

The system preserves crossfades, avoids restarting the same layer, exposes a live preview button in Settings, and displays the active music state. Music uses conservative headroom and a minimum audible gain while respecting a true 0% mute.

## Procedural Runs

Every new run receives a high-resolution random seed and a reproducible graph of 12–15 nodes over seven floors and three lanes. The generator randomizes lane occupancy, links, encounter kind, enemy within threat tier, objective, compatible modifiers, rewards, and event IDs. It guarantees boss reachability, at least one safe route, no forced consecutive elites, no impossible objective/modifier pairing, and two choices on most floors.

Enemy stats scale from authored bases through the threat budget rather than mutating source data. The current seed is visible on the map and persisted for exact resume. A same-seed debug path reproduces the graph byte-for-byte; different seeds must show measurable roster and node-kind variation.

## Enemy Expansion

Add twenty enemies across four visual families and four tiers:

- Crypt: Bone Rat, Grave Archer, Wailing Spirit, Crypt Knight, Ossuary Priest.
- Fungal: Sporeling, Myconid Brute, Rotcap Shaman, Mossback Toad, Bloom Horror.
- Arcane: Rune Wisp, Mimic Flask, Clockwork Imp, Void Acolyte, Prism Sentinel.
- Infernal: Cinder Hound, Ash Harpy, Magma Beetle, Flame Wraith, Furnace Titan.

Four five-character sprite atlases provide consistent lighting, scale, ground contact, and transparent backgrounds. Atlas regions are data-driven, so Godot renders only the selected enemy. Each enemy receives stats, tier, intent pool, motion profile, reward value, and at least one gameplay identity through existing intent primitives. The original seven enemies remain available.

## GUI Upgrade

The redesign keeps the existing generated hall art and ornate motifs but reduces ornamental interference with live information. Battle gains a cleaner tutorial spotlight, compact intent/objective cards, stronger active/disabled button states, and stable spacing at 576×1280 and 720×1280. Map nodes gain enemy portrait thumbnails, clearer route states, seed display, and a compact legend. Settings gains aligned music preview and tutorial replay rows. Enemy atlas art uses consistent framing and shadow grounding.

All screens retain safe margins, 48px-equivalent touch targets, readable values, and Reduced Effects support. Screenshot QA covers hall, tutorial steps, map variants, normal battle, elite, boss, settings, and at least one enemy from each new family.

## Data and Interfaces

- `TutorialDirector`: configure, advance on named action, skip, replay, spotlight signal.
- `AudioManager`: `set_combat_layer`, `preview_music`, layer state, melodic/percussion stems.
- `RunGenerator.generate(seed)`: complete reproducible graph with encounter contracts and event IDs.
- Enemy records add `tier`, `family`, optional `atlas`, and `atlas_region`.
- `VisualRegistry.enemy` returns either a standalone sprite or an atlas region.
- `EnemyDisplay` accepts both without changing battle logic.

## Verification

Tests cover all tutorial transitions, skip/replay persistence, default music audibility, layer changes, graph invariants over 2,000 seeds, meaningful cross-seed variation, 27-enemy content count, every sprite/atlas region, all scene smoke tests, and responsive UI contracts. Final QA includes live screenshots, Android export, APK signature verification, merge, and push.
