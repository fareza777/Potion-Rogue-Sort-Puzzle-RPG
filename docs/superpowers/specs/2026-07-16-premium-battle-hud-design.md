# Premium Battle HUD Design

## Objective

Raise the battle and hall presentation from a functional prototype to a cohesive premium dungeon game UI, while retaining the existing monster artwork and gameplay behavior.

## Approved Direction

Use a premium hybrid treatment inspired by the supplied Play Store reference: dark obsidian surfaces, restrained gold ornament, saturated potion colors, layered status frames, and compact readable typography. Avoid adding ornament where it reduces clarity.

## Battle Composition

- Replace the single row of six tall tubes with a centered 3-by-2 formation.
- Keep each bottle near a 0.42 width-to-height ratio and preserve the source texture aspect; never stretch it to fill an arbitrary rectangle.
- Place the bottles on a subtle alchemy tray with a vignette, gold rim, selection glow, and enough separation for touch input.
- Keep the monster art as the main arena focal point.
- Group encounter title, enemy HP, countdown, player HP/shield, turn state, puzzle, and actions into clear vertical bands.

## HUD Components

- Enemy HP: dark framed track, ruby fill, inner highlight, skull marker, and centered numeric badge.
- Player HP: emerald framed track with heart marker; shield becomes a distinct blue badge instead of loose text.
- Encounter header: smaller stage kicker, larger monster name, and clearer currency capsule.
- Countdown: compact warning plaque that changes emphasis on the final move.
- Turn banner and instruction copy: stronger contrast and less visual competition.
- Action controls: retain the generated icons, add a subtle pedestal/glow, keep identical dimensions and baselines.

## Hall Composition

- Retain the dungeon background and slime artwork.
- Add a subtle hero halo and ambient particles so the center does not feel flat.
- Move CTA and navigation upward into a reliable safe area.
- Add three concise feature seals (Sort, Brew, Conquer) to echo the richer Play Store composition without crowding the screen.

## Motion

- Preserve reduced-effects support.
- Add bar-change shimmer, selected-bottle lift/glow, warning pulse, and restrained ambient particles.
- Motion must remain short and readable; no continuous animation may obstruct taps.

## Acceptance Criteria

- Device screenshots at 576x1280 show no clipped navigation or overlapping labels.
- Bottles read as short, wide potion vessels rather than stretched test tubes.
- Six bottles appear in a symmetrical 3-by-2 layout with touch targets of at least 84 pixels in the project design coordinate system.
- Enemy and player HP bars look framed and layered, with their values readable at phone size.
- Battle screen contains no large unintentional empty zone.
- Hall CTA and navigation remain above the bottom safe area.
- Logic and visual suites pass, Android export succeeds, and the APK is validated with `aapt`.

