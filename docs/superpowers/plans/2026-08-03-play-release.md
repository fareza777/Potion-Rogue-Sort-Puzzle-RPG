# Potion Rogue Play Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a verified English-first Google Play closed-testing package for Potion Rogue with a US$4.99 full-campaign entitlement, public privacy policy, eight screenshots, and a Remotion promo video.

**Architecture:** A `BillingService` autoload owns the Android plugin boundary and exposes entitlement, product, purchase, restore, and status signals to the game. `SaveSystem` stores only the cached entitlement and migration state; `AreaSelectScreen` and `SettingsScreen` consume the service without knowing Google Play APIs. Store assets and the privacy page live in reproducible release folders, while a separate Remotion composition renders a video from real game captures.

**Tech Stack:** Godot 4.x / GDScript, GodotGooglePlayBilling 3.3.0, Android Gradle export, PowerShell asset tooling, static HTML privacy page, Remotion, Play Console, YouTube.

## Global Constraints

- All user-facing copy, store listing copy, captions, video text, and privacy policy text must be English.
- Product ID is `potion_rogue_full_campaign`; product type is one-time non-consumable; price is US$4.99.
- The app remains free; Shadow Crypt is always playable and later realms unlock after a confirmed purchase.
- A purchase never auto-completes realms, grants mastery, grants Ascension, or changes existing progress.
- Pending, canceled, unavailable, and failed purchases never grant access.
- Desktop/editor/headless runs must remain usable when the Android BillingClient class is unavailable.
- All screenshots and video frames must use shipped game art and actual current scenes.
- The final requested stopping point is closed-testing setup; do not submit production access or publish a public release.
- Never commit signing keys, credentials, browser session data, or source-control tokens.

---

### Task 1: Add the versioned campaign entitlement model

**Files:**
- Modify: `src/autoload/save_system.gd`
- Modify: `src/ui/area_select_screen.gd`
- Create: `tests/campaign_entitlement_test.gd`
- Create: `tests/campaign_entitlement_test.tscn`

**Interfaces:**
- `SaveSystem.full_campaign_unlocked() -> bool`
- `SaveSystem.set_full_campaign_unlocked(value: bool) -> void`
- `SaveSystem.DEFAULT_DATA["full_campaign_unlocked"] == false`
- `SaveSystem.SAVE_VERSION` increments from 11 to 12 with a migration that defaults the new key to false.
- `SaveSystem.is_area_unlocked(area_id)` returns true for every valid area only when the entitlement is true; the free default remains Shadow Crypt.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_fresh_profile_only_has_shadow_crypt() -> void:
	var save := SaveSystem.new()
	var payload := save.migrate({"version": 11, "unlocked_areas": ["shadow_crypt"]})
	assert(not bool(payload.get("full_campaign_unlocked", false)))

func test_entitlement_unlocks_all_authored_areas_without_completing_them() -> void:
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	SaveSystem.set_full_campaign_unlocked(true)
	for area_id in GameState.area_ids():
		assert(SaveSystem.is_area_unlocked(str(area_id)))
	assert(SaveSystem.completed_areas().is_empty())

func test_invalid_area_is_never_unlocked_by_entitlement() -> void:
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	SaveSystem.set_full_campaign_unlocked(true)
	assert(not SaveSystem.is_area_unlocked("not_an_area"))
```

- [ ] **Step 2: Run the focused scene and verify it fails**

Run: `godot --headless --path . res://tests/campaign_entitlement_test.tscn`

Expected: FAIL because the entitlement key and accessors do not yet exist.

- [ ] **Step 3: Implement the minimal migration and accessors**

Add the default key, migration branch, accessors, and a guarded area-access check. Preserve existing unlocked/completed arrays and never write completion records when the entitlement is granted.

- [ ] **Step 4: Run the focused scene and verify it passes**

Run: `godot --headless --path . res://tests/campaign_entitlement_test.tscn`

Expected: PASS with zero assertion failures.

- [ ] **Step 5: Commit the entitlement model**

Run: `git add src/autoload/save_system.gd src/ui/area_select_screen.gd tests/campaign_entitlement_test.gd tests/campaign_entitlement_test.tscn && git commit -m "feat: add full campaign entitlement state"`

---

