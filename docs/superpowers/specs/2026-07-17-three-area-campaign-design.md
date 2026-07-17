# Three-Area Campaign Expansion Design

## Goal

Turn the current single-run game into a replayable three-area campaign while preserving short mobile sessions and the existing potion-sort combat core.

## Campaign structure

The campaign contains three independently replayable seven-depth expeditions:

1. **Shadow Crypt** — introductory crypt roster, purple-blue torchlight, Fire Golem boss, threat multiplier `1.00`.
2. **Verdant Catacombs** — fungal and poison roster, bioluminescent roots and spores, Bloom Horror boss, threat multiplier `1.12`.
3. **Astral Foundry** — arcane and infernal roster, rune machinery and furnace light, Furnace Titan boss, threat multiplier `1.25`.

Defeating a boss completes only the current area. It banks run crystals, records the first clear, unlocks the next area, and returns the player to an expedition selection screen. Completing Astral Foundry marks the campaign complete without preventing replay.

## Data architecture

Create `data/areas.json`. Each area defines:

- `id`, `order`, `name`, `subtitle`, and `unlock_after`;
- `boss`, `background`, `music`, `accent`, and particle preset;
- explicit enemy pools for `intro`, `tier_1`, `tier_2`, `tier_3`, and `elite`;
- threat multiplier and first-clear crystal reward.

`GameState` loads areas. `RunGenerator.generate(seed, area_id)` consumes area pools and boss identity instead of scanning every enemy globally. Graph shape and combat-heavy cadence remain deterministic and seven depths long.

## Progression and saves

Save version 4 adds:

- `unlocked_areas`, initially `['shadow_crypt']`;
- `completed_areas`;
- `selected_area`;
- per-area `best_depth` and `wins`.

Active-run boundary version 3 adds `area_id`. Migration preserves all existing currencies, upgrades, settings, tutorial progress, and an active legacy Shadow Crypt run. Returning to Hall preserves the active run; Continue resumes it rather than silently creating a new one.

## Player flow

`NEW RUN` opens `area_select.tscn`, not kit selection directly. The expedition screen shows three large illustrated area cards, completion/unlock state, boss silhouette, first-clear reward, and difficulty. Choosing an unlocked area opens kit selection; choosing a kit starts that area. Locked cards explain the exact prerequisite.

After an area boss:

- title: `AREA CLEARED`;
- show banked crystals and first-clear bonus separately;
- announce the next unlocked area;
- actions: `NEXT EXPEDITION` and `RETURN TO HALL`;
- final area additionally shows `CAMPAIGN COMPLETE`.

## Area identity

Generate two new portrait backgrounds matching the current painterly dark-fantasy quality:

- `verdant_catacombs_battle.png`: ruined underground greenhouse, cyan-green fungi, roots, dark central combat stage;
- `astral_foundry_battle.png`: arcane forge, blue-violet machinery, orange furnace core, dark central combat stage.

Map and battle backgrounds, accent colors, particles, and music resolve from the active area. Shared gold/obsidian frames and Cinzel typography remain the campaign-wide brand. Bloom Horror and Furnace Titan reuse their existing clean individual sprites but gain three authored boss phases each.

## Audio

Add `verdant_ambient.wav` and `astral_ambient.wav` plus area-aware melodic/percussion profiles. Verdant uses low wooden pulses, glassy spores, and slower tempo; Astral uses metallic ticks, fifths, and higher energy. Boss phases retain tempo escalation while inheriting the active area's tonal profile.

## Difficulty

Every area starts with readable low-complexity fights, then escalates:

- depth 1: one modifier maximum and area intro enemies;
- depths 2–3: tier-1/2 roster and one modifier;
- depths 4–5: tier-2/3 roster, occasional elite, up to two modifiers;
- depth 6: three-phase authored boss.

Area multipliers affect threat budgets, not raw data definitions. Assist Mode continues to add one warning move without reducing rewards. New areas must remain beatable without permanent upgrades.

## Verification

- Campaign/save migration tests cover unlocks, completion, replay, and active-run area restoration.
- Generator tests cover all three area pools over 2,000 seeds each and prove no cross-area enemy leakage.
- Boss tests cover three phases for all three bosses.
- Visual tests cover area selection, dynamic backgrounds, locked/complete states, and truthfully labeled navigation.
- Live captures at `720×1280` cover selection, Verdant map/battle, and Astral map/battle.
- Full suite, Android export, v2/v3 signature verification, merge, and push are required.
