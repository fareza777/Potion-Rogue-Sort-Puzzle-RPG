# Route Pacing and Individual Enemy Sprites

## Problem

The procedural generator only guarantees a non-elite "safe" lane. That lane may still be an event, shop, treasure, or campfire on every floor, so a valid route can reach the boss without fighting. The twenty generated enemies use five-character atlases divided into equal-width regions, but the illustrated subjects do not respect those mathematical boundaries, allowing adjacent body parts into the rendered region.

## Route design

The five pre-boss floors use an alternating encounter cadence. Floors 1, 3, and 5 contain combat nodes only; floor 1 is normal battle while floors 3 and 5 may include elites. Floors 2 and 4 contain exactly one non-combat node, with every other node remaining combat. Therefore every possible route includes at least three battles, cannot contain consecutive non-combat nodes, and still presents two procedural utility/reward opportunities before the boss.

The graph remains seeded and deterministic. Enemy selection, lane count, battle/elite mix, the two non-combat kinds, contracts, modifiers, and links continue to vary by seed. Tests sweep 2,000 seeds and validate every reachable start-to-boss route, not merely one preferred route.

## Sprite design

Each of the twenty generated enemies receives one dedicated transparent PNG under `assets/art/enemies/generated/<enemy_id>.png`. Every image contains one complete, centered character with generous transparent padding and no neighboring subject. The existing atlas files may remain as source/reference art but are no longer used by runtime enemy data.

`VisualRegistry.enemy_texture()` prefers the direct sprite path used by the original slime, skeleton, and other launch enemies. Atlas support remains only as a backwards-compatible fallback. Automated tests require all twenty generated enemies to resolve to a direct sprite resource.

## Verification

- Seed sweep: every route contains at least three combat encounters and never two consecutive non-combat encounters.
- Content test: each middle floor contains combat; floors 2 and 4 contain exactly one non-combat node.
- Visual resource test: every new enemy resolves an individual sprite and no runtime atlas reference.
- Live captures: at least four new enemies from different families are inspected in battle, plus a generated map.
- Full Godot test suite and signed Android APK export run after merge.