### Task 2: Integrate Google Play Billing behind a service boundary

**Files:**
- Create: `addons/GodotGooglePlayBilling/` from the signed upstream 3.3.0 release archive
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Create: `src/autoload/billing_service.gd`
- Create: `tests/billing_service_test.gd`
- Create: `tests/billing_service_test.tscn`
- Modify: `README.md`

**Interfaces:**
- `BillingService.PRODUCT_ID == "potion_rogue_full_campaign"`
- `BillingService.is_available() -> bool`
- `BillingService.is_entitled() -> bool`
- `BillingService.product_title() -> String`
- `BillingService.product_price() -> String`
- `BillingService.purchase_full_campaign() -> void`
- `BillingService.restore_purchases() -> void`
- Signals: `entitlement_changed(unlocked: bool)`, `status_changed(message: String)`, `purchase_available(available: bool)`.

- [ ] **Step 1: Install the official plugin release**

Download the `3.3.0` release archive from `godot-sdk-integrations/godot-google-play-billing`, verify the extracted plugin contains its Android plugin metadata and `BillingClient` script, then place it under `addons/GodotGooglePlayBilling/`. Do not add build outputs or credentials to Git.

- [ ] **Step 2: Write headless service tests with a deterministic fake backend**

The tests must exercise `PURCHASED`, `PENDING`, `CANCELED`, unavailable-plugin, and restore paths through a fake adapter or injected response dictionaries. They must assert that only a purchased product containing `potion_rogue_full_campaign` grants the entitlement and that a pending product never does.

- [ ] **Step 3: Run the billing tests and verify the red state**

Run: `godot --headless --path . res://tests/billing_service_test.tscn`

Expected: FAIL because `BillingService` and the fake adapter do not yet exist.

- [ ] **Step 4: Implement the service boundary**

On Android, instantiate `BillingClient`, connect `connected`, `disconnected`, `connect_error`, `query_product_details_response`, `query_purchases_response`, `on_purchase_updated`, and `acknowledge_purchase_response`, then call `start_connection()`. Query `ProductType.INAPP`, launch `purchase(PRODUCT_ID)` only after product details succeed, process only `PurchaseState.PURCHASED`, call `acknowledge_purchase(purchase_token)` when needed, and query purchases again from `NOTIFICATION_APPLICATION_RESUMED`/app resume. On other platforms, expose unavailable state without referencing an undefined class.

- [ ] **Step 5: Enable Android Gradle export and register the autoload**

Enable the Android Gradle build option required by the plugin, register `BillingService` in `[autoload]`, keep the existing package name, and add a release-oriented Android App Bundle preset without changing the existing debug preset's behavior.

- [ ] **Step 6: Run billing tests and the project parser**

Run: `godot --headless --path . res://tests/billing_service_test.tscn`  
Run: `godot --headless --editor --quit --path .`

Expected: both exit 0; desktop execution must not attempt a Google Play connection.

- [ ] **Step 7: Commit the billing boundary**

Run: `git add addons project.godot export_presets.cfg src/autoload/billing_service.gd tests/billing_service_test.gd tests/billing_service_test.tscn README.md && git commit -m "feat: integrate Google Play campaign billing"`

---

### Task 3: Wire purchase and restore UI into the game

**Files:**
- Modify: `src/ui/area_select_screen.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `src/ui/credits_screen.gd`
- Create: `src/ui/components/campaign_unlock_card.gd`
- Modify: `tests/accessibility_test.gd`
- Create: `tests/campaign_unlock_ui_test.gd`
- Create: `tests/campaign_unlock_ui_test.tscn`

**Interfaces:**
- `CampaignUnlockCard.configure(available: bool, entitled: bool, price: String) -> void`
- `CampaignUnlockCard.purchase_requested` signal
- `CampaignUnlockCard.restore_requested` signal

- [ ] **Step 1: Write failing UI contract tests**

Assert that locked later realms expose an English unlock explanation, that Buy is disabled when Billing is unavailable, that Restore Purchase is visible in Settings, that the entitled state says `FULL CAMPAIGN UNLOCKED`, and that no purchase UI hides Shadow Crypt.

- [ ] **Step 2: Run the focused UI scene and verify failure**

Run: `godot --headless --path . res://tests/campaign_unlock_ui_test.tscn`

