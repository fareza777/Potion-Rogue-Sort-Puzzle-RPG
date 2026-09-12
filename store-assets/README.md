# Potion Rogue Store Assets

The approved Play listing assets use English copy throughout. The current ASO refresh is the `aso-v2-*.png` set: eight 1080×1920 portrait creatives with real shipped gameplay framed in a consistent dark-indigo/gold presentation.

- `play-store-feature-graphic.png` — 1024×500 Google Play feature graphic.
- `app-icon-v3-512.png` — 512×512 Google Play icon matching the Android launcher.
- `screenshots/aso-v2-01-sort-potions.png` — main menu and the core potion fantasy.
- `screenshots/aso-v2-02-tactical-combat.png` — live puzzle combat with readable enemy intent.
- `screenshots/aso-v2-03-branching-runs.png` — route choice and roguelite risk.
- `screenshots/aso-v2-04-build-your-brewer.png` — four distinct brewer kits.
- `screenshots/aso-v2-05-five-realms.png` — campaign areas, bosses and hazards.
- `screenshots/aso-v2-06-persistent-choices.png` — story choices carrying through a run.
- `screenshots/aso-v2-07-permanent-upgrades.png` — permanent upgrade workshop.
- `screenshots/aso-v2-08-remove-ads.png` — Remove Ads purchase and ad/accessibility settings.

- `screenshots/` — truthful captures rendered directly from the Godot scenes; the older raw 720×1080 set remains available for rollback.
- `tools/build_store_screenshots_v2.py` — reproducible compositor for the current eight-image ASO set.
- `build_feature_graphic.ps1` — reproducible compositor for the feature graphic.
- `build_app_icon.ps1` — reproducibly derives the launcher and Play Store icons from the approved v3 master.

Regenerate the screenshots with `DevTools` after material UI changes, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\store-assets\build_feature_graphic.ps1
powershell -ExecutionPolicy Bypass -File .\store-assets\build_app_icon.ps1
```

The creative intentionally uses only shipped game art and real gameplay screens.
