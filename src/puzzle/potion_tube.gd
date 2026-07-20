class_name PotionTube
extends Control
## A single potion tube. Holds up to CAPACITY liquid units (bottom -> top)
## and draws itself procedurally as a glass vial with a rounded bottom,
## glowing liquid, glass shine and a rim. Swap for sprite art in polish phase.

signal tapped(tube: PotionTube)

const CAPACITY := 4

const COLOR_MAP := {
	"red": Color("ff4d3d"),
	"green": Color("46e065"),
	"blue": Color("3d9bff"),
	"purple": Color("b04dff"),
}

## Liquid colors from bottom (index 0) to top.
var contents: Array[String] = []
var layer_effects: Array = []
var capacity := CAPACITY:
	set(value):
		capacity = clampi(value, 1, 8)
		queue_redraw()

## Moves remaining while this tube is magically locked (0 = unlocked).
var locked_moves := 0:
	set(value):
		locked_moves = maxi(value, 0)
		queue_redraw()

var selected := false:
	set(value):
		selected = value
		queue_redraw()

var guidance_state := "neutral":
	set(value):
		guidance_state = value
		queue_redraw()

var _bottle_texture: Texture2D
var _feedback_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_bottle_texture = VisualRegistry.texture_or_null(
			"res://assets/art/potions/bottle_frame.png")
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)
	elif event.is_action_pressed("ui_accept"):
		tapped.emit(self)
		accept_event()


func is_locked() -> bool:
	return locked_moves > 0


func top_color() -> String:
	return "" if contents.is_empty() else contents[contents.size() - 1]


## Number of contiguous same-color units at the top.
func top_run_count() -> int:
	if contents.is_empty():
		return 0
	var color := top_color()
	var count := 0
	for i in range(contents.size() - 1, -1, -1):
		if contents[i] != color:
			break
		count += 1
	return count


func free_space() -> int:
	return capacity - contents.size()


func is_complete() -> bool:
	return contents.size() == capacity and top_run_count() == capacity


func set_contents(new_contents: Array[String]) -> void:
	contents = new_contents.duplicate()
	layer_effects.clear()
	for i in contents.size():
		layer_effects.append([])
	queue_redraw()


func add_layer_effect(index: int, effect: String) -> bool:
	_sync_layer_effects()
	if index < 0 or index >= contents.size():
		return false
	var effects: Array = layer_effects[index]
	if not effect in effects:
		effects.append(effect)
	queue_redraw()
	return true


func remove_layer_effect(index: int, effect: String) -> bool:
	_sync_layer_effects()
	if index < 0 or index >= contents.size():
		return false
	var effects: Array = layer_effects[index]
	var removed := effect in effects
	effects.erase(effect)
	queue_redraw()
	return removed


func has_layer_effect(index: int, effect: String) -> bool:
	_sync_layer_effects()
	return index >= 0 and index < layer_effects.size() \
			and effect in (layer_effects[index] as Array)


func effect_count(effect: String) -> int:
	_sync_layer_effects()
	var count := 0
	for effects in layer_effects:
		count += 1 if effect in (effects as Array) else 0
	return count


func _sync_layer_effects() -> void:
	while layer_effects.size() < contents.size():
		layer_effects.append([])
	while layer_effects.size() > contents.size():
		layer_effects.pop_back()


func flash_complete() -> void:
	if bool(SaveSystem.setting("reduced_effects")):
		modulate = Color.WHITE; scale = Vector2.ONE; queue_redraw(); return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween().set_parallel(true)
	modulate = Color(1.8, 1.65, 1.25, 1.0)
	scale = Vector2.ONE
	_feedback_tween.tween_property(self, "scale", Vector2(1.1, 1.08), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.32)


func play_invalid() -> void:
	if bool(SaveSystem.setting("reduced_effects")):
		queue_redraw(); return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	var base_x := position.x
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "position:x", base_x - 5.0, 0.045)
	_feedback_tween.tween_property(self, "position:x", base_x + 5.0, 0.07)
	_feedback_tween.tween_property(self, "position:x", base_x - 3.0, 0.06)
	_feedback_tween.tween_property(self, "position:x", base_x, 0.05)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var lift := -7.0 if selected else 0.0
	draw_set_transform(Vector2(0, lift))
	var inner_left := w * 0.21
	var inner_w := w * 0.58
	var body_top := h * 0.29
	var body_bottom := h * 0.89
	var liquid_area_h := body_bottom - body_top
	var seg_h := liquid_area_h / float(capacity)
	var cx := w * 0.5

	# Jewel-toned glow behind the physical bottle sprite.
	if not contents.is_empty():
		var glow: Color = VisualRegistry.potion(top_color()).get("glow", Color.WHITE)
		glow.a = 0.14 if not selected else 0.34
		draw_circle(Vector2(cx, h * 0.61), w * (0.50 if not selected else 0.68), glow)

	# Dynamic liquid remains tied directly to the four logical capacity units.
	for i in contents.size():
		var style := VisualRegistry.potion(contents[i])
		var color: Color = style.get("color", COLOR_MAP.get(contents[i], Color.WHITE))
		if has_layer_effect(i, "hidden"):
			color = Color("282337")
		elif contents[i] == "wild":
			color = Color("f4c95d")
		var seg_top := body_bottom - seg_h * float(i + 1)
		var liquid_rect := Rect2(inner_left, seg_top + 1.0, inner_w, seg_h - 2.0)
		draw_rect(liquid_rect, color.darkened(0.12))
		draw_rect(Rect2(liquid_rect.position + Vector2(2, 2),
				Vector2(liquid_rect.size.x * 0.32, liquid_rect.size.y - 4)),
				color.lightened(0.32))
		# Each cell receives a readable surface and small deterministic bubble.
		if i == contents.size() - 1:
			draw_line(Vector2(inner_left, seg_top + 2.0),
					Vector2(inner_left + inner_w, seg_top + 2.0),
					color.lightened(0.55), 3.0, true)
		var bubble_r := maxf(1.5, w * 0.025)
		draw_circle(Vector2(inner_left + inner_w * (0.67 if i % 2 == 0 else 0.78),
				seg_top + seg_h * 0.55), bubble_r, Color(1, 1, 1, 0.28))
		if has_layer_effect(i, "cursed"):
			draw_line(Vector2(inner_left + 3, seg_top + 3),
					Vector2(inner_left + inner_w - 3, seg_top + seg_h - 3),
					Color("d46cff"), 3.0, true)
		if has_layer_effect(i, "volatile"):
			draw_rect(liquid_rect.grow(-2), Color("ff9b42"), false, 3.0)

	# The painted frame supplies bronze, scratches and high-quality glass edges.
	if _bottle_texture != null:
		draw_texture_rect(_bottle_texture,
				Rect2(Vector2(-w * 0.04, h * 0.015), Vector2(w * 1.08, h * 0.96)),
				false)
	else:
		draw_rect(Rect2(4, 8, w - 8, h - 12), Color("7d7195"), false, 3.0)

	# Magical lock overlay
	if is_locked():
		draw_rect(Rect2(5, h * 0.16, w - 10, h * 0.76), Color(0.05, 0.02, 0.12, 0.7))
		var lock_c := Vector2(cx, h * 0.5)
		var lock_col := Color("c07ce8")
		draw_rect(Rect2(lock_c.x - 13, lock_c.y - 4, 26, 22), lock_col)
		draw_arc(lock_c + Vector2(0, -4), 9.0, PI, TAU, 12, lock_col, 4.0)
		var turns_label := str(locked_moves)
		draw_string(ThemeDB.fallback_font, lock_c + Vector2(-5, 40), turns_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
