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
var _surface_clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_bottle_texture = VisualRegistry.texture_or_null(
			"res://assets/art/potions/bottle_frame.png")
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	set_process(true)


## Gentle liquid-surface motion at a low tick rate: alive without shaders or
## per-frame redraws. Reduced Effects freezes the surface entirely.
func _process(delta: float) -> void:
	if contents.is_empty() or bool(SaveSystem.setting("reduced_effects")):
		return
	_surface_clock += delta
	if _surface_clock >= 0.12:
		_surface_clock = 0.0
		queue_redraw()


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


## Pour anticipation: the tube leans toward its target and settles back.
func play_pour_tilt(direction: float) -> void:
	if bool(SaveSystem.setting("reduced_effects")):
		return
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	rotation_degrees = 0.0
	var lean := clampf(direction, -1.0, 1.0) * 9.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "rotation_degrees", lean, 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "rotation_degrees", 0.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


## Colorblind support: every potion color carries a unique sigil so liquids
## can be told apart without hue. Flame = red, leaf cross = green,
## wave = blue, diamond = purple, ring = wild.
func _draw_color_sigil(color_id: String, at: Vector2, radius: float) -> void:
	var ink := Color(1, 1, 1, 0.82)
	var shadow := Color(0, 0, 0, 0.45)
	match color_id:
		"red":
			var flame := PackedVector2Array([at + Vector2(0, -radius),
					at + Vector2(radius * 0.8, radius * 0.7),
					at + Vector2(-radius * 0.8, radius * 0.7)])
			draw_colored_polygon(flame, shadow)
			draw_polyline(PackedVector2Array([flame[0], flame[1], flame[2],
					flame[0]]), ink, 2.0, true)
		"green":
			draw_line(at + Vector2(0, -radius), at + Vector2(0, radius), shadow, 5.0)
			draw_line(at + Vector2(-radius, 0), at + Vector2(radius, 0), shadow, 5.0)
			draw_line(at + Vector2(0, -radius), at + Vector2(0, radius), ink, 2.5, true)
			draw_line(at + Vector2(-radius, 0), at + Vector2(radius, 0), ink, 2.5, true)
		"blue":
			for wave_row in [-0.4, 0.4]:
				var points := PackedVector2Array()
				for step in 7:
					var t := float(step) / 6.0
					points.append(at + Vector2((t - 0.5) * radius * 2.0,
							wave_row * radius + sin(t * TAU) * radius * 0.3))
				draw_polyline(points, shadow, 4.5)
				draw_polyline(points, ink, 2.0, true)
		"purple":
			var diamond := PackedVector2Array([at + Vector2(0, -radius),
					at + Vector2(radius, 0), at + Vector2(0, radius),
					at + Vector2(-radius, 0)])
			draw_colored_polygon(diamond, shadow)
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2],
					diamond[3], diamond[0]]), ink, 2.0, true)
		_:
			draw_arc(at, radius * 0.8, 0, TAU, 20, shadow, 4.5)
			draw_arc(at, radius * 0.8, 0, TAU, 20, ink, 2.0, true)


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

	# Board guidance: legal pour targets glow, illegal ones recede. This is the
	# visual half of PuzzleBoard._refresh_guidance and Assist Mode.
	if guidance_state == "valid" and not selected:
		draw_circle(Vector2(cx, h * 0.61), w * 0.58, Color(0.55, 0.95, 0.62, 0.20))
		draw_arc(Vector2(cx, h * 0.58), w * 0.52, 0, TAU, 40,
				Color(0.62, 1.0, 0.70, 0.55), 3.0, true)

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
			if bool(SaveSystem.setting("reduced_effects")):
				draw_line(Vector2(inner_left, seg_top + 2.0),
						Vector2(inner_left + inner_w, seg_top + 2.0),
						color.lightened(0.55), 3.0, true)
			else:
				# Live liquid surface: a slow sine ripple so potions read as
				# fluid rather than painted blocks.
				var phase := Time.get_ticks_msec() / 1000.0 * 2.2 \
						+ float(get_index()) * 1.7
				var points := PackedVector2Array()
				for step in 9:
					var t := float(step) / 8.0
					points.append(Vector2(inner_left + inner_w * t,
							seg_top + 2.0 + sin(t * 9.0 + phase) * 1.6))
				draw_polyline(points, color.lightened(0.55), 3.0, true)
		var bubble_r := maxf(1.5, w * 0.025)
		draw_circle(Vector2(inner_left + inner_w * (0.67 if i % 2 == 0 else 0.78),
				seg_top + seg_h * 0.55), bubble_r, Color(1, 1, 1, 0.28))
		if bool(SaveSystem.setting("color_patterns")) \
				and not has_layer_effect(i, "hidden"):
			_draw_color_sigil(contents[i],
					Vector2(inner_left + inner_w * 0.5, seg_top + seg_h * 0.5),
					minf(inner_w, seg_h) * 0.30)
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

	# Keyboard/controller focus ring for non-touch accessibility.
	if has_focus():
		draw_rect(Rect2(2, 2, w - 4, h - 4), Color("ffd36b"), false, 3.0)

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
