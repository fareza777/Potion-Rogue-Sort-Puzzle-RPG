# Potion Rogue: Sort Puzzle RPG

Sort potions, cast powerful spells, and conquer the dungeon.

A lightweight, offline, portrait Android game combining **water-sort puzzle**
mechanics with **turn-based battles** and **roguelike progression**. Every potion
tube you complete instantly fires its effect in battle — the enemy doesn't wait
for you to finish the puzzle.

- 🔴 Fire Potion — direct damage
- 🟢 Healing Potion — restore HP
- 🔵 Shield Potion — absorb attacks
- 🟣 Poison Potion — damage over time

**Status: Phase 4 — premium visual package complete.** Full 7-battle run (7 enemy encounters,
elite Stone Golem with relic reward, boss Fire Golem with armor/tube-locks/enrage),
15 data-driven upgrades, 3 relics, 4 potion combos, permanent upgrade shop
(8 crystal upgrades), interactive tutorial, synthesized placeholder audio with
volume/vibration settings, and corrupt-safe local save. The complete enemy roster,
battle animation/VFX, potion vessels, main menu, dungeon map, workshop, utility
screens, branded app icon, real screenshots, and Play Store feature graphic now
share the same authored dark-fantasy art direction. Remaining release engineering:
final audio production and Android signing/export configuration.
See [docs/TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md) for architecture and roadmap.

## Running the game

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (Run Project).

## Tests

Headless gameplay logic tests (battle rules, combos, armor, poison, board rules,
upgrades):

```
godot --headless --path . res://tests/logic_test.tscn
```

## Project layout

```
data/    JSON data definitions (potions, enemies, player) — no hardcoded stats in code
scenes/  Scene entry points (main menu, battle)
src/     GDScript source: autoload/, puzzle/, battle/, ui/
docs/    Technical design & roadmap
store-assets/  Play Store feature graphic, real screenshots, reproducible builders
```

## Tech

- Godot 4.3+ / GDScript, GL Compatibility renderer
- 720x1280 base, portrait, responsive to all Android aspect ratios
- Fully offline, no accounts, no backend

Package name: `com.farezagames.potionrogue`
