# Story Flow, Credits, and Guide Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver one generated entry painting per encounter, release-ready Credits/rating links, and a concise ornate-safe Guide page.

**Architecture:** Keep story content and rendering systems intact while narrowing which screens invoke full-screen storyboards. Keep Guide copy data-backed, but replace paragraph-shaped `copy` values with structured `what`, `how`, and `note` facts rendered inside a dedicated safe margin. Keep external URLs centralized in `AppLinks`.

**Tech Stack:** Godot 4.7.1, GDScript, scene-based headless regression tests, Android Gradle export.

## Global Constraints

- Do not change first-run onboarding, combat balance, enemy art, or generated paintings.
- Show at most one full-screen generated painting when entering an encounter.
- Credits must show the exact line `Created by F7 Developer`.
- Google Play rating URL is `https://play.google.com/store/apps/details?id=com.farezagames.potionrogue`.
- Guide targets 576×1280 and retains full-area drag scrolling with hidden scrollbars.
- Guide inner card margins are at least 34 px left/right, 24 px top, and 26 px bottom.
- Preserve untracked `builds/`, `review_shots/`, and store screenshot files.

---

### Task 1: Enforce one full-screen painting per encounter

**Files:**
- Modify: `tests/gameplay_integration_test.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/battle_screen.gd`

**Interfaces:**
- Consumes: `StoryboardService.play(trigger: String, context: Dictionary)`.
- Produces: battle entry trigger `battle_intro`, event entry trigger `event_reveal`, and inline-only battle escalation feedback.

- [ ] **Step 1: Write the failing trigger-policy assertions**

```gdscript
check(map_source.count('StoryboardService.play("battle_intro"') == 1,
        "battle entry owns one generated painting")
check(not map_source.contains('StoryboardService.play("route_choice"'),
        "map does not prepend a duplicate route painting")
check(event_source.contains('StoryboardService.play("event_reveal"')
        and not event_source.contains('StoryboardService.play("event_resolution"'),
        "event owns one reveal painting and resolves inline")
check(not battle_source.contains('StoryboardService.play("battle_escalation"'),
        "battle phases stay inside the battle presentation")
check(battle_source.contains("play_phase_transition")
        and battle_source.contains("enemy_display.play_intro()"),
        "boss phases and waves retain inline feedback")
```

- [ ] **Step 2: Run the test and verify the old multi-trigger behavior fails**

Run:

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/gameplay_integration_test.tscn
```

Expected: non-zero exit with failures for `route_choice`, `event_resolution`, and `battle_escalation`.

- [ ] **Step 3: Remove only the duplicate full-screen calls**

```gdscript
# map_screen.gd
if node.kind in ["battle", "elite", "boss"]:
    await StoryboardService.play("battle_intro", story_context)

# event_screen.gd: keep _play_event_reveal(); resolve _choose() inline.

# battle_screen.gd: remove StoryboardService.play("battle_escalation", ...)
# while retaining warning messages, play_phase_transition(), impact, music,
# enemy configure, and enemy_display.play_intro().
```

- [ ] **Step 4: Re-run the trigger-policy test**

Expected: all gameplay integration checks pass.

- [ ] **Step 5: Commit**

```powershell
git add tests/gameplay_integration_test.gd src/ui/map_screen.gd src/ui/event_screen.gd src/ui/battle_screen.gd
git commit -m "fix: prevent duplicate encounter story art"
```

### Task 2: Make Credits and rating links release-ready

**Files:**
- Create: `tests/credits_store_test.gd`
- Create: `tests/credits_store_test.tscn`
- Modify: `src/autoload/app_links.gd`
- Modify: `src/ui/credits_screen.gd`
- Modify: `src/ui/settings_screen.gd`

**Interfaces:**
- Produces: `AppLinks.PLAY_STORE_URL: String` and buttons named `RateOnPlayStoreButton`.

- [ ] **Step 1: Add a failing source-and-scene contract test**

```gdscript
check(AppLinks.PLAY_STORE_URL ==
        "https://play.google.com/store/apps/details?id=com.farezagames.potionrogue",
        "rating uses the production Play Store listing")
