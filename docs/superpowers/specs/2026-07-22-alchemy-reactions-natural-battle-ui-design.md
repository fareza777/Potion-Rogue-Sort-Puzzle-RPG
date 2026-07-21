# Alchemy Reactions and Natural Battle UI — Design Specification

## Status and decision

The user approved the hybrid direction on 2026-07-22: tactical Alchemy Reactions form the battle core, while Hero Schools and run-build choices change how those reactions behave.

Three directions were evaluated:

1. **Alchemy Reactions (selected core):** completed potion colors form ordered two- and three-color formulas that answer enemy intent.
2. **Flask Engineering:** capacity and vessel-shape modification. This is deferred because it harms board readability and solver predictability.
3. **Hero Schools:** class-specific rules and progression. This is selected as the supporting layer rather than the core, so hero identity deepens the puzzle instead of replacing it.

The work also includes two approved presentation changes: remove colored guide boxes/rings from normal battle play, and enlarge the main-menu dock icons.

## Product outcome

The finished system must make each move serve three readable decisions:

1. Which legal pour advances the color-sort board?
2. Which completed color should enter the reaction sequence next?
3. Which formula best answers the enemy's declared intent and the current build?

The base sort rules remain unchanged. A player who ignores advanced formulas can still finish early encounters using the four base potion effects. Deeper enemies and higher Ascension levels reward deliberate sequencing without requiring memorization of a large recipe book.

## Natural battle interaction

Normal battle play contains no colored target guides around bottles:

- Remove legal-target circles, yellow focus rectangles, tutorial-style target boxes, and persistent source/target outlines.
- Selecting a bottle only lifts it slightly and intensifies its existing liquid glow. This is direct selection feedback, not a move suggestion.
- A successful move is communicated by tilt, liquid travel, glass audio, and target settle animation.
- An invalid move uses a short restrained shake and error sound. It does not paint the board red or add a box.
- Mechanically meaningful states remain visible: locked, cursed, volatile, hidden, and other enemy-applied conditions. Their visuals must be visually distinct from guidance.
- Keyboard/controller focus remains accessible, but uses a subtle neutral-white inner glint visible only during non-touch navigation, not a yellow rectangle.
- The guided tutorial may spotlight controls while it is explicitly active. Completing or skipping the tutorial removes all tutorial overlays immediately.
- Optional color-pattern accessibility remains an explicit Settings choice; it must never activate as battle guidance by default.

## Menu dock visual design

The main-menu dock keeps five destinations: Home, Areas, Build, History, and Credits.

- Increase icon rendering from 54 px to a 70–76 px target, chosen responsively from available width.
- Increase dock height and button height only enough to preserve the icon, caption, safe-area inset, and a minimum 56 px touch target.
- Use the generated medallion artwork at its natural aspect ratio; never stretch it to fill a rectangular button.
- Use a soft medallion glow and brighter caption for the active destination. Do not draw an active-tab box.
- Captions remain readable at the narrow 576 px reference viewport and must not clip or overlap adjacent icons.

## Alchemy Reaction rules

### Base essences

A completed full bottle produces one essence and immediately resolves its base effect:

- Red / Fire: direct enemy damage.
- Green / Life: restore player HP.
- Blue / Ward: grant shield.
- Purple / Venom: apply damage over enemy turns.

The completed color is then appended to a three-slot Reaction Chamber. The chamber is ordered, keeps only the three most recent essences, and is included in exact battle snapshots.

### Formula resolution

- The resolver checks the longest matching suffix first, so a three-color formula takes precedence over a two-color formula.
- A completion can trigger at most one reaction. This prevents the same essence from firing both a two-color and a three-color formula.
- Triggering a reaction does not erase the chamber. Its suffix remains available for deliberate chaining, while the three-slot limit naturally pushes older colors out.
- Base potion effects always resolve before the reaction bonus. Formula copy must describe whether it modifies that base effect or applies a separate effect.
- Reactions cost no additional move. The pours used to complete the bottles are already the tactical cost.
- Ultimate charge is granted once per resolved reaction and is capped at 100.

Initial formulas use the existing authored set: Fire Burst, Restorative Barrier, Reflected Blaze, Toxic Detonation, Burning Venom, Fortify, Regeneration, Venom Ward, Inferno Catalyst, Sanctuary, and Plague Nova. Each formula receives a display name, concise effect description, tags, VFX profile, and exact numeric payload in data.

### Reaction Chamber UI

The chamber is a compact factual status strip near mana and skills, not a hint system:

- Show up to three small colored essence gems in chronological order.
- Empty slots use low-contrast neutral sockets.
- On formula activation, the matched gems converge briefly into a named reaction burst, then return to their current sequence state.
- Do not preview the next required color during normal battle.
- A tap opens the discovered Formula Codex; it does not highlight any bottle.

## Hero Schools

The five existing kits become distinct rule modifiers:

- **Ember Adept:** strengthens Fire formulas and rewards consecutive aggressive reactions.
- **Verdant Warden:** converts overhealing into Ward and improves Life/Ward reactions.
- **Void Brewer:** manipulates Venom and can create a limited Wild essence through its active skill.
- **Tide Oracle:** controls chamber history, allowing one stored essence to survive a push or be reordered through a cooldown-limited skill.
- **Marrow Alchemist:** spends HP for amplified Fire/Venom reactions, with explicit lethal-safety rules.

