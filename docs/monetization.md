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

`AdService` resolves the configured `AdmobRuntime` node on Android and keeps
the Engine singleton names as a compatibility fallback. The bundled AdMob
Plugin v7.0 supplies the Google Mobile Ads SDK, UMP consent hooks, and the
Android manifest App ID. Editor, desktop, headless CI, or a build without the
Android plugin remain safe no-ops.

## Placements

| Placement | Where | Rules |
| --- | --- | --- |
| Banner | Hall, Expedition select, Workshop, History, Codex, Credits | Never in battle, on the map, in events, or over a story beat. Exactly one banner exists per session. |
| Interstitial | Leaving the reward screen for the map | Capped: skips the first 3 battles, then at most one per 3 battles **and** per 150s. Never after a boss clear. |
| App Open | Returning to the foreground on a menu, the map or kit select | Never on the install session, never after a glance under 45s, at most one per 15 min, and never within 2 min of another full-screen ad. Dormant until an App Open unit id is set. |
| Rewarded — Second Wind | Defeat screen | Opt-in. Revive at 50% HP, once per run, offered *before* the run is failed. |
| Rewarded — Open a realm | Expedition select | Opt-in. Opens only the **next** sealed realm, never further ahead. |
| Rewarded — Reroll reward | Upgrade/relic choice | Opt-in. One reshuffle per battle; the roll is a serialized permutation so the new spread is genuinely different. |
| Rewarded — Multiply crystals | Run-end screen | Opt-in, once per run. Only ever adds on top of what was earned. |

All caps live in `data/ads.json` — change them there, not in code.

## Realm progression

The paywall is gone. Realms open by clearing the previous realm's boss
(`SaveSystem.record_area_clear`), and a rewarded ad can open the next one early
(`SaveSystem.unlock_area_early`, which refuses to skip ahead).

Players who bought the old **Full Campaign Unlock** are migrated at save
version 13: they keep every realm they paid for **and** get Remove Ads for free.

## Live configuration

### 1. AdMob console

The Potion Rogue app and its three units are configured as follows:

| Item | Value |
| --- | --- |
| App ID | `ca-app-pub-6279186647593327~2300822678` |
| Banner | `ca-app-pub-6279186647593327/2085929206` |
| Interstitial | `ca-app-pub-6279186647593327/5833602524` |
| Rewarded | `ca-app-pub-6279186647593327/6763540816` |

The production values are in `data/ads.json`. Local/debug runs are forced to
Google's test units by `src/autoload/admob_runtime.gd`; never click live ads
while testing.

The publisher file is already live and returns:

`google.com, pub-6279186647593327, DIRECT, f08c47fec0942fa0`

AdMob still needs to review the manually added app and link it to the Play
store listing after the closed-test listing becomes discoverable.

AdMob **Privacy & messaging** is live for Potion Rogue:

- `Potion Rogue - EEA GDPR Consent` targets the EEA, UK, and Switzerland and
  exposes Consent, Do not consent, and Manage options.
- `Potion Rogue - US States Privacy` targets every current and future supported
  US state and exposes the opt-out flow.
- Both messages use the live privacy-policy URL. The in-game
  *Settings → Ad Privacy Settings* button is wired to
  `AdService.open_privacy_options()` through the bundled UMP SDK.

### 2. Play Console
1. Create and activate the managed one-time product **`potion_rogue_remove_ads`**, title
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

### 3. Version
`1.7.6` / version code `36`.

## Verifying without ads

`tests/ad_service_test.tscn` asserts the no-plugin path stays inert and that the
frequency caps and banner scene list stay sane. Run it with the rest of the
suite:

```bash
godot --headless --path . tests/ad_service_test.tscn
```