var credits_source := FileAccess.get_file_as_string("res://src/ui/credits_screen.gd")
check(credits_source.contains("Created by F7 Developer"), "creator line is exact")
check(not credits_source.contains("FAREZA GAMES")
        and not credits_source.contains("Built with Godot"),
        "credits omit internal production copy")
```

Instantiate both scenes and assert each contains `RateOnPlayStoreButton`.

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/credits_store_test.tscn
```

Expected: missing URL/button/creator-line failures.

- [ ] **Step 3: Add the centralized URL and two rating buttons**

```gdscript
const PLAY_STORE_URL := \
        "https://play.google.com/store/apps/details?id=com.farezagames.potionrogue"

var rate := UiKit.button("RATE ON GOOGLE PLAY", Vector2(300, 52), Color("f0bd4f"))
rate.name = "RateOnPlayStoreButton"
rate.pressed.connect(func() -> void: OS.shell_open(AppLinks.PLAY_STORE_URL))
```

Credits retain only title, tagline, creator line, rate, privacy, and return actions. Settings places rate beside privacy under `STORE & CAMPAIGN`.

- [ ] **Step 4: Re-run the test**

Expected: all Credits/store checks pass.

- [ ] **Step 5: Commit**

```powershell
git add tests/credits_store_test.gd tests/credits_store_test.tscn src/autoload/app_links.gd src/ui/credits_screen.gd src/ui/settings_screen.gd
git commit -m "feat: add release-ready credits and rating links"
```

### Task 3: Replace Guide paragraphs with structured concise lessons

**Files:**
- Modify: `tests/guide_content_test.gd`
- Modify: `src/guide/guide_content.gd`

**Interfaces:**
- Produces: each section has `summary: String`; each card has `title: String` and at least two of `what`, `how`, `note`.
- Preserves: `GuideContent.sections()`, `section(id)`, `kit_cards()`, `skill_effect()`, and `ultimate_effect()`.

- [ ] **Step 1: Write failing structure and copy-budget checks**

```gdscript
for section in GuideContent.sections():
    var summary := str(section.get("summary", ""))
    check(not summary.is_empty() and summary.length() <= 120,
            "%s summary is concise" % section.title)
    check(not section.has("body"), "%s has no wall-of-text body" % section.title)
    for card in section.cards:
        var facts := 0
        for key in ["what", "how", "note"]:
            var value := str(card.get(key, ""))
            if not value.is_empty():
                facts += 1
                check(value.length() <= 120, "%s %s copy is bounded" % [card.title, key])
        check(facts >= 2, "%s has actionable facts" % card.title)
```

Also assert Reactions mention history and order, Basics cover all four colors, and kit cards retain cost/cooldown/Ultimate facts.

- [ ] **Step 2: Run the test and verify paragraph-shaped data fails**

Run the `guide_content_test.tscn`; expect failures for missing `summary`/fact keys and legacy `body`.

- [ ] **Step 3: Rewrite the five sections with short factual fields**

Use direct copy such as:

```gdscript
{"title":"POUR A POTION",
 "what":"Move connected top layers into an empty or matching flask.",
 "how":"Tap the source flask, then tap the destination.",
 "note":"Each successful pour advances the enemy countdown."}
```

Generate potion, reaction, and kit cards using the same schema and live `GameState` values. Add separate `UNDO & NEW MIX` and `REACTION CHAMBER` cards so rules are discoverable without repeating section summaries.

- [ ] **Step 4: Re-run `guide_content_test.tscn`**

Expected: all content structure and semantic checks pass.

- [ ] **Step 5: Commit**

```powershell
git add tests/guide_content_test.gd src/guide/guide_content.gd
git commit -m "refactor: make guide lessons concise and actionable"
```

### Task 4: Keep Guide text inside the ornate safe area

**Files:**
- Modify: `tests/guide_navigation_test.gd`
- Modify: `src/ui/guide_screen.gd`

