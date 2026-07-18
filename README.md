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

**Status: v1.0 campaign and systems overhaul complete.** Three procedural realms,
27 tiered enemies, distinct kit skills/ultimates, transparent event trade-offs,
Daily Challenge, boss rematches, mastery rewards, run history, an interactive
tutorial, layered ambient battle music, accessible potion patterns, and exact
mid-battle Save & Exit are implemented. Continue restores the same enemy, HP,
turn countdown, potion layout, hazards, mana, objective, and boss phase. The Hall,
battle actions, route map, settings, workshop, and replay screens share one
responsive dark-fantasy UI and support standard/tall portrait Android devices.
See [docs/TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md) for architecture and roadmap.

## Running the game

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (Run Project).

## Tests

Run any focused headless suite, or execute every `tests/*_test.tscn` scene for the
full regression matrix (gameplay, generation, save migration, UI, audio, and release budgets):

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
