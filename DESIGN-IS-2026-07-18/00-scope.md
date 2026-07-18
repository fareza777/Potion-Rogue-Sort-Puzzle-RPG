# Scope

- Audited product: Potion Rogue Sort Puzzle RPG at commit `b1d318f` on `main`.
- Surfaces: Hall, expedition/map, battle, boss battle, settings, tutorial, rewards/events, progression, local persistence, procedural run generation, Android release pipeline.
- Primary user: a casual-to-midcore Android player who enjoys water-sort puzzles but wants roguelite build decisions and readable fantasy combat.
- Primary task: start or continue a run, choose a concealed route, solve potion boards, understand combat consequences, and grow a build across the run.
- Constraints: Godot 4.7.1, offline-first Android portrait UI, premium dark-fantasy/alchemy brand, touch-first controls, deterministic procedural runs, local save compatibility.
- Reference: the Play Store-style Potion Rogue / Dungeon Sort screenshots supplied by the user, especially their dense illustrated hierarchy, readable combat status, route map, and equipment/progression presentation.
- Evidence build: `builds/PotionRogue-v12-debug.apk` (64.2 MB); live captures at 576×1280 and 720×1280 under `C:/Users/FAJAR/AppData/Local/Temp/potion-v12/`.
- Audit type: full product audit covering engine, features, and user-facing visual design. This audit recommends changes; it does not implement them.
