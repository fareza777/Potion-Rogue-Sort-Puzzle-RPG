# Map Fog, Enemy Progression, and Hall Navigation Design

## Goal

Make route choices suspenseful, keep early encounters readable and modest, and remove the map dead end without losing run progress.

## Route disclosure

- The current/start node remains identified.
- Reachable choices show only `UNKNOWN ENCOUNTER`, a question-mark sigil, and a risk label. They do not expose kind, event, enemy name, or portrait.
- Unreachable future nodes show `UNCHARTED`, a fogged medallion, and no content metadata.
- Visited nodes may reveal their actual content so the route becomes a readable travel history.
- The boss node remains a sealed `DUNGEON GUARDIAN` destination until it is reachable.

## Enemy progression

- Floor 1 normal battles use only Slime or Skeleton.
- Floor 2 uses tier-1 enemies, introducing the wider roster.
- Floors 3–4 use tier 2, with elites allowed one tier above.
- Floor 5 uses tier 3, with elites allowed tier 4.
- Fire Golem remains the fixed floor-6 boss.
- Existing combat-heavy route cadence remains unchanged.

## Map navigation and presentation

- Add a named `BackToHallButton` that returns to `main_menu.tscn` without mutating `RunState`.
- Replace the raw seed header with a current-depth subtitle.
- Add a compact fog legend and stronger framing around route guidance.
- Use mystery sigils instead of dimmed enemy art to prevent accidental spoilers.

## Verification

- Test generation across 2,000 seeds for floor-specific enemy pools.
- Test map source contracts for disclosure states and non-destructive Hall navigation.
- Capture the map at 720x1280 and inspect disclosure, alignment, and button placement.
- Run all Godot test scenes and export a signed Android debug APK.
