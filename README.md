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

**Status: Phase 2+ — playable roguelike run.** Full 7-battle run (5 enemy types,
elite Stone Golem, boss Fire Golem with armor/tube-locks/enrage), 12 data-driven
upgrades, 4 potion combos, crystals with local save, styled dark-fantasy UI.
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
```

## Tech

- Godot 4.3+ / GDScript, GL Compatibility renderer
- 720x1280 base, portrait, responsive to all Android aspect ratios
- Fully offline, no accounts, no backend

Package name: `com.farezagames.potionrogue`
