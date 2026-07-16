# Potion Rogue Store Assets

- `play-store-feature-graphic.png` — 1024×500 Google Play feature graphic.
- `screenshots/` — truthful 720×1080 captures rendered directly from the Godot scenes.
- `build_feature_graphic.ps1` — reproducible compositor for the feature graphic.
- `build_app_icon.ps1` — reproducible 512×512 app-icon compositor.

Regenerate the five screenshots with `DevTools` after material UI changes, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\store-assets\build_feature_graphic.ps1
```

The creative intentionally uses only shipped game art and real gameplay screens.
