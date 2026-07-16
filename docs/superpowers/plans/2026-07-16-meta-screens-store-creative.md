# Meta Screens and Store Creative Implementation Plan

**Goal:** Carry the premium dark-fantasy battle language through every player-facing screen and export a truthful Play Store creative from the finished game.

**Architecture:** Reuse the battle background, nine-slice panel, illustrated enemy art, Cinzel typography, and centralized `UiKit` factories. Keep gameplay/state code unchanged; this phase only changes presentation and screenshot tooling.

## Task 1: Shared ornate components

- Add visual contract tests for an illustrated menu hero, textured button, and map-node badge.
- Implement the reusable factories in `src/ui/ui_kit.gd`.
- Run `visual_test.tscn`.

## Task 2: Main menu and utility screens

- Recompose the main menu as a layered key-art screen with readable title hierarchy and an animated hero.
- Apply textured panels and consistent navigation to settings and credits.
- Capture and inspect screenshots.

## Task 3: Dungeon map and permanent upgrades

- Rebuild the map as an illustrated progression path with distinct battle, elite, and boss nodes.
- Restyle the permanent-upgrade shop as premium cards with stronger currency and level hierarchy.
- Capture and inspect screenshots.

## Task 4: Reward overlay and store creative

- Restyle battle reward/upgrade overlays with the illustrated panel system.
- Capture final menu, map, battle, boss, and shop screens.
- Compose a Play Store feature graphic only from real in-game captures and committed art.

## Task 5: Final verification

- Run logic and visual suites, scene smoke tests, `git diff --check`, and screenshot review.
- Update README/art pipeline status and commit the finished visual package.
