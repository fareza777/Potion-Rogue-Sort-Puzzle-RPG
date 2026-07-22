# Player Guide and Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a six-chapter animated onboarding, a permanent in-game Guide, expanded contextual battle teaching, and exact explanations for Reaction Chamber dots, Mana, skills, and ultimates.

**Architecture:** `GuideContent` converts authoritative potion, combo, and kit data into immutable presentation models. `GuideScreen` and `OnboardingDemo` render that material independently from combat, while `TutorialDirector` continues to own persisted action progression. Main-menu and battle navigation enter the Guide through a return-context value that never advances a run.

**Tech Stack:** Godot 4.7.1, GDScript, programmatic `Control` UI, JSON game data, headless scene tests, Android export pipeline.

## Global Constraints

- Existing players are never forced through onboarding again.
- Color meaning is repeated in text and never communicated by color alone.
- Reduced Effects replaces continuous animation with immediate state changes.
- All guide content supports touch-drag scrolling at 576×1280 and 720×1280.
- Opening help from battle cannot mutate, advance, or abandon the encounter.
- Tutorial highlight layers must pass pointer input to required battle controls.
- No new external runtime dependency is added.

---

### Task 1: Authoritative Guide Content

**Files:**
- Create: `src/guide/guide_content.gd`
- Create: `tests/guide_content_test.gd`
- Create: `tests/guide_content_test.tscn`

**Interfaces:**
- Consumes: `GameState.potions`, `GameState.combos`, `GameState.kits`.
- Produces: `GuideContent.sections() -> Array[Dictionary]`, `GuideContent.section(id: String) -> Dictionary`, and `GuideContent.kit_cards() -> Array[Dictionary]`.

- [ ] **Step 1: Write the failing content contract test**

```gdscript
extends Node
func _ready() -> void:
	var ids := GuideContent.sections().map(func(item): return item.id)
	assert(ids == ["basics", "reactions", "skills", "battle", "expedition"])
	assert(str(GuideContent.section("reactions").body).contains("last three"))
	assert(str(GuideContent.section("reactions").body).contains("order"))
	assert(GuideContent.kit_cards().size() == GameState.kits.size())
	for card in GuideContent.kit_cards():
		assert(card.has("cost") and card.has("cooldown") and card.has("ultimate"))
	get_tree().quit()
```

- [ ] **Step 2: Verify the content test is red**

Run: `& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/guide_content_test.tscn`

Expected: parser failure because `GuideContent` does not exist.

- [ ] **Step 3: Implement the content model**

```gdscript
class_name GuideContent
extends RefCounted

static func sections() -> Array[Dictionary]:
	return [
		{"id":"basics", "title":"BASICS", "body":"Tap a source flask, then a matching or empty destination..."},
		{"id":"reactions", "title":"REACTIONS", "body":"The three dots store your last three completed potion essences. Order matters..."},
		{"id":"skills", "title":"SKILLS", "body":"Completed potions generate Mana for active skills..."},
		{"id":"battle", "title":"BATTLE", "body":"Each successful pour advances the enemy intent countdown..."},
		{"id":"expedition", "title":"EXPEDITION", "body":"Every run generates hidden routes..."},
	]

static func section(id: String) -> Dictionary:
	for item in sections():
		if item.id == id: return item.duplicate(true)
	return sections()[0].duplicate(true)
```

`kit_cards()` reads each kit's `active`, `cost`, `cooldown`, passive, and ultimate fields and returns safe fallback strings for missing optional copy.

- [ ] **Step 4: Run the content test green**

Run the Task 1 command. Expected: all Guide content checks pass with exit code 0.

- [ ] **Step 5: Commit Task 1**

```powershell
git add src/guide/guide_content.gd tests/guide_content_test.gd tests/guide_content_test.tscn
git commit -m "feat: add authoritative player guide content"
```

### Task 2: Permanent Guide Screen and Navigation

