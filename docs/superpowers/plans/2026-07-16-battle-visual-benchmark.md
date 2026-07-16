# Battle Visual Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable Cave Slime battle benchmark that matches the approved premium dark-fantasy concept while preserving every existing puzzle and battle rule.

**Architecture:** Keep `BattleManager`, `PuzzleBoard`, and `PotionTube` as state owners. Add a data-driven `VisualRegistry`, replace procedural enemy drawing with a sprite-backed `EnemyDisplay`, enhance potion rendering without changing its public API, and centralize reusable battle motion/VFX in `BattleFx`. Code-built screen layout remains in place for this benchmark, but reusable presentation pieces become focused scenes/scripts that later screens and enemies can consume.

**Tech Stack:** Godot 4.7.1 compatibility renderer, GDScript, CanvasItem shaders, PNG/WebP raster assets, built-in Tween and GPUParticles2D, existing headless GDScript tests.

## Global Constraints

- Preserve the 720×1280 portrait base viewport and Android safe areas.
- Preserve all battle, puzzle, save, progression, and data JSON behavior.
- Target 60 FPS on mainstream Android devices with a functional reduced-effects fallback.
- All generated art must be original, contain no trademarks or watermarks, and share the approved charcoal/indigo/aged-gold visual system.
- Potion liquid state must stay readable by color and segment count during all motion.
- Presentation events must never decide damage, rewards, turn order, or board state.
- Missing textures, shaders, or animation clips must degrade to a safe visible fallback rather than crash.

---

## File Structure

### New runtime files

- `src/ui/visual_registry.gd` — maps gameplay IDs to art paths, palette values, scale, and effect anchors.
- `src/ui/battle_fx.gd` — reusable hit-stop, shake, flashes, particles, and reduced-effects behavior.
- `assets/shaders/liquid_glass.gdshader` — subtle highlight, bubble, and surface motion for potion liquid.
- `assets/shaders/enemy_hit.gdshader` — enemy flash and poison/enrage tint without replacing textures.
- `tests/visual_test.gd` — registry coverage, resource fallback, scene smoke, and presentation-invariance checks.
- `tests/visual_test.tscn` — headless test entry point.

### New approved runtime assets

- `assets/art/backgrounds/shadow_crypt_battle.webp`
- `assets/art/enemies/slime/cave_slime.png`
- `assets/art/enemies/slime/cave_slime_shadow.png`
- `assets/art/potions/bottle_frame.png`
- `assets/art/ui/battle_panel.png`
- `assets/art/ui/banner_turn.png`
- `assets/art/ui/button_round.png`
- `assets/art/ui/icon_undo.png`
- `assets/art/ui/icon_remix.png`
- `assets/art/ui/icon_pause.png`

### Modified runtime files

- `src/battle/enemy_display.gd` — load registered sprite art and expose normalized animation methods while retaining procedural fallback.
- `src/puzzle/potion_tube.gd` — draw premium bottle/liquid presentation using the existing contents and interaction API.
- `src/puzzle/puzzle_board.gd` — emit pour presentation metadata and arrange two responsive rows for the benchmark layout.
- `src/ui/ui_kit.gd` — add nine-slice panel/button factories and battle backdrop factory.
- `src/ui/battle_screen.gd` — compose the benchmark layout and connect battle signals to `EnemyDisplay` and `BattleFx`.
- `project.godot` — add a `reduced_effects` project setting defaulting to `false` only if it is not stored in save settings.

---

### Task 1: Visual Registry and Headless Test Harness

**Files:**
- Create: `src/ui/visual_registry.gd`
- Create: `tests/visual_test.gd`
- Create: `tests/visual_test.tscn`
- Modify: `tests/logic_test.gd`

**Interfaces:**
- Consumes: `GameState.enemies`, `GameState.potions`, `ResourceLoader.exists(path)`.
- Produces: `VisualRegistry.enemy(enemy_id: String) -> Dictionary`, `VisualRegistry.potion(color: String) -> Dictionary`, `VisualRegistry.texture_or_null(path: String) -> Texture2D`, `VisualRegistry.missing_runtime_assets() -> PackedStringArray`.