**Interfaces:**
- Produces: `GuideSectionSummary`, one `GuideCardSafeContent` per card, and fact rows named `GuideFact_<key>`.
- Preserves: `open_section(id)`, `FormulaCodexButton`, `ReturnButton`, and full-area drag scrolling.

- [ ] **Step 1: Write failing layout contracts**

Instantiate the Guide, open all five sections, wait two frames, and verify:

```gdscript
check(guide.find_child("GuideSectionSummary", true, false) is Label,
        "Guide exposes a concise section summary")
for card in guide.find_children("GuideLessonCard_*", "PanelContainer", true, false):
    var safe := card.find_child("GuideCardSafeContent", true, false) as MarginContainer
    check(safe != null, "%s owns an inner safe area" % card.name)
    check(safe.get_theme_constant("margin_left") >= 34
            and safe.get_theme_constant("margin_right") >= 34,
            "%s clears the ornate side points" % card.name)
```

Assert vertical and horizontal scroll modes are `SCROLL_MODE_SHOW_NEVER`, and simulate drag input inside the content region to confirm the vertical offset changes when content exceeds the viewport.

- [ ] **Step 2: Run the navigation test and verify missing safe-layout nodes fail**

Run `guide_navigation_test.tscn`; expected non-zero exit before implementation.

- [ ] **Step 3: Build the safe card renderer**

Inside each textured panel, add:

```gdscript
var safe := MarginContainer.new()
safe.name = "GuideCardSafeContent"
safe.add_theme_constant_override("margin_left", 38)
safe.add_theme_constant_override("margin_right", 38)
safe.add_theme_constant_override("margin_top", 24)
safe.add_theme_constant_override("margin_bottom", 28)
card.add_child(safe)
```

Render the title and non-empty `WHAT`, `HOW`, `NOTE` facts as separate wrapping rows. Set `_intro.name = "GuideSectionSummary"`, use `summary`, cap visible summary lines at two, and let card height grow naturally. Keep `_input()` drag routing and hidden scrollbars.

- [ ] **Step 4: Run Guide tests and render every section at 576×1280**

Run both Guide test scenes. Launch `scenes/guide.tscn` with a temporary capture selector or test harness, capture each section into `review_shots/guide-polish/`, and inspect that labels stay inside safe margins with no overlap or clipping.

- [ ] **Step 5: Commit**

```powershell
git add tests/guide_navigation_test.gd src/ui/guide_screen.gd
git commit -m "fix: keep guide copy clear of ornate frames"
```

### Task 5: Regression, Android build, and delivery

**Files:**
- Modify only generated Godot `.import` sidecars if the editor legitimately refreshes them.
- Produce untracked: `builds/PotionRogue-v1.6.4-debug.apk`.

**Interfaces:**
- Produces: verified installable package `com.farezagames.potionrogue` version `1.6.4`.

- [ ] **Step 1: Parse-check and run targeted suites**

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
$tests = 'gameplay_integration_test','credits_store_test','guide_content_test','guide_navigation_test','storyboard_director_test','story_art_catalog_test'
foreach ($name in $tests) {
  & '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . "res://tests/$name.tscn"
  if ($LASTEXITCODE -ne 0) { throw "$name failed" }
}
```

- [ ] **Step 2: Run the complete non-long test matrix**

Enumerate every `tests/*_test.tscn`, excluding only an explicitly long balance simulation, and require exit code zero for each scene.

- [ ] **Step 3: Export and validate the APK**

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-debug 'Android Debug' 'builds/PotionRogue-v1.6.4-debug.apk'
& '.\tools\validate_release.ps1'
Get-FileHash 'builds/PotionRogue-v1.6.4-debug.apk' -Algorithm SHA256
```

Expected: export exit zero, validator passes, signing/package/version are valid, and SHA-256 is reported.

- [ ] **Step 4: Inspect final diff and push `main`**

```powershell
git diff --check
git status --short
git push origin main
```

Expected: only intended tracked files are committed; user screenshots and build artifacts remain untracked; push succeeds.