**Files:**
- Create: `src/ui/guide_screen.gd`
- Create: `scenes/guide.tscn`
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/battle_screen.gd`
- Create: `tests/guide_navigation_test.gd`
- Create: `tests/guide_navigation_test.tscn`

**Interfaces:**
- Consumes: `GuideContent.sections()` and `RunState.resume_scene()`.
- Produces: Guide scene nodes `GuideTabs`, `GuideScroll`, `GuideCards`, `FormulaCodexButton`, and `ReturnButton`; `GuideScreen.open_section(id: String)`.

- [ ] **Step 1: Write the failing navigation test**

```gdscript
var guide := load("res://scenes/guide.tscn").instantiate()
add_child(guide)
await get_tree().process_frame
assert(guide.find_child("GuideScroll", true, false) is ScrollContainer)
assert(guide.find_child("GuideTabs", true, false) != null)
assert(guide.find_child("FormulaCodexButton", true, false) != null)
var menu_source := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
assert(menu_source.contains('"GUIDE"'))
assert(battle_source.contains('name = "BattleGuideButton"'))
```

- [ ] **Step 2: Verify the navigation test is red**

Run: `& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/guide_navigation_test.tscn`

Expected: failure because `scenes/guide.tscn` is absent.

- [ ] **Step 3: Build the responsive Guide screen**

Create a full-height background, header, horizontally scrollable tab row, vertically draggable content viewport, reusable framed cards, formula link, and Return button. `open_section()` updates tab state and rebuilds only the card list. Return uses `RunState.resume_scene()` when a run is active and otherwise returns to `main_menu.tscn`.

- [ ] **Step 4: Add both entry points**

Add a large `GUIDE` secondary command to the main menu. Add a 52×52 `?` button named `BattleGuideButton` to battle; before navigation call the existing encounter checkpoint API, then change to `guide.tscn`.

- [ ] **Step 5: Run navigation and lifecycle tests**

Run:

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/guide_navigation_test.tscn
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/run_lifecycle_test.tscn
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/battle_input_workflow_test.tscn
```

Expected: Guide, lifecycle, and 20 battle-input checks pass.

- [ ] **Step 6: Commit Task 2**

```powershell
git add src/ui/guide_screen.gd scenes/guide.tscn src/ui/main_menu.gd src/ui/battle_screen.gd tests/guide_navigation_test.*
git commit -m "feat: add permanent guide navigation"
```

### Task 3: Six-Chapter Animated Onboarding

**Files:**
- Create: `src/ui/components/onboarding_demo.gd`
- Modify: `src/ui/onboarding_screen.gd`
- Create: `tests/onboarding_complete_test.gd`
- Create: `tests/onboarding_complete_test.tscn`

**Interfaces:**
- Consumes: chapter dictionaries from `OnboardingScreen.PAGES` and `SaveSystem.setting("reduced_effects")`.
- Produces: `OnboardingDemo.show_chapter(id: String, reduced_effects: bool)` and visual node `OnboardingDemo`.

- [ ] **Step 1: Write the failing onboarding contract**

```gdscript
var source := FileAccess.get_file_as_string("res://src/ui/onboarding_screen.gd")
for chapter in ["sort", "brew", "survive", "react", "cast", "explore"]:
	assert(source.contains('"id":"%s"' % chapter))
var scene := load("res://scenes/onboarding.tscn").instantiate()
add_child(scene)
await get_tree().process_frame
assert(scene.find_child("OnboardingDemo", true, false) != null)
```

- [ ] **Step 2: Verify the onboarding test is red**

Run the new `onboarding_complete_test.tscn`. Expected: missing six chapters and `OnboardingDemo`.

- [ ] **Step 3: Implement procedural demonstrations**

Render bottle silhouettes, layered essence rectangles, enemy intent pips, three reaction sockets, Mana/Skill meters, and route nodes using `Control._draw()`. Animate state using one bounded tween per chapter. When Reduced Effects is enabled, draw the final state immediately and create no looping tween.

- [ ] **Step 4: Expand and polish the onboarding page controller**

Replace the three cards with six authored pages, insert `OnboardingDemo` above the explanation card, crossfade copy and accent colors, retain Back/Next/Skip, and keep `SaveSystem.mark_onboarding_done()` unchanged.

- [ ] **Step 5: Run onboarding, accessibility, and viewport tests**