- [ ] **Step 1: Create the failing visual test scene**

Create `tests/visual_test.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/visual_test.gd" id="1"]

[node name="VisualTest" type="Node"]
script = ExtResource("1")
```

Create `tests/visual_test.gd` with coverage checks that fail before the registry exists:

```gdscript
extends Node

var failures := 0
var checks := 0

func _ready() -> void:
	check(VisualRegistry.enemy("slime").get("sprite", "") != "", "slime sprite mapping")
	for enemy_id in GameState.enemies:
		check(not VisualRegistry.enemy(str(enemy_id)).is_empty(), "enemy mapping: " + str(enemy_id))
	for color in GameState.potions:
		check(not VisualRegistry.potion(str(color)).is_empty(), "potion mapping: " + str(color))
	check(VisualRegistry.texture_or_null("res://missing.png") == null, "missing texture fallback")
	print("---")
	print("%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
```

- [ ] **Step 2: Run the visual test and verify it fails**

Run:

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/visual_test.tscn
```

Expected: non-zero exit with `Identifier "VisualRegistry" not declared`.

- [ ] **Step 3: Implement the minimal registry**

Create `src/ui/visual_registry.gd`:

```gdscript
class_name VisualRegistry
extends RefCounted

const ENEMY_DEFAULT := {
	"sprite": "",
	"shadow": "",
	"scale": 1.0,
	"hit_anchor": Vector2(0.68, 0.42),
	"projectile_anchor": Vector2(0.5, 0.46),
}

const ENEMIES := {
	"slime": {
		"sprite": "res://assets/art/enemies/slime/cave_slime.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 1.0,
		"hit_anchor": Vector2(0.72, 0.42),
		"projectile_anchor": Vector2(0.5, 0.5),
	},
	"skeleton": {"scale": 0.92},
	"poison_beast": {"scale": 0.96},
	"stone_golem": {"scale": 1.02},
	"dark_mage": {"scale": 0.94},
	"blood_slime": {"scale": 1.04},
	"fire_golem": {"scale": 1.1},
}

const POTIONS := {
	"red": {"color": Color("ed4b36"), "glow": Color("ff8a3d")},
	"green": {"color": Color("73cf43"), "glow": Color("b7f36b")},
	"blue": {"color": Color("3699ec"), "glow": Color("62c7ff")},
	"purple": {"color": Color("a448e0"), "glow": Color("d879ff")},
}

static func enemy(enemy_id: String) -> Dictionary:
	var result := ENEMY_DEFAULT.duplicate(true)
	var override: Dictionary = ENEMIES.get(enemy_id, {})
	result.merge(override, true)
	return result

static func potion(color: String) -> Dictionary:
	return POTIONS.get(color, {"color": Color.WHITE, "glow": Color.WHITE}).duplicate(true)

