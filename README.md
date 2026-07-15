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

**Status: Phase 1 — playable technical prototype** (one battle vs. Cave Slime).
See [docs/TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md) for architecture and roadmap.

## Running the game

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (Run Project).

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