Every passive, active, and ultimate must alter a decision the player makes. Pure percentage bonuses are secondary tuning, not the identity of a school.

## Build integration

Relics, catalysts, mutations, upgrades, and formula effects use structured reaction hooks rather than free-form conditional code. Supported hook families include:

- transform an incoming essence;
- duplicate an essence with a per-battle or cooldown limit;
- preserve, reorder, or clear chamber history;
- modify a tagged reaction payload;
- trigger a secondary effect after a reaction;
- reward answering a specific enemy intent.

Each item declares tags, trigger timing, limits, and exact values in data. Build Summary derives genuine synergies from those fields. Reward cards state the affected formula or tag and show the numerical change before selection.

## Enemy and boss interaction

Enemies do not directly disable random recipes without warning. Their intent communicates a counterplay opportunity:

- armor intents invite shield conversion or poison buildup;
- large attacks invite Ward/Life sequencing;
- cleansing intents create a timing decision around Venom detonation;
- healing or summoning intents reward burst formulas;
- curse and lock intents pressure board efficiency without prescribing a target flask.

Boss phases may alter reaction rules, but every alteration is declared before it becomes active, is preserved in snapshots, and has at least one viable response. Early realm enemies teach one interaction at a time; later realms combine two interactions. Difficulty comes from decisions, not hidden information or inflated HP alone.

## Discovery and onboarding

- The tutorial introduces base potion effects first, then demonstrates one two-color reaction using an authored solvable board.
- New formulas are discovered when first activated and recorded in the Formula Codex.
- A newly discovered reaction may show one concise result card after resolution. It must not pause every subsequent activation.
- The Codex lists discovered formulas, exact effects, compatible Hero Schools, and owned build modifiers.
- Undiscovered formulas show only their tier and silhouette; progression never requires external trial-and-error documentation.

## Architecture and data flow

`ComboResolver` evolves into the authoritative reaction-domain object while preserving backward-compatible snapshots:

1. `PuzzleBoard` emits a completed color.
2. `BattleScreen` forwards it to base potion resolution and then to `ComboResolver`.
3. `ComboResolver` appends the essence, resolves the longest suffix, and returns one typed result.
4. `BattleManager` applies the typed payload through explicit reaction-effect handlers.
5. Presentation receives a read-only event containing formula ID, colors, effect summary, and VFX profile.

Hero and build modifiers are assembled into a deterministic reaction context before resolution. They may transform the input or result only through registered hook types. The resolver must remain deterministic for the same battle snapshot, build, and input color.

Snapshot migration accepts the existing `history` and `ultimate_charge` fields. New fields use safe defaults so active runs from earlier builds resume without losing the chamber or duplicating a reaction.

## Error handling and safety

- Unknown formula IDs or hook types log a development error and resolve only the base potion effect in production.
- Invalid numeric payloads are rejected during data validation, not clamped silently mid-battle.
- Reaction failure never corrupts the puzzle board, consumes extra mana, or spends an additional move.
- Snapshot restore validates chamber colors, length, charge range, and modifier state before enabling input.
- Animation is presentation-only; battle state commits before VFX and remains correct if Reduced Effects skips the sequence.

## Balance constraints

- Two-color formulas provide useful tactical value but remain weaker than three-color formulas.
- Formula bonuses target approximately 25–45% of a base potion's value; three-color formulas target 70–110%, subject to simulation.
- No build may create an unbounded essence loop, free infinite healing, or repeated reaction without a new bottle completion.
- Early encounters remain beatable without reactions. Standard mid-run encounters expect occasional two-color use; elites and bosses reward deliberate chaining.
- Enemy scaling, board difficulty, reaction value, and run rewards are tested together across all areas and Ascension bands.

## Testing and acceptance

All behavioral implementation follows red-green TDD. Required evidence includes:

- ordered suffix matching, longest-match precedence, one reaction per completion, and history trimming;
- deterministic modifier ordering and loop prevention;
- snapshot round-trip and migration from the current combo snapshot;
- every formula payload applying its exact combat result;
- every Hero School changing the intended reaction behavior;
- no normal-battle guidance circles, yellow boxes, or target highlights;
- touch selection, keyboard focus, tutorial spotlight, and color-pattern accessibility remaining distinct;
- dock icons meeting responsive size, aspect-ratio, touch-target, and clipping constraints at 576×1280 and 720×1280;
- balance simulation across early, standard, elite, boss, and Ascension encounters;
- Android battle captures demonstrating clear bottles, readable chamber state, enlarged menu icons, and no guide residue.

## Non-goals

- Changing core pour legality or replacing the color-sort puzzle.
- Adding arbitrary flask capacities or irregular vessel shapes in this release.
- Showing recommended moves or the next recipe color during normal play.
- Expanding the enemy roster solely to justify the reaction system.
- Replacing authored enemy intent with opaque random counters.

## Delivery boundaries

The implementation plan will separate: visual cleanup and dock sizing; reaction-domain tests and data schema; typed effect application; Hero School hooks; enemy/boss integration; discovery/Codex; balance simulation; responsive captures and Android release validation. Each boundary must leave the game playable and preserve existing active runs.