static func texture_or_null(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func missing_runtime_assets() -> PackedStringArray:
	var result := PackedStringArray()
	for enemy_id in ENEMIES:
		var config := enemy(str(enemy_id))
		for key in ["sprite", "shadow"]:
			var path := str(config.get(key, ""))
			if not path.is_empty() and not ResourceLoader.exists(path):
				result.append(path)
	return result
```

- [ ] **Step 4: Run existing and visual tests**

Run both commands:

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/logic_test.tscn
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/visual_test.tscn
```

Expected: logic suite reports `0 failures`; visual suite passes registry and fallback checks even though runtime asset coverage still reports missing files only through `missing_runtime_assets()`.

- [ ] **Step 5: Commit the registry and harness**

```powershell
git add src/ui/visual_registry.gd tests/visual_test.gd tests/visual_test.tscn tests/logic_test.gd
git commit -m "test: add visual asset registry coverage"
```

---

### Task 2: Generate and Validate the Battle Benchmark Art Pack

**Files:**
- Create: `assets/art/backgrounds/shadow_crypt_battle.webp`
- Create: `assets/art/enemies/slime/cave_slime.png`
- Create: `assets/art/enemies/slime/cave_slime_shadow.png`
- Create: `assets/art/potions/bottle_frame.png`
- Create: `assets/art/ui/battle_panel.png`
- Create: `assets/art/ui/banner_turn.png`
- Create: `assets/art/ui/button_round.png`
- Create: `assets/art/ui/icon_undo.png`
- Create: `assets/art/ui/icon_remix.png`
- Create: `assets/art/ui/icon_pause.png`

**Interfaces:**
- Consumes: approved Cave Slime concept and `VisualRegistry` paths from Task 1.
- Produces: optimized raster resources at the exact `res://assets/art/...` paths above.

- [ ] **Step 1: Generate the environment plate**

Use the built-in image generation tool with this exact production prompt, using the approved Cave Slime concept only as a style and lighting reference:

```text
Use case: stylized-concept
Asset type: portrait mobile game battle environment plate
Primary request: an empty torch-lit shadow crypt arena for Potion Rogue, designed to sit behind a large enemy and UI
Scene/backdrop: symmetrical stone arch chamber, circular cracked fighting platform, side torches, distant cool-blue doorway, tiny violet crystals
Style/medium: polished hand-painted 2.5D fantasy mobile game environment, original design
Composition/framing: 9:16 portrait, no enemy, no bottles, no interface, center kept readable for a character, darker lower edge for UI transition
Lighting/mood: warm side torchlight, cool blue-violet depth light, subtle ember and fog atmosphere
Color palette: charcoal, deep indigo, aged brown stone, warm amber, restrained violet
Constraints: no text, no logos, no watermark, no character, no interface frame
Avoid: flat gradients, photorealism, excessive clutter, bright center floor
```

Copy the approved output into `assets/art/backgrounds/shadow_crypt_battle.webp` without deleting the generated source.

- [ ] **Step 2: Generate the Cave Slime and shadow cutouts**

Generate the slime on a perfectly flat `#ff00ff` background because the subject is green. Require generous padding, no floor, no cast shadow, no magenta in the subject, and the same expression/material quality as the approved concept. Copy the generated source to `tmp/imagegen/cave_slime_key.png`, then run:

```powershell
python 'C:\Users\FAJAR\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py' --input tmp/imagegen/cave_slime_key.png --out assets/art/enemies/slime/cave_slime.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --edge-contract 1
```

Generate a separate soft oval painted ground shadow on the same flat magenta key, remove its background with the same command, and save it as `assets/art/enemies/slime/cave_slime_shadow.png`.

- [ ] **Step 3: Generate reusable bottle and UI cutouts**

Generate each asset separately on a flat chroma-key background:

- Bottle frame: dark reflective glass outline with aged-bronze neck and rim, empty transparent central liquid chamber, straight-on orthographic view.
- Battle panel: rectangular carved dark stone/wood frame with aged-gold edge and clear empty center, designed for nine-slice scaling.
- Turn banner: compact carved banner with empty center and no text.
- Round button: dark stone/bronze circular control with empty center.
- Icons: original undo arrow, two-bottle remix symbol, and pause bars; painted gold, bold silhouette, no surrounding frame.

Remove the chroma key with `remove_chroma_key.py`, save to the exact paths listed in this task, and retain no keyed source under runtime `assets/`.

- [ ] **Step 4: Validate art files through Godot**

Extend `tests/visual_test.gd` before `get_tree().quit(...)`:

```gdscript
	var missing := VisualRegistry.missing_runtime_assets()
	check(missing.is_empty(), "registered runtime assets exist: " + ", ".join(missing))
	for path in [
		"res://assets/art/backgrounds/shadow_crypt_battle.webp",
		"res://assets/art/potions/bottle_frame.png",
		"res://assets/art/ui/battle_panel.png",
		"res://assets/art/ui/banner_turn.png",
		"res://assets/art/ui/button_round.png",
	]:
		check(ResourceLoader.exists(path), "loadable art: " + path)
```

Run:

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --quit
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/visual_test.tscn
```

Expected: all named resources import and visual tests report `0 failures`.

- [ ] **Step 5: Inspect alpha and edge quality**

Open every transparent PNG at original resolution. Confirm transparent corners, no chroma fringe, no cropped silhouette, no embedded text, and no inconsistent light direction. Regenerate only the failed asset with one targeted prompt correction.

- [ ] **Step 6: Commit the approved art pack**

```powershell
git add assets/art tests/visual_test.gd
git commit -m "art: add Cave Slime battle benchmark pack"
```

---

### Task 3: Sprite-Backed EnemyDisplay with Smooth State Animation

**Files:**
- Modify: `src/battle/enemy_display.gd`
- Create: `assets/shaders/enemy_hit.gdshader`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: `VisualRegistry.enemy(enemy_id)` and existing `configure(shape, color_hex)` calls.
- Produces: `configure_enemy(enemy_id: String, fallback_shape: String, color_hex: String)`, `play_intro()`, `play_anticipate()`, `play_attack()`, `play_hit()`, `play_defeat()`, and the existing `enraged` property.

- [ ] **Step 1: Add a failing EnemyDisplay smoke test**

Append to `tests/visual_test.gd`:

```gdscript
	var enemy_view := EnemyDisplay.new()
	add_child(enemy_view)
	enemy_view.custom_minimum_size = Vector2(520, 300)
	enemy_view.configure_enemy("slime", "slime", "6fce4e")
	check(enemy_view.has_method("play_intro"), "enemy intro interface")
	check(enemy_view.has_method("play_attack"), "enemy attack interface")
	check(enemy_view.has_method("play_defeat"), "enemy defeat interface")
	check(enemy_view.uses_sprite_art(), "slime uses registered sprite")
	enemy_view.queue_free()
```

- [ ] **Step 2: Run the visual test and verify the new assertions fail**

Expected: failure for missing `configure_enemy` or `uses_sprite_art`.

- [ ] **Step 3: Add the hit/tint shader**

Create `assets/shaders/enemy_hit.gdshader`:

```glsl
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 tinted = mix(tex.rgb, tex.rgb * tint_color.rgb, tint_amount);
	tinted = mix(tinted, vec3(1.0), flash_amount);
	COLOR = vec4(tinted, tex.a * COLOR.a);
}
```

- [ ] **Step 4: Refactor EnemyDisplay without removing its fallback**

Keep the current procedural `_draw_*` methods. Add child `TextureRect` nodes for shadow and body, load registered art in `configure_enemy`, and hide sprite nodes when loading fails. `configure(shape, color_hex)` delegates to `configure_enemy(shape, shape, color_hex)` for backward compatibility.

Use one perpetual idle tween that scales the body between `Vector2(1.0, 1.0)` and `Vector2(1.025, 0.975)` over 0.8 seconds. Each event method kills only its own action tween, never the idle tween permanently. `play_attack()` performs anticipation scale `Vector2(0.9, 1.08)` for 0.12 seconds, lunges upward 18 pixels for 0.14 seconds, then returns over 0.22 seconds. `play_hit()` retains the current shake and animates shader `flash_amount` from `1.0` to `0.0` over 0.24 seconds. `play_defeat()` squashes to `Vector2(1.25, 0.12)`, fades to zero over 0.55 seconds, and does not free the node.

Add:

```gdscript
func uses_sprite_art() -> bool:
	return _body_texture != null and _body_texture.texture != null and _body_texture.visible
