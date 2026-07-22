class_name ReactionChamber
extends Button
## Three-slot factual history. It deliberately has no recipe prediction API.

signal codex_requested

const ESSENCE_COLORS := {
	"red": Color("ff5548"), "green": Color("55df72"),
	"blue": Color("4ba8ff"), "purple": Color("b85cff"),
	"wild": Color("f4ca62"),
}

var _history: Array[String] = []
var _sockets: HBoxContainer
var _activation_tween: Tween


func _init() -> void:
	name = "ReactionChamber"
	custom_minimum_size = Vector2(138, 58)
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "REACTION CHAMBER\nLast three completed potion essences. Order creates reactions. Tap for formulas."
	for state in ["normal", "hover", "pressed", "focus"]:
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.045, 0.02, 0.075, 0.88 if state == "normal" else 0.96)
		frame.border_color = Color("8d6bb5", 0.55 if state == "normal" else 0.9)
		frame.set_border_width_all(1); frame.set_corner_radius_all(14)
		frame.content_margin_left = 10; frame.content_margin_right = 10
		frame.content_margin_top = 8; frame.content_margin_bottom = 8
		add_theme_stylebox_override(state, frame)
	_sockets = HBoxContainer.new()
	_sockets.name = "Sockets"
	_sockets.alignment = BoxContainer.ALIGNMENT_CENTER
	_sockets.add_theme_constant_override("separation", 8)
	_sockets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sockets)
	pressed.connect(func() -> void: codex_requested.emit())
	_render_sockets()


func set_history(colors: Array[String]) -> void:
	_history.clear()
	var start := maxi(colors.size() - 3, 0)
	for index in range(start, colors.size()):
		var color := str(colors[index])
		if ESSENCE_COLORS.has(color): _history.append(color)
	_render_sockets()


func essence_ids() -> Array[String]:
	return _history.duplicate()


func play_activation(payload: Dictionary) -> void:
	if bool(SaveSystem.setting("reduced_effects")): return
	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()
	modulate = Color.WHITE; scale = Vector2.ONE; pivot_offset = size * 0.5
	var tint := Color("d99aff")
	var tags: Array = payload.get("tags", [])
	if "fire" in tags: tint = Color("ffb05b")
	elif "ward" in tags: tint = Color("73c8ff")
	elif "healing" in tags: tint = Color("77ed96")
	_activation_tween = create_tween().set_parallel(true)
	_activation_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_activation_tween.tween_property(self, "modulate", tint, 0.12)
	_activation_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.2)
	_activation_tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func _render_sockets() -> void:
	if _sockets == null: return
	for child in _sockets.get_children():
		_sockets.remove_child(child)
		child.free()
	for slot_index in 3:
		var socket := PanelContainer.new()
		socket.custom_minimum_size = Vector2(30, 30)
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		var history_index := slot_index - (3 - _history.size())
		var filled := history_index >= 0
		var essence := _history[history_index] if filled else ""
		style.bg_color = ESSENCE_COLORS.get(essence, Color(0.16, 0.12, 0.22, 0.78))
		style.border_color = Color.WHITE if filled else Color("756889")
		style.border_color.a = 0.72 if filled else 0.48
		style.set_border_width_all(2); style.set_corner_radius_all(15)
		style.shadow_color = Color(style.bg_color, 0.5 if filled else 0.0)
		style.shadow_size = 5 if filled else 0
		socket.add_theme_stylebox_override("panel", style)
		_sockets.add_child(socket)