Expected: FAIL because the card and BillingService wiring do not exist.

- [ ] **Step 3: Implement the reusable unlock card**

Use the existing `UiKit` and minimum touch-size conventions. All visible copy must be English. Show `UNLOCK ALL FIVE REALMS` and `FULL CAMPAIGN UNLOCK  •  $4.99` only when product data is available; show `Restore Purchase` as a separate action.

- [ ] **Step 4: Connect Area Select, Settings, and Credits**

Area Select refreshes when `entitlement_changed` fires. Settings exposes Restore Purchase and the privacy-policy link. Credits exposes the same policy link so the policy remains reachable from inside the app.

- [ ] **Step 5: Run focused UI and accessibility checks**

Run: `godot --headless --path . res://tests/campaign_unlock_ui_test.tscn`  
Run: `godot --headless --path . res://tests/accessibility_test.tscn`

Expected: PASS with no undersized action or untranslated purchase copy.

- [ ] **Step 6: Commit the purchase UI**

Run: `git add src/ui/area_select_screen.gd src/ui/settings_screen.gd src/ui/credits_screen.gd src/ui/components/campaign_unlock_card.gd tests/accessibility_test.gd tests/campaign_unlock_ui_test.gd tests/campaign_unlock_ui_test.tscn && git commit -m "feat: add campaign unlock purchase UI"`

---

### Task 4: Create and publish the English privacy policy and store assets

**Files:**
- Create: `privacy-policy/index.html`
- Modify: `store-assets/README.md`
- Create: `store-assets/store-listing-copy.md`
- Create or modify: `store-assets/screenshots/06-event-choice.png`
- Create or modify: `store-assets/screenshots/07-area-select.png`
- Create or modify: `store-assets/screenshots/08-reaction-codex.png`
- Modify: `store-assets/build_feature_graphic.ps1`
- Create: `tools/validate_store_assets.ps1`

**Interfaces:**
- Public privacy URL resolves to the deployed English `privacy-policy/index.html`.
- Store copy file contains the exact title, short description, full description,
  screenshot order, and alt text used in Play Console.
- `tools/validate_store_assets.ps1` exits 0 only when eight screenshots, the
  feature graphic, and their dimensions/file sizes are valid.

- [ ] **Step 1: Write the privacy policy and listing copy**

Use the approved English copy in the design spec. The privacy page must explain local save data, no developer collection/sharing, Google Play Billing processing, retention/deletion, developer identity, and a public privacy-contact mechanism without inventing a personal email address.

- [ ] **Step 2: Capture the three missing screenshots**

Use the existing deterministic DevTools capture flow or a Godot scene runner to capture an event choice, area selection, and reaction codex state from shipped scenes. Keep the captures portrait, English, truthful, and free of external device frames or invented promotional overlays.

- [ ] **Step 3: Add the validation script and run it red/green**

Run: `powershell -ExecutionPolicy Bypass -File .\tools\validate_store_assets.ps1`

Expected: it reports any missing screenshot before capture and exits 0 after all eight files and the 1024x500 feature graphic are present.

- [ ] **Step 4: Build or publish the static privacy page**

Use the Sites hosting path for a publicly accessible, non-geofenced HTML page. Verify the final URL returns status 200 and contains the exact English policy before entering it into Play Console. Keep the local HTML source in the repo.

- [ ] **Step 5: Commit the privacy and creative package**

Run: `git add privacy-policy store-assets tools/validate_store_assets.ps1 && git commit -m "feat: prepare English Play listing assets"`

---

### Task 5: Render the Remotion promotion video

**Files:**
- Create: `promo-video/package.json`
- Create: `promo-video/remotion.config.ts`
- Create: `promo-video/src/Root.tsx`
- Create: `promo-video/src/PromoVideo.tsx`
- Create: `promo-video/public/` with copied real screenshots and feature graphic
- Create: `promo-video/README.md`
- Create: `store-assets/potion-rogue-promo.mp4`

**Interfaces:**
- Composition ID: `PotionRoguePromo`
- Duration: 30 seconds at 30 fps
- Output: 1920x1080 H.264 MP4
- All text on screen is English and matches the store listing.

- [ ] **Step 1: Add the Remotion composition**