```

- [ ] **Step 5: Run visual and logic tests**

Expected: both suites pass; missing non-slime sprites continue through procedural fallback.

- [ ] **Step 6: Capture an isolated battle screenshot**

Run:

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --path . res://scenes/battle.tscn ++ --screenshot=.tools/shots/battle-sprite.png --delay=2
```

Inspect that the slime is centered, fully visible, correctly grounded, and not blurred by scaling.

- [ ] **Step 7: Commit the enemy presentation**

```powershell
git add src/battle/enemy_display.gd assets/shaders/enemy_hit.gdshader tests/visual_test.gd .tools/shots/battle-sprite.png
git commit -m "feat: animate sprite-backed battle enemies"
```

Do not stage `.tools/shots/battle-sprite.png` because `.tools/` is intentionally ignored; the command lists it only as a local review artifact.

---

### Task 4: Premium Potion Vessel Rendering and Pour Metadata

**Files:**
- Modify: `src/puzzle/potion_tube.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Create: `assets/shaders/liquid_glass.gdshader`
- Modify: `tests/logic_test.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: existing `contents`, `selected`, `locked_moves`, `tapped`, and `VisualRegistry.potion(color)`.
- Produces: `PotionTube.flash_complete()`, `PotionTube.play_invalid()`, and `PuzzleBoard.pour_presented(from_global: Vector2, to_global: Vector2, color: String, count: int)`.

