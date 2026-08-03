# Potion Rogue Play Release Design

**Date:** 2026-08-03  
**Status:** Approved for implementation by the product owner

## Goal

Prepare Potion Rogue: Sort Puzzle RPG for Google Play closed testing with an
English-first store presence, a working one-time purchase that unlocks the full
five-realm campaign, a public English privacy policy, eight truthful gameplay
screenshots, and a short Remotion promotional video.

## Product decisions

- App type: Game
- App pricing: Free
- Default store language: English (United States)
- Package name: `com.farezagames.potionrogue`
- Product ID: `potion_rogue_full_campaign`
- Product name: `Full Campaign Unlock`
- Product type: One-time non-consumable
- Product price: US$4.99
- Entitlement: unlock access to all five realms; do not auto-complete realms,
  grant mastery, grant Ascension, or alter existing campaign progress
- Closed testing track: Alpha
- Closed tester groups: the four Google Groups currently used by Vocatim

## Scope

### 1. Billing and entitlement

Use the first-party Godot Google Play Billing Android plugin compatible with the
project's Godot 4.x line. Add a small billing service boundary so gameplay and
UI do not call plugin APIs directly.

The service must:

1. Connect only on Android when the plugin is available.
2. Query the product details for `potion_rogue_full_campaign`.
3. Query owned purchases on startup and app resume.
4. Launch the purchase flow from the campaign unlock card.
5. Grant the entitlement only for a `PURCHASED` result.
6. Acknowledge the non-consumable purchase after granting the entitlement.
7. Keep pending, canceled, unavailable, and error states locked with readable
   English feedback.
8. Provide a restore-purchase action that re-queries owned purchases.
9. Leave desktop/editor/headless runs usable without the Android plugin.

Persist the entitlement in the versioned local save file. Treat Play purchase
state as the source of truth whenever the Android service can query it; the
local flag is a resilient cache for offline play after a verified purchase.

### 2. Unlock behavior and UI

Shadow Crypt remains available to every player. The four later realms show a
clear locked state until the entitlement is active. The purchase card explains
that one purchase unlocks all five realms permanently on the player's Google
Play account. Add Buy and Restore Purchase actions in the campaign selection
surface and a restore action in Settings.

Do not hide the normal crystal shop, daily challenge, tutorials, accessibility
settings, or offline play behind the purchase. Do not describe the purchase as
an ad-removal or subscription product.

### 3. English store listing

Use this copy unless Play Console imposes a stricter field limit:

- Title: `Potion Rogue: Sort Puzzle RPG`
- Short description: `Sort potions, build powerful runs, and conquer five dark-fantasy realms.`
- Full description:

  > Sort potions. Cast spells. Survive the dungeon.
  >
  > Potion Rogue is an offline portrait puzzle RPG where every smart pour
  > becomes a tactical decision. Arrange colorful potions to complete a brew,
  > trigger its effect instantly, and outplay enemies before their next attack.
  >
  > BUILD A RUN
  > Choose a kit, follow branching dungeon routes, and shape each expedition
  > with upgrades, relics, mutations, catalysts, and transparent risk-reward
  > events.
  >
  > MASTER THE BREW
  > Fire burns, healing restores, shields absorb, poison keeps ticking, and
  > alchemy reactions reward clever combinations. Read enemy intents, manage
  > your moves, and turn a crowded board into a winning spell.
  >
  > CONQUER FIVE REALMS
  > Explore the Shadow Crypt, Verdant Catacombs, Astral Foundry, Frostbound
  > Reliquary, and Abyssal Apothecary. Each realm brings new enemies,
  > hazards, bosses, and strategic pressure.
  >
  > PLAY YOUR WAY
  > Enjoy a fully offline experience with no account required, a guided first
  > run, readable accessibility settings, daily and weekly challenges, boss
  > rematches, run history, and exact save-and-exit recovery during battle.
  >
  > The first realm is free to play. A one-time Full Campaign Unlock purchase
  > opens all five realms permanently. Google Play handles the purchase and
  > Restore Purchase is available on supported Android devices.

### 4. Store creative package

Provide eight portrait gameplay screenshots, ordered for first-impression
clarity:

1. Main menu / Hall — identify the dark-fantasy puzzle RPG.
2. Cave Slime battle — show the sort-to-attack loop.
3. Alchemy reaction or potion completion — show immediate tactical payoff.
4. Dungeon map — show route choice and run structure.
5. Event or campfire decision — show risk-reward choices.
6. Arcane Workshop — show persistent build progression.
7. Fire Golem boss — show high-stakes combat.
8. Area selection — show the five-realm campaign and unlock structure.

Screenshots must be captured from the current shipped scenes, contain no
invented UI, and use English captions only when the caption is part of the
actual game capture. Use the existing feature graphic as the base for the
1024x500 Play asset, refreshing it after the final screenshot set.

### 5. Privacy policy

Publish a non-editable, publicly accessible English HTML page. It must name
the app and developer, provide a privacy contact mechanism, explain that the
game stores progress and settings locally, state that no personal data is
collected or shared by the game, and explain that Google Play independently
processes purchase transactions. It must also state retention/deletion behavior
for the local save and that uninstalling the app removes the local save subject
to Android backup/device behavior.

Link the same page from Play Console's App content and from an accessible
in-app Settings or Credits action.

### 6. Promotional video

Create a 30-second 1920x1080 Remotion video using only actual game screenshots
and shipped visual assets. Sequence: hook, sort-to-attack, build choices,
five-realm campaign, boss payoff, and the English end card. Use restrained
motion, high-contrast English typography, and no unsupported claims. Upload it
to the already-open YouTube account only after the rendered file is verified;
use the resulting YouTube URL in the Play listing.

### 7. Play Console setup

Create the app with the exact package name and free/game declarations. Add the
English listing, graphic assets, privacy URL, data-safety answers matching the
offline code and Billing integration, the one-time product, and the Alpha
closed-testing track. Copy the four Vocatim Google Group addresses without
adding unrelated testers. Stop after the closed-testing setup and leave the
user to submit later stages.

## Error handling

- Billing plugin missing: show the free first realm and a non-blocking
  unavailable message; never crash or show a fake success.
- Purchase pending: explain that access will appear after Google Play confirms
  payment; do not unlock yet.
- Purchase canceled or failed: keep the campaign locked and preserve the
  existing save.
- Corrupt or old save: migrate safely and keep the entitlement false unless a
  current Play query confirms ownership.
- Missing creative asset or privacy URL: block the Play Console upload step and
  report the exact missing item.

## Verification

- Run focused billing/save/area-unlock tests and the complete existing headless
  regression suite.
- Export a signed Android App Bundle with an incremented version code and verify
  package name, version, and bundle output.
- Validate all eight screenshot dimensions, feature graphic dimensions, and
  video render output.
- Open the privacy URL and verify it returns the final English page publicly.
- Confirm Play Console shows the app, product, English listing, privacy URL,
  and Alpha tester groups before handing off.
- Do not claim a public release; the requested stopping point is closed testing
  configuration.
