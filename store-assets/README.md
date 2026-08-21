# Potion Rogue Store Assets

The approved Play listing assets use English copy throughout:

- `play-store-feature-graphic.png` — 1024×500 Google Play feature graphic.
- `app-icon-v3-512.png` — 512×512 Google Play icon matching the Android launcher.
- `screenshots/01-main-menu.png` — branded Hall entrance.
- `screenshots/02-battle-potion-sigils.png` — live puzzle combat with accessibility sigils.
- `screenshots/03-campaign-unlock.png` — expedition selector with the US$4.99 Remove Ads offer.
- `screenshots/04-realm-map.png` — route choice and roguelike risk.
- `screenshots/05-event-choice.png` — permanent event trade-off.
- `screenshots/06-brewer-selection.png` — four distinct brewer kits.
- `screenshots/07-arcane-workshop.png` — permanent upgrade workshop.
- `screenshots/08-settings-accessibility.png` — Remove Ads purchase, ad privacy controls and accessibility settings.

- `screenshots/` — truthful 720×1080 captures rendered directly from the Godot scenes.
- `build_feature_graphic.ps1` — reproducible compositor for the feature graphic.
- `build_app_icon.ps1` — reproducibly derives the launcher and Play Store icons from the approved v3 master.

Regenerate the screenshots with `DevTools` after material UI changes, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\store-assets\build_feature_graphic.ps1
powershell -ExecutionPolicy Bypass -File .\store-assets\build_app_icon.ps1
```

The creative intentionally uses only shipped game art and real gameplay screens.