- [ ] **Step 1: Add failing signal and API checks**

In the board-rule test, connect `pour_presented`, perform a valid pour, and check that color and count equal the actual moved run. In `tests/visual_test.gd`, instantiate a tube and check `has_method("flash_complete")` and `has_method("play_invalid")`.

- [ ] **Step 2: Run tests and verify the new checks fail**

Expected: unknown signal or method failure.

- [ ] **Step 3: Add the liquid shader**

Create `assets/shaders/liquid_glass.gdshader`:

```glsl
shader_type canvas_item;

uniform vec4 liquid_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float selected_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float wave = sin(uv.x * 18.0 + TIME * 2.2) * 0.008;
	float surface = smoothstep(0.49 + wave, 0.47 + wave, uv.y);
	float edge = smoothstep(0.48, 0.08, abs(uv.x - 0.5));
	float sparkle = pow(max(0.0, sin((uv.x + uv.y) * 42.0 + TIME * 1.8)), 20.0) * 0.15;
	vec3 rgb = liquid_color.rgb * (0.72 + edge * 0.35) + sparkle;
	rgb += liquid_color.rgb * selected_amount * 0.22;
	COLOR = vec4(rgb, liquid_color.a * surface);
}
```

- [ ] **Step 4: Upgrade PotionTube rendering while preserving state logic**

Load `bottle_frame.png` once in `_ready()`. Draw a layered soft glow, four clipped liquid cells with curved surface highlights and bubbles, dark glass body, bottle texture overlay, selected halo, and illustrated lock badge. Keep each of the four capacity units visually distinct with at least a 2-pixel separator at 720×1280.

Implement `flash_complete()` as a 0.32-second scale/glow tween and `play_invalid()` as a three-step 5-pixel horizontal shake. Do not mutate `contents` in either method.

- [ ] **Step 5: Emit pour presentation metadata from PuzzleBoard**

Add:

```gdscript
signal pour_presented(from_global: Vector2, to_global: Vector2, color: String, count: int)
```

In `_try_pour`, capture source and destination global centers before mutating arrays, then emit after a successful move:

```gdscript
	pour_presented.emit(
		from_tube.global_position + from_tube.size * 0.5,
		to_tube.global_position + to_tube.size * 0.5,
		color,
		count
	)
```

Call `to_tube.flash_complete()` before clearing a completed tube. Route invalid taps to `tube.play_invalid()`.

- [ ] **Step 6: Arrange tubes as two rows on narrow battle layouts**

Replace the single `HBoxContainer` with a centered `GridContainer` using `columns = 6` when available width is at least 660 pixels and `columns = 3` below that threshold. For the 720-pixel benchmark, use six tubes in one row only if each tube retains at least 82 pixels width; otherwise use two rows of three. Keep board logic and the order of `tubes` unchanged.

- [ ] **Step 7: Run tests and capture the board**

Expected: logic and visual suites pass; the screenshot shows four clearly readable liquid units and two empty bottles without layout clipping.

- [ ] **Step 8: Commit potion presentation changes**

```powershell
git add src/puzzle/potion_tube.gd src/puzzle/puzzle_board.gd assets/shaders/liquid_glass.gdshader tests/logic_test.gd tests/visual_test.gd
git commit -m "feat: polish potion vessels and pour feedback"
```

---

### Task 5: Reusable Battle FX and Reduced-Effects Mode

