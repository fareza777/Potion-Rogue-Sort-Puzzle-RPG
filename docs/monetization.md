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
| Banner | Hall, Areas, Shop, History, Credits, Codex | Bottom of those menus only, anchored above the system navigation bar. Never battle, map, events, story or the tutorial. |
| Interstitial | Leaving the reward screen for the map | Capped: skips the first 3 wins of the install, then at most one per 3 battles **and** per 150s. Never after a boss clear, and never within 2 min of another full-screen ad. |
| Rewarded — Second Wind | Defeat screen | Opt-in. Revive at 50% HP, once per run, offered *before* the run is failed. |
| Rewarded — Open a realm | Expedition select | Opt-in. Opens only the **next** sealed realm, never further ahead. |
| Rewarded — Reroll reward | Upgrade/relic choice | Opt-in. One reshuffle per battle; the roll is a serialized permutation so the new spread is genuinely different. |
| Rewarded — Multiply crystals | Run-end screen | Opt-in, once per run. Only ever adds on top of what was earned. |

All caps live in `data/ads.json` — change them there, not in code.

Full-screen formats share a two-minute cooldown in both directions, so a
rewarded ad a player chose can never be followed immediately by an
interstitial they did not. Two ads inside a minute is what draws one-star
reviews; the daily total matters much less.

## Realm progression

The paywall is gone. Realms open by clearing the previous realm's boss
(`SaveSystem.record_area_clear`), and a rewarded ad can open the next one early
(`SaveSystem.unlock_area_early`, which refuses to skip ahead).

Players who bought the old **Full Campaign Unlock** are migrated at save
version 13: they keep every realm they paid for **and** get Remove Ads for free.

## Live configuration

### 1. AdMob console

The Potion Rogue app and its production units are configured as
follows:

| Item | Value |
| --- | --- |
| App ID | `ca-app-pub-6279186647593327~2300822678` |
| Banner | `ca-app-pub-6279186647593327/2085929206` |
| Interstitial | `ca-app-pub-6279186647593327/5833602524` |
| Rewarded | `ca-app-pub-6279186647593327/6763540816` |

App Open stays retired and its release unit ID is empty. Banner, interstitial
and rewarded units are live while `test_mode` is `false`. The production values
are in `data/ads.json`. Local/debug runs are forced to Google's test units by
`src/autoload/admob_runtime.gd`; never click live ads while testing.

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
`1.7.12` / version code `42`.

## Banner safe area

The Android export runs edge-to-edge with `screen/immersive_mode=false`. That
combination is deliberate: while immersive mode hid the navigation bar, every
safe-area query in the stack reported a bottom inset of `0`, so the AdMob plugin
anchored the banner to the physical bottom of the screen — directly underneath
the back / home / recents buttons, where a swipe up from the bottom edge both
reveals those buttons and counts as an ad impression.

With the bars visible the plugin's own `anchor_to_safe_area` still reads the
real inset and lifts the banner above the navigation bar on its own.
`UiKit.safe_margin()` then reserves the same chrome for the game's own content,
using `DisplayServer.get_display_safe_area()` converted from screen pixels into
the viewport units every layout is written in. Reverting to immersive mode puts
the banner back on top of the navigation buttons.

## Verified on device

A debug build (Google test units, Redmi Note 11 / Android 13) confirmed the
rewarded, interstitial, and menu-banner paths. App Open stays disabled in the
production policy. Menu layout reserves bottom space only when a banner can
actually appear.

The 1.7.12 build was checked on the same device while the fix was in flight.
The plugin now logs `Anchor to Safe Area: Insets (T, B, L, R) in Pixels: 93,
130, 0, 0` — against `93, 0, 0, 0` before — and the screenshot shows the
navigation buttons clear of the banner instead of drawn across its call to
action.

## Verifying without ads

`tests/ad_service_test.tscn` asserts the no-plugin path stays inert, App Open
stays disabled, banners stay on menus only, and the frequency caps remain sane. Run it with
the rest of the suite:

```bash
godot --headless --path . tests/ad_service_test.tscn
```
