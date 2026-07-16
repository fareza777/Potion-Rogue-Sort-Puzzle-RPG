# Potion Rogue Art Pipeline

This document defines the production rules for runtime art. The Cave Slime battle is the quality benchmark for every later enemy and screen.

## Runtime Layout

```text
assets/art/
  backgrounds/          portrait environment plates
  enemies/<enemy_id>/   enemy body, shadow, and later animation layers
  potions/              reusable vessel frames
  ui/                    scalable frames and action icons
assets/shaders/          presentation-only CanvasItem shaders
```

Generated sources, keyed intermediates, rejected variants, and contact sheets do not belong under `assets/`. Only approved and cleaned runtime files are committed.

## Visual Bible

- Primary environment: charcoal stone and deep indigo shadow.
- Primary light: warm torchlight from the upper-left or both side walls.
- Secondary light: cool blue-violet rim light from dungeon magic.
- UI material: dark carved stone or stained wood with aged bronze and muted gold.
- Gameplay color: saturated jewel tones are reserved for potion liquids and combat effects.
- Enemy style: expressive, readable, hand-painted 2.5D fantasy; broad mobile silhouette; no photorealism.
- Texture: soot, scratches, glass reflections, liquid bubbles, restrained grain.
- Avoid flat rounded rectangles, generic vector icons, uniform purple gradients, tiny labels, and unrelated light directions.

## Asset Naming

- Use lowercase snake case.
- Enemy paths match JSON IDs: `assets/art/enemies/<enemy_id>/...`.
- Use semantic roles: `cave_slime.png`, `cave_slime_shadow.png`, `button_round.png`.
- Do not encode draft numbers in runtime names. Draft history remains outside the project.

## Image Generation

Use the approved Cave Slime battle concept as a quality and lighting reference, not as an edit target. Prompts must state the runtime role, required camera/framing, lighting direction, palette, and negative constraints. Every asset must be original and contain no watermark, text, trademark, or unrelated object unless the asset specification explicitly requires text.

Environment plates are generated as empty 9:16 scenes with a protected character focal area and a darker puzzle region. Enemy and UI cutouts use a perfectly flat chroma-key background chosen to avoid the subject palette.

For green subjects, use `#ff00ff`. For subjects containing magenta, use `#00ff00`.

## Alpha Cleanup

Store keyed sources outside runtime directories, then run:

```powershell
python 'C:\Users\FAJAR\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py' `
  --input tmp\imagegen\source_key.png `
  --out assets\art\target.png `
  --auto-key border `
  --soft-matte `
  --transparent-threshold 12 `
  --opaque-threshold 220 `
  --despill `
  --edge-contract 1
```

Inspect the output at original resolution. Transparent corners, clean antialiasing, complete silhouettes, and absence of key-color fringe are required. Do not commit the keyed source.

## Godot Import

Import new resources before running presentation tests:

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit
```

UI and enemy cutouts must preserve alpha. Avoid lossy compression when it creates edge halos. Large opaque backgrounds may be converted to WebP after side-by-side inspection; the Cave Slime benchmark currently keeps its source PNG to preserve the approved plate exactly.

`VisualRegistry` is the only mapping between gameplay IDs and optional art paths. A missing texture returns `null`, and presentation nodes must use their procedural fallback.

## Animation Contract

Every enemy presentation supports:

- `play_intro()`
- `play_anticipate()`
- `play_attack()`
- `play_hit()`
- `play_defeat()`
- the `enraged` property when applicable

Animation and VFX never mutate HP, damage, board state, rewards, or turn order. Battle signals drive presentation after the authoritative state change.

Normal hit shake is capped at 8 pixels. Reduced-effects mode caps it at 3 pixels and lowers particle counts. Full-screen time scaling is forbidden; it would couple presentation to gameplay timing.

## Battle Screenshot Commands

From a checkout that contains the local Godot binary:

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' `
  --path . res://scenes/battle.tscn -- `
  --screenshot='.tools\shots\battle-benchmark.png' --delay=4
```

Use a delay of at least four seconds after a new import so shader compilation and the intro tween have settled. A two-second first capture can contain transient driver artifacts on the compatibility renderer.

## Verification

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/logic_test.tscn
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/visual_test.tscn
```

Before accepting an asset or screen, verify:

- All tests exit zero.
- Enemy and UI alpha edges are clean.
- Four liquid units remain distinguishable.
- Enemy HP, player HP, countdown, and action counts are readable at phone size.
- Nine-slice corners do not stretch.
- Nothing crosses the safe areas.
- Fallback rendering remains usable when an optional registered sprite is missing.
- A 60-second idle does not continually add nodes.

## Play Store Rule

Marketing screenshots must be captured from implemented scenes. External captions and device framing may be added, but screenshots must not invent unimplemented equipment, progression, or combat systems. The committed `store-assets/` package follows this rule and can be rebuilt with its PowerShell compositors.
