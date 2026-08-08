# Story Flow, Credits, and Guide Polish Design

## Goal

Remove repeated full-screen story art, make Credits suitable for a Play Store release, and rebuild the existing Guide page so its notes are concise, useful, and never collide with ornamental frames on a 576×1280 phone viewport.

## Scope

This pass changes three presentation surfaces only:

1. Storyboard trigger policy at map, event, and battle transitions.
2. Credits and store-rating links.
3. The existing Guide page opened from the hall or battle help button.

The first-run onboarding remains unchanged. This work does not add a second tutorial, change combat balance, or replace generated paintings.

## Storyboard Trigger Policy

The player sees at most one full-screen generated painting when entering an encounter.

- A battle node plays `battle_intro` only.
- An event node plays `event_reveal` only.
- A non-encounter route may still use `route_choice` only if it does not immediately open a battle or event.
- Event choice results are explained inline on the event screen; `event_resolution` is not played as a second painting.
- Enemy signatures, boss phase changes, and reinforcement waves use the existing in-battle warning text, intent panel, animation, impact, sound, and music layering. They do not play `battle_escalation` as another full-screen enemy painting.
- `battle_victory`, `battle_defeat`, and `run_epilogue` remain because each communicates a new outcome instead of repeating the encounter introduction.

This policy removes the observed duplicate enemy/event images and the redundant `PHASE SHIFT` interruption without reducing combat feedback.

## Credits and Store Rating

Credits use a clean, release-facing hierarchy:

- Game title and short product tagline.
- Exact creator line: `Created by F7 Developer`.
- `RATE ON GOOGLE PLAY` opens `https://play.google.com/store/apps/details?id=com.farezagames.potionrogue`.
- `PRIVACY POLICY` opens the existing policy URL.
- `RETURN TO HALL` returns to the main menu.

Remove the previous studio, engine, font, and decorative narrative copy from the visible Credits screen. Add the same Google Play rating action to Settings under its existing store/support area for discoverability.

## Guide Information Architecture

The existing five tabs remain: Basics, Reactions, Skills, Battle, and Expedition. Tabs and the content area retain full-area drag scrolling with hidden scrollbars.

Each section contains:

- A title.
- One summary sentence, limited to two rendered lines.
- Compact lesson cards.

Each lesson card contains:

- Optional essence dots or formula sequence.
- A short lesson title.
- Up to three labeled facts: `WHAT`, `HOW`, and `NOTE`.
- No uninterrupted paragraph and no duplicate explanation between the section summary and cards.

The content focus is:

- Basics: select/pour/complete flow, four potion effects, Undo, and New Mix cost/recovery behavior.
- Reactions: the three history dots, ordered formulas, immediate effect, and Ultimate charge.
- Skills: Mana cost, cooldown measured in completed potions, and Ultimate charge/effect.
- Battle: enemy intent/countdown, objective, Shield/Armor/Poison, and turn tools.
- Expedition: hidden routes, encounter types, building a run, checkpointing, and abandon behavior.

## Guide Layout and Visual Safety

- The page targets the existing 576×1280 portrait reference first and remains responsive through `UiKit.layout_profile`.
- Every ornate lesson card contains a named inner safe-content margin. Text and dots live inside this margin, never directly inside the textured panel.
- Minimum inner margins are 34 px left/right, 24 px top, and 26 px bottom at the reference viewport.
- Card titles use 21–22 px text; fact labels use 13–14 px; fact values use 16–17 px; section summaries use 17–18 px.
- Labels wrap by words and never clip horizontally.
- Card height grows from its content. No fixed height may hide or overlap text.
- Content scrollbars remain hidden; dragging anywhere inside the tab strip or lesson list scrolls the corresponding axis.

## Verification

Automated checks must prove:

- Battle and event entry use only the approved single full-screen trigger.
- In-battle escalation no longer calls the storyboard service, while phase/wave feedback remains present.
- Credits show the exact creator line and both external links.
- Every Guide section has a concise summary and structured fact fields with bounded copy.
- Guide cards expose a named safe-content container and keep all text within it at 576×1280.
- Existing navigation to Guide and Formula Codex still works.

Visual verification captures the Guide at 576×1280, checks all five sections, and confirms no text touches the ornamental corners or overlaps another label. The optimized Android APK is rebuilt after the full test suite passes.
