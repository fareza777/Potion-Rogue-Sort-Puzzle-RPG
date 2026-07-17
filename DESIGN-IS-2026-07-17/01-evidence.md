# Consolidated Evidence

## Structural evidence

- Main menu renders nine interactive controls and duplicates both Upgrades and Settings in the command stack and bottom navigation (`src/ui/main_menu.gd:51-85`).
- The procedural map renders 13–16 buttons but only two route choices are initially selectable (`src/run/run_generator.gd:13-35`; `src/ui/dungeon_route.gd:89-114`).
- Battle initially exposes eleven controls: six tubes plus Skill, Ultimate, Undo, New Mix, and Pause (`src/puzzle/puzzle_board.gd:16-18,43-50`; `src/ui/battle_screen.gd:410-478`).
- Primary scenes contain only a root Control; their full trees are constructed procedurally in large scripts (`scenes/main_menu.tscn:1-8`; `scenes/map.tscn:1-8`; `scenes/battle.tscn:1-8`).
- `RunState.start_new_run` has no area parameter, the generator fixes seven floors and Fire Golem, active-run serialization has no area, and completion deactivates the entire run (`src/autoload/run_state.gd:44-58,101-133,313-324`; `src/run/run_generator.gd:4,20-35`).
- Enemy selection ignores family metadata and scans all enemies by tier (`src/run/run_generator.gd:55-73`; `data/enemies.json:1-170`).
- Map and battle hard-code the Shadow Crypt background, boss UI special-cases Fire Golem, and audio exposes only dungeon/boss identities (`src/ui/map_screen.gd:12`; `src/ui/battle_screen.gd:124-131,239-242`; `src/autoload/audio_manager.gd:56-69,187-203`).

## Visual and accessibility evidence

- Primary screens use 127 literal color specifications and 22 font sizes; map detail reaches 9px (`src/ui/ui_kit.gd:7-18,217-254`; `src/ui/dungeon_route.gd:102-165`; `src/ui/main_menu.gd:36-38`; `src/ui/battle_screen.gd:269-498`).
- Fogged map heading contrast is approximately 2.62:1 at 11px; white HP text on the red bar is approximately 3.82:1 before outlines (`src/ui/dungeon_route.gd:102-165`; `src/ui/ui_kit.gd:7-18`).
- Loading and user-facing content-error states are absent; success and disabled states exist (`src/ui/battle_screen.gd:716-760`; `src/ui/visual_registry.gd:139-142`).
- Focus styles are inconsistent and no explicit focus graph or focus restoration exists (`src/ui/ui_kit.gd:120-166`; `src/ui/main_menu.gd:126-137`).
- PotionTube accepts only left-pointer input and potion identity is primarily color-coded (`src/puzzle/potion_tube.gd:11-16,41-52,178-205`).
- Reduced effects lowers FX intensity, but ambient particles still process/redraw and the route redraws at 25Hz (`src/ui/ambient_particles.gd:29-47`; `src/ui/dungeon_route.gd:37-45`; `src/ui/battle_fx.gd:15-24`).
- The fantasy language is coherent, but all gameplay/meta screens reuse the same crypt environment (`src/ui/map_screen.gd:12`; `src/ui/battle_screen.gd:239-242`; `src/ui/shop_screen.gd:11-12`; `src/ui/settings_screen.gd:9-10`).

## Copy and honesty evidence

- Continue and bottom Map silently create a default-kit run when none exists (`src/ui/main_menu.gd:60-62,84-85,168-187,210-213`).
- `HERO` opens Credits (`src/ui/main_menu.gd:78,168-187`; `src/ui/credits_screen.gd:31-42`).
- `BACK TO HALL` claims the run is saved, but battle completion does not save a boundary and no caller restores the saved active run (`src/ui/map_screen.gd:79-83`; `src/autoload/run_state.gd:101-134,313-324`).
- `Abandon Run` only returns to Hall and leaves the run active (`src/ui/battle_screen.gd:802-809,860-861`).
- Battle denominator uses the legacy static seven-battle list while procedural routes can contain noncombat nodes (`src/ui/battle_screen.gd:547-556,790-794`; `src/run/run_generator.gd:20-35`).
- Banked and run-only crystals are visually combined although events can spend only run crystals (`src/ui/map_screen.gd:121-123`; `src/run/event_resolver.gd:20-22`).
- Event buttons hide material HP/curse costs and expose internal failure codes (`data/events.json:4-7`; `src/ui/event_screen.gd:35-41`; `src/run/event_resolver.gd:9,19-35`).
- The HUD calls a non-required mana bonus an `OBJECTIVE`; brew-order does not display its required sequence (`src/battle/battle_manager.gd:343-355`; `src/ui/battle_screen.gd:113-152`; `data/objectives.json:12-16`).
- Armor-break objectives have no production progress caller (`src/battle/objective_controller.gd:59-61`; `src/run/run_generator.gd:94-100`).
- Kit copy promises distinct skills/ultimates, but all ultimates deal the same 38 damage; Flash Boil copy promises a queued double potion but deals immediate damage (`src/ui/kit_select_screen.gd:4-11,27-29`; `src/ui/battle_screen.gd:204-227`; `src/battle/skill_controller.gd:31-42`).
- Save data has no unlocked/completed area fields and boss victory offers only Main Menu (`src/autoload/save_system.gd:10-23`; `src/ui/battle_screen.gd:723-735`).

## Resource and friction evidence

- The v8 debug APK is 62,080,089 bytes. Compressed resource/assets are 32,984,454 bytes and native Godot libraries are 25,921,151 bytes (APK Zip inspection of `builds/PotionRogue-v8-debug.apk`).
- Enemy art is 35,138,057 source bytes. Four superseded atlases remain packaged because export uses `all_resources`, costing about 4.59MB compressed (`export_presets.cfg:9`; no runtime references found by `rg`).
- Windows headless startup-to-three-frames measured 3,187ms median across three runs; this is a desktop proxy, not Android TTI.
- There are zero network calls in the primary flow; the game uses local JSON, PNG, WAV, and generated audio (`src/autoload/game_state.gd:56-71`; `src/autoload/audio_manager.gd:137-301`).
- Audio synthesizes 12 SFX at startup, eagerly evaluates two fallback drones, and regenerates about 705KB PCM across two stems whenever a music layer changes (`src/autoload/audio_manager.gd:149-203,255-301`).
- Main-menu embers update/redraw 22 particles each frame, route pulse redraws at 25Hz, and enemy idle redraws every frame (`src/ui/ambient_particles.gd:10-47`; `src/ui/dungeon_route.gd:37-45`; `src/battle/enemy_display.gd:232`).
- Battle effects allocate temporary Polygon2D/Line2D objects; an ultimate may create three rings and 34 particles (`src/ui/battle_fx.gd:127-180`).

## Known gaps

- Store screenshots predate the latest fog-of-war map.
- No physical Android device, TalkBack, gamepad, localization expansion, or real GPU/CPU profiler capture was available during this audit.
- APK numbers describe a debug APK, not release AAB split download size.
- Contrast values are source-color estimates; texture, outline, transparency, and device brightness affect rendered results.
