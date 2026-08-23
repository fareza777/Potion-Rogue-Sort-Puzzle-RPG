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
| App Open | Returning to the foreground on a menu, the map or kit select | Never on the install session, never on a cold start, never after a glance under 45s, at most one per 15 min, and never within 2 min of another full-screen ad. |
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
| App Open | `ca-app-pub-6279186647593327/1834184740` |

All four units are live and `test_mode` is `false`. The production values are
in `data/ads.json`. Local/debug runs are forced to
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

### 2. Play Console — done

1. **Remove Ads product** — `potion_rogue_remove_ads`, US$4.99, active. The old
   `potion_rogue_full_campaign` is still honoured in code for existing buyers,
   so deactivate rather than delete it.
2. **Data safety** — Advertising ID declared as collected and shared for
   *Advertising or marketing* and *Fraud prevention*; submitted for review.
3. **Privacy policy** — live, with the Advertising section. The URL review reads
   is in `src/autoload/app_links.gd`.
4. **app-ads.txt** — live and returning
   `google.com, pub-6279186647593327, DIRECT, f08c47fec0942fa0`.

Still worth confirming on the next build: that the merged Android manifest
carries `com.google.android.gms.permission.AD_ID`, which target SDK 33+ needs.
The AdMob plugin normally merges it in.

### 3. Version
`1.7.6` / version code `36`.

## Verified on device

A debug build (Google test units, Redmi Note 11 / Android 13) confirmed:
banner loads exactly once per session and never reaches battle, the map, a
story beat or an event; App Open is skipped on a cold start and presents on a
genuine resume; rewarded ads present and grant. Interstitials were not observed
because the lifetime grace period had not been cleared yet.

## Verifying without ads

`tests/ad_service_test.tscn` asserts the no-plugin path stays inert and that the
frequency caps and banner scene list stay sane. Run it with the rest of the
suite:

```bash
godot --headless --path . tests/ad_service_test.tscn
```