Sequence the hook, sort-to-attack, build choices, five-realm campaign, boss payoff, and end card. Use actual screenshots with gentle zoom/pan and readable typography; do not imply online multiplayer, live service, or features not in the game.

- [ ] **Step 2: Install dependencies and render**

Run from `promo-video`: `npm install` then `npx remotion render src/index.ts PotionRoguePromo ../store-assets/potion-rogue-promo.mp4 --codec=h264`

Expected: exit 0 and an MP4 with the planned resolution, duration, and non-zero file size.

- [ ] **Step 3: Inspect the rendered file**

Use the bundled media metadata/thumbnail tooling to verify the MP4 opens, has no blank frames, and contains the final English end card. Re-render once if a validation issue is found.

- [ ] **Step 4: Commit the video source and verified output**

Run: `git add promo-video store-assets/potion-rogue-promo.mp4 && git commit -m "feat: add Remotion Play promo video"`

---

### Task 6: Build, verify, and configure Play Console through closed testing

**Files:**
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Modify: `docs/TECHNICAL_DESIGN.md`
- Modify: `README.md`
- Create: `docs/releases/1.6.2.md`

- [ ] **Step 1: Increment the Android release version**

Set the project/export version to the next version code and version name without changing the package name. Ensure the App Bundle preset uses the same values.

- [ ] **Step 2: Run the complete verification matrix**

Run: `godot --headless --editor --quit --path .`  
Run: `for ($scene in Get-ChildItem tests -Filter '*_test.tscn') { godot --headless --path . $scene.FullName }`  
Run: `powershell -ExecutionPolicy Bypass -File .\tools\validate_release.ps1 -ProjectRoot .`

Expected: every command exits 0; record any environment-limited Android/plugin limitation explicitly instead of claiming it passed.

- [ ] **Step 3: Export and inspect the Android App Bundle**

Export the signed AAB, verify its package name, version code, version name, signing presence, and size. Do not upload an APK when Play Console requests an App Bundle.

- [ ] **Step 4: Create the Play Console app**

Create a free Game using `Potion Rogue: Sort Puzzle RPG`, package `com.farezagames.potionrogue`, English (United States), and the two required declarations. Stop and record the resulting app dashboard URL.

- [ ] **Step 5: Add the one-time product**

In Monetize with Play, create `potion_rogue_full_campaign` as a one-time non-consumable product named `Full Campaign Unlock`, set the default price to US$4.99, and keep it available for testing.

- [ ] **Step 6: Fill the English store listing and privacy policy**

Enter the approved title, short/full descriptions, icon, feature graphic, eight screenshots with unique English alt text, promo video URL, and verified privacy URL. Keep the listing claims consistent with the game and entitlement behavior.

- [ ] **Step 7: Complete Data safety and app content**

Declare the offline/local-save behavior accurately, identify Google Play Billing as the purchase processor where the form requires it, add the privacy URL, and complete the content declarations without inventing analytics, ads, accounts, or collected user data.

- [ ] **Step 8: Upload the closed-testing release and copy Vocatim testers**

Upload the signed AAB to the Alpha closed-testing track. Configure the same four Google Group addresses currently used by Vocatim, preserve the existing feedback address only if it is already the developer's configured contact, and save the tester configuration. Do not submit production access.

- [ ] **Step 9: Verify the stopping point**

Re-read the Play Console pages and record evidence for: app created, product configured, listing saved, privacy URL reachable, data safety saved, Alpha track present, tester groups saved, and release available to selected testers. Leave the Play Console tab at the closed-testing page for handoff.

- [ ] **Step 10: Commit release documentation**

Run: `git diff --check` and then `git add project.godot export_presets.cfg docs/TECHNICAL_DESIGN.md README.md docs/releases/1.6.2.md && git commit -m "release: prepare Potion Rogue closed testing"`

---

## Plan self-review

- Billing covers product query, purchase, restore, pending/cancel/error, and acknowledgement.
- Entitlement covers all five authored realms without changing campaign completion.
- Store listing covers English metadata, eight screenshots, feature graphic, video, privacy, and data safety.
- Verification covers parser, focused tests, full regression, asset checks, video metadata, bundle metadata, and Play Console state.
- No step depends on a placeholder, secret, invented contact address, or production submission.
