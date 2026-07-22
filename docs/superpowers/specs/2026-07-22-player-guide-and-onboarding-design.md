# Player Guide and Onboarding Design

## Goal

Teach Potion Rogue clearly enough that a first-time player understands the complete combat loop without leaving battle confused, while keeping every explanation available later from the main hall.

The guide must explicitly explain:

- legal bottle pours and potion completion;
- the four potion effects;
- enemy intents and the fact that each pour advances combat;
- mana generation and skill costs;
- the three colored dots in the Reaction Chamber;
- ordered Alchemy Reactions, formula discovery, and ultimate charge;
- active skills, ultimates, New Mix, Undo, map choices, and autosave.

## Considered Approaches

1. **Long linear tutorial only.** Easy to build, but forces players to memorize too much and becomes irritating on replay.
2. **Static encyclopedia only.** Excellent as a reference, but does not teach actions at the moment a new player needs them.
3. **Hybrid onboarding, contextual practice, and permanent Guide.** Recommended and selected. It introduces the mental model visually, requires a small number of real actions in battle, and provides a searchable reference afterward.

## Experience Structure

### 1. Animated Onboarding

The existing three text cards become six short animated chapters:

1. **Sort:** animated source and destination bottles demonstrate a legal pour.
2. **Brew:** four matching layers combine and reveal Red, Green, Blue, and Purple effects.
3. **Survive:** an enemy intent countdown advances to show that every successful pour spends one move.
4. **React:** completed potion colors fly into three Reaction Chamber sockets; Red then Red activates Fire Burst.
5. **Cast:** potion completion fills Mana, then the active Skill button lights and casts. Ultimate charge is shown as a separate resource filled by reactions.
6. **Explore:** hidden route nodes, rewards, autosave, and procedural runs are explained.

Each chapter has a clear title, one concise explanation, an animated diagram, progress markers, Back, Next, Skip, and Reduced Effects support. Animation is decorative and never required to continue.

### 2. Interactive Battle Tutorial

The first battle remains playable. Tutorial cards explain one required action at a time and only spotlight the relevant control. Highlight layers always ignore pointer input except the tutorial card buttons.

The lesson sequence is expanded to distinguish these concepts:

- select source;
- select a legal destination;
- Undo and restored enemy countdown;
- complete a potion and observe its immediate effect;
- observe the completed color entering the Reaction Chamber;
- complete the required second potion to activate Fire Burst;
- observe Mana gain;
- cast the active skill and see its exact cost;
- observe Ultimate charge gained from the reaction;
- use New Mix explanation without forcing a wasteful remix;
- choose a reachable map node.

The tutorial uses authored solvable board states. It cannot permanently block bottle input, and dismissing or skipping it cannot change combat state.

### 3. Main Hall Guide

A large **GUIDE** command is added to the main hall beside Upgrades and Settings. It opens a dedicated Guide scene, not a modal overlay.

The Guide has five tabs:

- **Basics:** bottle rules, move economy, potion effects, Undo, and New Mix costs.
- **Reactions:** explains that the three colored dots are the last completed potion essences, order matters, and matching suffixes activate formulas. It links to the Formula Codex.
- **Skills:** dynamically lists every kit, active skill, Mana cost, cooldown, passive identity, ultimate, and how ultimate charge is gained.
- **Battle:** HP, shield, armor, poison, enemy intent, objectives, status effects, and defeat.
- **Expedition:** routes, node types, procedural generation, rewards, save/continue, and abandon behavior.

Cards use existing premium frames, large touch targets, icon/color swatches, short demonstrations, and Indonesian-friendly plain language. The current game copy remains English for consistency; localization keys can be added later without changing the layout.

### 4. Context Help

- Tapping the Reaction Chamber continues to open the Formula Codex.
- Its accessible tooltip becomes explicit: “Last completed potion essences; order creates reactions. Tap for formulas.”
- Mana, Skill, and Ultimate controls receive concise factual tooltips generated from the currently selected kit.
- A small `?` button in battle opens the relevant Guide section without mutating or advancing combat. Returning restores the exact battle snapshot.

## Architecture

- `GuideContent` provides immutable section/card data derived from `potions`, `combos`, and `kits`; skill values therefore cannot drift from gameplay data.
- `GuideScreen` renders tabs and reusable cards.
- `OnboardingDemo` owns lightweight procedural demonstrations. It never talks to `RunState` or battle managers.
- `TutorialDirector` remains responsible only for ordered actions and persistence.
- Battle supplies dynamic context (current kit, Mana cost, tutorial targets) through existing public state and does not duplicate formulas.

New navigation scenes are additive. Existing saves migrate safely because completion remains backward-compatible: players who already completed the old tutorial keep their progress and can use Guide or Replay Tutorial manually.

## Animation and Accessibility

- Transitions use 180–360 ms fades, lifts, liquid pulses, and socket trails.
- Reduced Effects replaces motion with immediate state changes and a brief color emphasis.
- Text wraps at narrow Android widths, supports saved text scaling, and never overlays interactive bottles.
- All guide content is scrollable by dragging anywhere in the content region.
- Color meaning is always repeated in text; no mechanic depends on color alone.

## Failure Safety

- Guide navigation checkpoints the current battle before changing scenes and returns through `RunState.resume_scene()`.
- Missing art falls back to procedural diagrams and labels.
- Missing kit or formula fields display safe generic copy rather than crashing.
- Tutorial target lookup falling back to the board must still preserve pointer input.

## Verification

Automated coverage will verify:

- all four potion meanings and Reaction Chamber semantics appear in guide data;
- every authored kit has active skill cost, cooldown, and ultimate guide content;
- the main hall and battle expose Guide entry points;
- Guide return preserves an active battle boundary;
- onboarding contains all six chapters and Reduced Effects behavior;
- expanded tutorial actions persist, replay, skip, and pass pointer input to bottles;
- 576×1280 and 720×1280 layouts remain scrollable and unclipped;
- existing bottle touch, battle workflow, reaction, save/resume, and release tests remain green.

## Out of Scope

- voice-over;
- online videos;
- a new localization framework;
- changing reaction balance or skill effects;
- forcing existing players through onboarding again.
