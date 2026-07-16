# Single-Row Potions and Hall Art Design

## Objective

Correct the potion-board composition and raise the main hall art quality without changing gameplay or the approved monster sprites.

## Approved Direction

- Six potion bottles appear in one centered horizontal row.
- Bottles are visibly larger than the current 3-by-2 version while remaining proportional and fully tappable.
- Remove the rectangular Alchemy Table panel, title, purple border, and boxed backdrop.
- Use only an understated shelf line, individual bottle shadows, and selection glows behind the row.
- Preserve the framed vitality HUD and combat motion unless screenshot QA exposes a regression.
- Generate a new portrait dungeon-hall background exclusively for the main menu. It contains no text, logo, character, UI, or watermark; the existing slime remains a separate foreground hero.
- Use existing ornamental assets and code-native accents for small frames so their geometry remains deterministic and readable.

## Main Hall Art Direction

The new background is a premium dark-fantasy alchemy dungeon: vaulted stone architecture, a blue portal centered deep in the corridor, warm amber braziers at the sides, subtle purple crystals, and a richer carved foreground platform. The center must remain readable behind the green slime, with quieter negative space at the top for the title and at the bottom for the CTA.

## Acceptance Criteria

- `PuzzleBoard.layout_columns()` returns `6` and all six bottles occupy one row.
- The board source has a named `PotionShelf` and no `AlchemyTray`.
- Bottle display size is at least 96 pixels wide in the tall profile and preserves a visually compact aspect ratio.
- No rectangular board panel appears behind the bottles.
- Main menu loads a new project-owned generated background asset.
- Screenshots show no bottle/action overlap, clipped navigation, or unreadable HUD labels.
- Logic and visual tests pass and Android APK v4 validates with `aapt`.

