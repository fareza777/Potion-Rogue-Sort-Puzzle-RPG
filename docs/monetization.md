# Monetization — ads + one-time Remove Ads

Potion Rogue is free to play, funded by Google AdMob, with a single optional
in-app product that switches the ads off.

## What the code does

| Piece | File |
| --- | --- |
| Ad boundary (AdMob) | `src/autoload/ad_service.gd` (autoload `AdService`) |
| Ad configuration | `data/ads.json` |
| Purchase boundary (Play Billing) | `src/autoload/billing_service.gd` (autoload `BillingService`) |
| Purchase surface | `src/ui/components/remove_ads_card.gd` |
| Entitlement + realm progression | `src/autoload/save_system.gd` |

`AdService` resolves the AdMob Android plugin at runtime through
`Engine.get_singleton`. It is not a hard dependency: with no plugin installed —
editor, desktop, headless CI, or an Android build without the `.aar` — every ad
call is a safe no-op and the game plays exactly as before.

## Placements

| Placement | Where | Rules |
| --- | --- | --- |
| Banner | Hall, Expedition select, Workshop, History, Codex, Credits | Never in battle, on the map, in events, or over a story beat. |
| Interstitial | Leaving the reward screen for the map | Capped: skips the first 3 battles, then at most one per 3 battles **and** per 150s. Never after a boss clear. |
| Rewarded — Second Wind | Defeat screen | Opt-in. Revive at 50% HP, once per run, offered *before* the run is failed. |
| Rewarded — Open a realm | Expedition select | Opt-in. Opens only the **next** sealed realm, never further ahead. |

All caps live in `data/ads.json` — change them there, not in code.

## Realm progression

The paywall is gone. Realms open by clearing the previous realm's boss
(`SaveSystem.record_area_clear`), and a rewarded ad can open the next one early
(`SaveSystem.unlock_area_early`, which refuses to skip ahead).

Players who bought the old **Full Campaign Unlock** are migrated at save
version 13: they keep every realm they paid for **and** get Remove Ads for free.

## What you still need to do outside the repo

### 1. AdMob console
1. Create the app in AdMob and note the **App ID** (`ca-app-pub-…~…`).
2. Create three ad units: **Banner**, **Interstitial**, **Rewarded**.
3. Put the App ID and the three unit IDs into `data/ads.json` and set
   `"test_mode": false` for the production build. Until then the file ships
   Google's official **test** IDs — never publish with those live, and never
   click your own live ads.
4. Configure the **UMP / Privacy & messaging** consent form (required for the
   EEA, UK and Switzerland). The in-game button is
   *Settings → Ad Privacy Settings*, wired to `AdService.open_privacy_options()`.

### 2. Install the AdMob Godot Android plugin
`AdService` looks for a singleton named `AdmobPlugin`, `AdMob`, `Admob` or
`GodotAdMob` (in that order). Drop the plugin's `.aar` + `.gdap`/plugin config
into `addons/`, enable it, and declare the App ID the way that plugin expects
(usually its own export-preset field, which writes the
`com.google.android.gms.ads.APPLICATION_ID` manifest entry).

If your plugin exposes different method or signal names than the ones in
`_connect_plugin_signals()` / `_call_plugin()`, adjust those two functions —
that is the only place plugin names appear.

### 3. Play Console
1. Create the managed in-app product **`potion_rogue_remove_ads`**, title
   "Remove Ads", price US$4.99, and activate it. (The old
   `potion_rogue_full_campaign` product is still honoured by the code for
   existing buyers — deactivate it rather than deleting it.)
2. **Data safety**: the app now collects, via AdMob, an *Advertising ID*, plus
   approximate location, IP-derived data and app interactions for advertising
   and fraud prevention. Declare `Advertising ID` under "Device or other IDs",
   collected and shared, purpose *Advertising or marketing* + *Fraud prevention*.
   Leaving the old "no data collected" declaration in place is a policy
   violation.
3. **Advertising ID permission**: target SDK 33+ builds must declare
   `com.google.android.gms.permission.AD_ID`. The AdMob plugin normally merges
   this in; confirm it is present in the merged manifest.
4. **Ads declaration**: set "Contains ads" to **Yes** in the app content
   section, and re-check the target audience / Families questionnaire.
5. **Privacy policy**: `privacy-site/app/page.tsx` has been updated with an
   Advertising section. Redeploy it before submitting — the live URL in
   `src/autoload/app_links.gd` is what review reads.

### 4. Version
`1.7.0` / version code `30`.

## Verifying without ads

`tests/ad_service_test.tscn` asserts the no-plugin path stays inert and that the
frequency caps and banner scene list stay sane. Run it with the rest of the
suite:

```bash
godot --headless --path . tests/ad_service_test.tscn
```