**Files:**
- Create: `src/ui/battle_fx.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: battle signals and `PuzzleBoard.pour_presented`.
- Produces: `BattleFx.hit(target: Control, strength: float)`, `BattleFx.pour(from: Vector2, to: Vector2, color: Color, count: int)`, `BattleFx.heal(at: Vector2)`, `BattleFx.shield(at: Vector2)`, `BattleFx.poison(at: Vector2)`, `BattleFx.set_reduced_effects(value: bool)`.

- [ ] **Step 1: Add failing BattleFx API checks**

Instantiate `BattleFx` in `tests/visual_test.gd`, verify every method above exists, set reduced effects to true, and verify `fx.reduced_effects` is true.

- [ ] **Step 2: Run visual tests and verify failure**

Expected: `Identifier "BattleFx" not declared`.

- [ ] **Step 3: Implement BattleFx with pooled lightweight effects**

Create `BattleFx` as a full-rect, mouse-ignoring `Control`. Use tweens plus small `GPUParticles2D` emitters built once in `_ready()`. Normal mode uses at most 48 active particles per effect and reduced mode at most 12. `hit()` applies no more than 8 pixels of root shake and 70 ms hit-stop by setting the target animation speed, not `Engine.time_scale`. `pour()` draws a tapered Line2D arc for 220 ms and releases 6–18 colored droplets. All temporary nodes self-clean at tween completion.

- [ ] **Step 4: Connect presentation-only signals**

In `BattleScreen._build_ui()`, add `battle_fx = BattleFx.new()` after the main layout and before overlays. Connect:

```gdscript
board.pour_presented.connect(func(from: Vector2, to: Vector2, color: String, count: int) -> void:
	var style := VisualRegistry.potion(color)
	battle_fx.pour(from, to, style.get("glow", Color.WHITE), count))
```

Call `enemy_display.play_anticipate()` when the countdown reaches one without replaying on every `_refresh()`. On `enemy_attacked`, play attack and player-hit feedback. On `enemy_damaged`, call `battle_fx.hit(enemy_display, 1.0)`. Route potion activation to matching fire/heal/shield/poison effects. Call `enemy_display.play_defeat()` before showing victory rewards.

- [ ] **Step 5: Verify presentation does not mutate battle state**

Add a test that records `enemy_hp`, calls every BattleFx method, waits two frames, and checks `enemy_hp` is unchanged.

- [ ] **Step 6: Run all tests**

Expected: both suites pass and no orphan-node warnings appear on quit.

- [ ] **Step 7: Commit reusable battle effects**

```powershell
git add src/ui/battle_fx.gd src/ui/battle_screen.gd tests/visual_test.gd
git commit -m "feat: add responsive battle effects"
```

---

### Task 6: Premium Battle Composition and Themed Controls

**Files:**
- Modify: `src/ui/ui_kit.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `assets/shaders/dungeon_bg.gdshader`
- Modify: `tests/visual_test.gd`

**Interfaces:**
- Consumes: benchmark art pack, `EnemyDisplay`, `PotionTube`, `BattleFx`.
- Produces: `UiKit.textured_panel(texture_path: String, margins := 26) -> PanelContainer`, `UiKit.icon_button(icon_path: String, count: int, tooltip: String) -> Button`, `UiKit.battle_background(parent: Control, texture_path: String)`.

- [ ] **Step 1: Add failing UiKit factory checks**

In `tests/visual_test.gd`, create one textured panel and icon button. Check they have minimum sizes, accessible tooltip text, and non-null normal/focus styleboxes.

- [ ] **Step 2: Run the visual test and verify failure**

Expected: missing factory methods.

- [ ] **Step 3: Implement nine-slice factories**

Use `StyleBoxTexture` with `texture_margin_left/right/top/bottom = 48` for `battle_panel.png`. Use `TextureButton` or a styled `Button` with `button_round.png` as normal/hover/pressed textures and the icon centered above a tabular count label. Preserve keyboard focus and disabled states.

- [ ] **Step 4: Recompose the battle screen to match the approved benchmark**

Use the following vertical budget at 720×1280:

- Safe top and stage strip: 76 px.
- Enemy name and HP: 88 px.
- Arena including enemy: 380 px.
- Turn/status banner: 72 px.
- Puzzle board: 470 px.
- Bottom controls and safe bottom: 154 px.