Run:

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/onboarding_complete_test.tscn
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/accessibility_complete_test.tscn
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/mobile_viewport_matrix_test.tscn
```

Expected: all three scenes exit 0 with no assertion failure.

- [ ] **Step 6: Commit Task 3**

```powershell
git add src/ui/components/onboarding_demo.gd src/ui/onboarding_screen.gd tests/onboarding_complete_test.*
git commit -m "feat: animate complete first-run onboarding"
```

### Task 4: Detailed Contextual Battle Teaching

**Files:**
- Modify: `data/tutorial_steps.json`
- Modify: `src/ui/components/reaction_chamber.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/tutorial_test.gd`
- Modify: `tests/battle_input_workflow_test.gd`
- Create: `tests/battle_help_copy_test.gd`
- Create: `tests/battle_help_copy_test.tscn`

**Interfaces:**
- Consumes: `TutorialDirector.accept_action(action)`, current kit data, Reaction Chamber history.
- Produces: tutorial actions `observe_essence`, `observe_ultimate`, and `learn_remix`; exact dynamic tooltips for reaction, Mana, active skill, and ultimate controls.

- [ ] **Step 1: Expand failing tutorial and help-copy assertions**

Assert that tutorial data contains thirteen or more ordered actions, explicitly names the three dots as completed potion essences, states that order matters, distinguishes Mana from Ultimate charge, and explains that the first New Mix costs one move while emergency recovery remains available.

- [ ] **Step 2: Verify both tests are red**

Run `tutorial_test.tscn` and `battle_help_copy_test.tscn`. Expected: missing new actions and exact explanatory copy.

- [ ] **Step 3: Implement the expanded teaching sequence**

Add passive observation steps that advance when potion completion updates chamber history and when a reaction grants ultimate charge. Keep direct action gates for bottle taps and skill casting. Wire factual tooltips from current kit values, not duplicated constants.

- [ ] **Step 4: Preserve all battle pointer paths**

For every new tutorial target, ensure dim panels use `MOUSE_FILTER_IGNORE`; only tutorial buttons consume input. Extend `battle_input_workflow_test.gd` to hit-test required bottles during every new step.

- [ ] **Step 5: Run tutorial and complete battle workflow tests**

Run:

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/tutorial_test.tscn
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/battle_help_copy_test.tscn
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/battle_input_workflow_test.tscn
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/alchemy_reaction_test.tscn
```

Expected: zero failures and real touch taps still pour between bottles.

- [ ] **Step 6: Commit Task 4**

```powershell
git add data/tutorial_steps.json src/ui/components/reaction_chamber.gd src/ui/battle_screen.gd tests/tutorial_test.gd tests/battle_input_workflow_test.gd tests/battle_help_copy_test.*
git commit -m "feat: teach reactions skills and battle resources"
```

### Task 5: Visual QA, Regression, and Android Release

**Files:**
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Modify: `.github/workflows/android-ci.yml`
- Modify: `tests/alchemy_release_test.gd`
- Modify: `tests/release_pipeline_test.gd`

**Interfaces:**
- Consumes: completed Guide, onboarding, and tutorial feature tests.
- Produces: signed Android debug APK with version name `1.6.0` and version code `25`.

- [ ] **Step 1: Run UI captures at target sizes**

Launch onboarding and Guide at 576×1280 and 720×1280. Verify title/card bounds, scroll range, button centering, and no overlap using captured screenshots.

- [ ] **Step 2: Run the targeted regression suite**

Run every new test plus `logic_test`, `gameplay_integration_test`, `natural_battle_ui_test`, `mobile_regression_v18_test`, `stuck_remix_and_area_scroll_test`, `reaction_codex_test`, `run_lifecycle_test`, and `accessibility_complete_test`. Expected: zero failures.

- [ ] **Step 3: Bump Android release metadata**

Set project/export version to `1.6.0`, code `25`, APK name `PotionRogue-v25-debug.apk`, and update exact release-test and CI expectations.

- [ ] **Step 4: Export and validate APK**

```powershell
& '.tools/Godot_v4.7.1-stable_win64_console.exe' --headless --path . --export-debug 'Android Debug' 'builds/PotionRogue-v25-debug.apk'
.\tools\validate_release.ps1 -ProjectRoot . -ApkPath builds\PotionRogue-v25-debug.apk
& 'C:\Android\Sdk\build-tools\36.0.0\apksigner.bat' verify --verbose builds\PotionRogue-v25-debug.apk
```

Expected: export exit 0, budgets pass, and v2/v3 APK signatures verify.

- [ ] **Step 5: Commit and push release**

```powershell
git add project.godot export_presets.cfg .github/workflows/android-ci.yml tests/alchemy_release_test.gd tests/release_pipeline_test.gd
git commit -m "release: ship complete player guide v25"
git push origin main
```
