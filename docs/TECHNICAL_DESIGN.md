# Potion Rogue: Sort Puzzle RPG — Technical Design

## Engine

**Godot 4.3+ (GDScript, GL Compatibility renderer)**

Why Godot:
- Free, open source, no royalties — ideal for a solo dev shipping to Play Store.
- One-click Android export, small APK (~30–40 MB), runs well on low-end devices.
- Node/scene system fits a portrait UI-heavy game.
- Fully offline; no backend needed.
- JSON/Resource-based data loading fits the data-driven design (enemies, potions, upgrades).

Trade-offs: smaller ads/IAP plugin ecosystem than Unity (community AdMob plugin exists;
only relevant in the monetization phase).

## Display

- Base resolution 720x1280 (9:16), portrait-locked.
- Stretch mode `canvas_items` + aspect `expand`: UI scales cleanly on any Android
  aspect ratio; top/bottom margins keep content clear of notch and nav bar.
- GL Compatibility renderer for maximum device coverage.

## Architecture

Strict separation between **logic**, **presentation**, and **data**:

```
data/ (JSON)          src/ (logic + UI)                 scenes/ (entry points)
  potions.json   -->    autoload/game_state.gd    <--     main_menu.tscn
  enemies.json          puzzle/potion_tube.gd             battle.tscn
  player.json           puzzle/puzzle_board.gd
                        battle/battle_manager.gd
                        battle/enemy_display.gd
                        ui/battle_screen.gd
                        ui/main_menu.gd
```

- **GameState (autoload)** — loads all JSON data with hardcoded fallbacks (a corrupt
  data file can never crash the game). Later: run state, crystals, permanent
  upgrades, save/load.
- **PuzzleBoard / PotionTube** — pure water-sort logic + procedural placeholder
  rendering. Knows nothing about battles; communicates via signals
  (`move_made`, `tube_completed(color)`, `board_refilled`).
- **BattleManager** — pure battle logic (HP, shield, poison, enemy turn cadence).
  No UI code; emits signals (`stats_changed`, `enemy_attacked`, `battle_won`, ...).
- **BattleScreen** — the only place that wires puzzle to battle and renders both.
  All UI is built in code for the placeholder phase; will migrate to themed
  scenes/sprites in the polish phase without touching logic.

Signal flow:

```
PuzzleBoard.move_made        -> BattleManager.on_move()        (enemy counter -1)
PuzzleBoard.tube_completed   -> BattleManager.on_potion_completed(color)
BattleManager.stats_changed  -> BattleScreen._refresh()
BattleManager.battle_won/lost-> BattleScreen overlays
```

## Core rules (Phase 1)

- 6 tubes: 4 filled + 2 empty; capacity 4 units; 4 colors, exactly 4 units each.
- Pour: tap source, tap target; allowed if target is empty or top colors match;
  moves the whole top run (as much as fits). Invalid target re-selects instead.
- A full single-color tube = potion completed: effect fires immediately, tube
  empties. Because each color has exactly 4 units, completing all colors empties
  the board -> a fresh board is generated ("New potions brewed!").
- Every pour = 1 move. Enemy attacks when its move counter hits 0, then the
  counter resets. Poison ticks before the enemy attack (can kill first).
- Shield absorbs damage before HP. Shield cap 30. Poison re-application
  refreshes duration (no stacking) — MVP simplification.
- Undo: 3 per battle, reverts the last pour and refunds the move counter.
  History clears when a potion completes (effects can't be taken back).
- "New Mix" reshuffles the board (free; revisit if abused).

Baseline numbers (all in `data/*.json`): Player 50 HP / shield cap 30 / 3 undos.
Slime 60 HP, 8 attack, attacks every 3 moves. Red 20 dmg, Green +15 HP,
Blue +12 shield, Purple 5 dmg x 3 turns.

## Roadmap

- **Phase 1 — Technical prototype: DONE.** One playable battle; 4 potion effects,
  enemy turn cadence, undo/restart/pause, victory/defeat.
- **Phase 2 — Core roguelike: DONE.** 7-battle run (map screen, HP carry-over),
  3-choice upgrade screen, data-driven upgrades (RunState.stat modifier pipeline),
  game over with partial crystal reward, persistent crystals (user://save.json,
  versioned, corrupt-file fallback).
- **Phase 3 — Content MVP: DONE.** 6 enemies + Fire Golem boss (armor, crit,
  player-poison, tube locking, enrage), 15 upgrades, 3 relics (elite reward),
  4 combos (Fire Burst, Shield Bash, Toxic Flame, Regeneration Guard), Last
  Remedy trigger, permanent upgrade shop (8 crystal upgrades, scaling costs),
  interactive event-driven tutorial (first battle, saved flag), synthesized
  placeholder SFX/music (AudioManager, no asset files) with Music/SFX buses,
  settings screen (volumes, vibration, reset progress), credits, headless logic
  tests — 30 checks (tests/logic_test.tscn).
- **Phase 4 — Polish: NEXT.** Real art (sprites for enemies/tubes/panels — the
  drawing code is isolated in EnemyDisplay/PotionTube/UiKit), real audio (swap
  streams in AudioManager._build_sounds), particles/animations, haptics tuning,
  performance pass, Android export template + signing, Play Store assets.

Additional systems since Phase 1:
- **RunState (autoload):** run progress, upgrade modifiers (`stat(name, base)`),
  crystal accounting. **SaveSystem (autoload):** persistent save. **DevTools
  (autoload):** CLI screenshot capture + battle-index override for testing.
- **UiKit:** single source of visual truth (colors, Cinzel font, styled panels/
  buttons/bars, floating combat text, shader background).
- Enemy abilities are plain JSON fields: `armor`, `crit_chance`,
  `lock_every_attacks`, `poison_player`, `enrage`.

## App identity

- Name: Potion Rogue: Sort Puzzle RPG (short: Potion Rogue)
- Package: `com.farezagames.potionrogue`
- Tagline: Sort potions, cast powerful spells, and conquer the dungeon.
