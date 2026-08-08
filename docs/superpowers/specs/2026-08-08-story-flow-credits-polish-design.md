# Story Flow and Credits Polish Design

## Goal

Remove repeated full-screen story art and make Credits suitable for a Play Store release. The existing Guide and first-run onboarding remain unchanged.

## Storyboard Trigger Policy

The player sees at most one full-screen generated painting when entering an encounter.

- Battle nodes play `battle_intro` only.
- Event nodes play `event_reveal` only.
- The map does not prepend `route_choice` before immediately opening a battle or event.
- Event results remain inline; `event_resolution` is not played as a duplicate painting.
- Enemy signatures, boss phases, and reinforcement waves use existing in-battle HUD, animation, impact, sound, and music feedback without `battle_escalation` full-screen art.
- `battle_victory`, `battle_defeat`, and `run_epilogue` remain because they present new outcomes.

## Credits and Store Rating

- Show Potion Rogue branding and the exact line `Created by F7 Developer`.
- Remove visible studio, engine, font, and decorative narrative copy.
- Add `RATE ON GOOGLE PLAY`, opening `https://play.google.com/store/apps/details?id=com.farezagames.potionrogue`.
- Keep `PRIVACY POLICY` and `RETURN TO HALL`.
- Add the same rating action to Settings under its existing store section.

## Non-Goals

- Do not modify `src/ui/guide_screen.gd`, `src/guide/guide_content.gd`, Guide tests, Guide copy, Guide layout, or onboarding.
- Do not change combat rules, balance, enemy art, or generated paintings.

## Verification

Automated checks prove that battle/event entry use only the approved single trigger, in-battle escalation retains inline feedback, Credits use the exact creator line and links, and the Guide files have no diff. Run the full test suite and rebuild the Android debug APK after targeted tests pass.
