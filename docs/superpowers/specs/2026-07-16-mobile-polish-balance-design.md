# Potion Rogue Mobile Polish and Balance Design

## Goal

Make every screen feel intentionally composed on real portrait phones, replace weak utility presentation, deepen battle feedback, add original dark-fantasy ambience, and make the opening battle welcoming. Preserve existing puzzle rules, run structure, rewards, and saved progression.

## Supported Layouts

The UI must remain readable and visually dense at 16:9, 19.5:9, 20:9, and 22:9. The 576×1280 device capture is the tall-phone acceptance target. Screens use proportional vertical bands and expandable content, not a centered fixed-height stack.

Safe margins protect display cutouts and navigation bars. Decorative backgrounds may bleed to every edge; interactive controls stay within the safe content region.

## Main Menu

The screen is divided into title, hero, pitch, primary action, utilities, and currency bands. Extra height expands the hero and atmosphere rather than collecting below the buttons. The primary action remains visually dominant. Utility controls use equal widths and aligned baselines.

## Dungeon Map

Replace the large framed text list with an illustrated route. Each encounter is a medallion containing its registered enemy portrait. A glowing path links nodes, alternating laterally to create depth. Nodes show distinct current, cleared, locked, elite, and boss states. The current node pulses subtly; the boss node is larger and warmer. Status and enter controls remain pinned to the lower safe region.

## Battle Layout

Use four responsive vertical regions: arena, combat status, potion board, and action bar. Tall screens enlarge the arena and potion board within bounded ratios. They do not create an empty spacer. Potion tubes stay large enough for four liquid units to remain legible.

Improve feedback with enemy breathing, anticipation silhouettes, attack lunges, projectile trails, elemental impact layers, HP damage interpolation, status pulses, subtle arena lighting, button press depth, and bounded camera shake. Reduced-effects mode continues to cap motion and particle counts.

## Supporting Icon Set

Create a coherent transparent PNG set for Undo, Mix, Pause, Music, Sound, and Vibration. Every icon uses the same obsidian, antique-gold, and warm-highlight treatment, identical optical center, consistent stroke weight, and safe padding. Buttons place icons independently from counters and captions so visual centering is stable.

## Settings and Utility Screens

Settings uses three icon-led rows. Music and SFX rows contain aligned labels, sliders, and live value percentages. Vibration uses the same row geometry. Reset remains visually separated as a destructive action. Other utility screens adopt the same responsive panel sizing and safe-area behavior.

## Audio

Ship original offline ambient loops rather than the current minimal drone. The dungeon loop combines low drones, sparse crystal bells, filtered noise, and a restrained pulse. The boss loop uses a stronger rhythmic bed and darker harmony. Loops must be seamless, avoid clipping, and remain beneath feedback sounds. Music changes crossfade instead of restarting abruptly.

SFX remain short and responsive. Missing audio must never block game state changes.

## Opening Difficulty

Cave Slime attacks for 5 damage every 4 player moves. The tutorial opening guarantees early access to defensive or healing progress without solving the board for the player. A typical new player should finish with 70–80% HP. Later encounters ramp gradually; the boss remains the run's primary difficulty spike.

Balance tests cover opening stats, attack cadence, damage, and HP carry-over. Gameplay randomness remains deterministic under test seeds.

## Verification

- Logic and visual contract tests pass.
- Every scene smoke-tests without parser/runtime errors.
- Screenshots are captured at 720×1280 and 576×1280 equivalents plus a tall 20:9 viewport.
- Controls remain centered, reachable, and unclipped.
- The opening battle meets the 70–80% HP target under the tutorial path.
- Ambient tracks loop cleanly and music crossfades.
- A signed debug APK is exported, signature-verified, and handed off with its SHA-256 hash.