Place the player HP/shield/status as a compact overlay strip at the lower edge of the arena rather than a separate large panel. Keep countdown text immediately above the turn banner. Set enemy art region to at least 310 pixels high. Use `shadow_crypt_battle.webp` as a cropped full-screen environment layer with a dark gradient under the puzzle region.

Replace text-only Undo/New Mix/Pause buttons with illustrated round controls plus readable labels/counts. Keep all existing handlers and accessibility tooltips.

- [ ] **Step 5: Configure enemy by gameplay ID**

Replace:

```gdscript
enemy_display.configure(battle.enemy_shape, battle.enemy_color)
```

with:

```gdscript
enemy_display.configure_enemy(
	str(entry.get("enemy", "slime")),
	battle.enemy_shape,
	battle.enemy_color
)
enemy_display.play_intro()
```

- [ ] **Step 6: Run tests and standardized screenshots**

Run:

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/logic_test.tscn
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/visual_test.tscn
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --path . res://scenes/battle.tscn ++ --screenshot=.tools/shots/battle-benchmark.png --delay=2
```

Expected: tests pass and screenshot is 720×1280 with no clipping or placeholder enemy for Cave Slime.

- [ ] **Step 7: Commit the benchmark layout**

```powershell
git add src/ui/ui_kit.gd src/ui/battle_screen.gd assets/shaders/dungeon_bg.gdshader tests/visual_test.gd
git commit -m "feat: deliver premium Cave Slime battle benchmark"
```

---

### Task 7: Benchmark Verification and Acceptance Gate

**Files:**
- Modify: `README.md`
- Create: `docs/ART_PIPELINE.md`
- Modify: `docs/TECHNICAL_DESIGN.md`

**Interfaces:**
- Consumes: completed benchmark and both automated test scenes.
- Produces: reproducible art-generation/import rules and evidence for continuing the full roster reskin.

- [ ] **Step 1: Run the full automated verification**

```powershell
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/logic_test.tscn
& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/visual_test.tscn
```

Expected: both commands exit `0`, logic reports `0 failures`, visual reports `0 failures`.

- [ ] **Step 2: Capture normal and reduced-effects evidence**

Capture the same Cave Slime battle once with full effects and once with `BattleFx.reduced_effects = true`. Confirm both are readable, the reduced version has fewer particles and no strong shake, and neither changes HP or board state at capture time.

- [ ] **Step 3: Perform the visual acceptance checklist**

Verify at original resolution:

- Enemy occupies the arena focal point and has clean alpha edges.
- Background depth and torch lighting match the enemy light direction.
- All six vessels and every liquid unit remain unambiguous.
- Player HP, enemy HP, attack countdown, and action counts are readable at phone size.
- Frames scale without corner stretching.
- No button, particle, or label crosses safe areas.
- Normal battle idles smoothly for 60 seconds without node-count growth.
- Existing tutorial overlay remains usable.

- [ ] **Step 4: Document the reproducible pipeline**

Create `docs/ART_PIPELINE.md` describing exact runtime paths, naming rules, chroma-key removal command, Godot import expectations, lighting direction, palette, effect limits, screenshot commands, and the fallback rule. Update the Phase 4 roadmap in `docs/TECHNICAL_DESIGN.md` and the README status to say the Cave Slime benchmark is complete while the remaining roster/screens are still in progress.

- [ ] **Step 5: Run diff and repository checks**

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; only intended documentation or generated import metadata remains.

- [ ] **Step 6: Commit the verified benchmark**

```powershell
git add README.md docs/ART_PIPELINE.md docs/TECHNICAL_DESIGN.md
git commit -m "docs: record battle art production pipeline"
```

## Next Plans After This Gate

Once this benchmark passes, create and execute three separate plans in order:

1. `enemy-roster-art-and-animation` — Skeleton, Poison Beast, Stone Golem, Dark Mage, Blood Slime, and Fire Golem with the normalized animation interface.
2. `meta-screen-visual-overhaul` — main menu, dungeon map, reward/relic screens, permanent upgrades, tutorial, settings, credits, and result screens.
3. `play-store-creative-pack` — capture real implemented screens, compose feature captions/device framing, and export store-ready images.
