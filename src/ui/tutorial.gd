class_name Tutorial
extends Control
## Full-screen guided tutorial spotlight. Four dim panels leave a real input
## window around the active target while the instruction card stays readable.

var director: TutorialDirector
var screen: Control
var target_resolver: Callable
var dim_panels: Array[ColorRect] = []
var card: PanelContainer
var title_label: Label
var body_label: Label
var progress_label: Label
var continue_button: Button
var pointer: Label
var _target: Control


func setup(host: Control, tutorial_director: TutorialDirector,
		resolver: Callable) -> void:
	screen = host; director = tutorial_director; target_resolver = resolver
	name = "TutorialOverlay"; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE; z_index = 90
	_build()
	director.step_changed.connect(_show_step)
	director.completed.connect(_close)
	director.skipped.connect(_close)
	_show_step(director.current_step(), director.index, director.steps.size())
	set_process(true)


func _build() -> void:
	for panel_name in ["TutorialDimTop", "TutorialDimBottom", "TutorialDimLeft", "TutorialDimRight"]:
		var dim := ColorRect.new(); dim.name = panel_name
		dim.color = Color(0.005, 0.003, 0.012, 0.78); dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim); dim_panels.append(dim)
	pointer = Label.new(); pointer.name = "TutorialPointer"; pointer.text = "▼"
	pointer.add_theme_font_size_override("font_size", 38); pointer.add_theme_color_override("font_color", Color("ffd56b"))
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(pointer)
	card = UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 24)
	card.name = "TutorialCard"; card.custom_minimum_size = Vector2(520, 230)
	add_child(card)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 9); card.add_child(box)
	var top := HBoxContainer.new(); box.add_child(top)
	progress_label = UiKit.label("1 / 10", 14, Color("c99cff")); progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(progress_label)
	var skip := UiKit.button("SKIP", Vector2(100, 42), Color("bda8c9")); skip.name = "TutorialSkip"
	skip.add_theme_font_size_override("font_size", 14); skip.pressed.connect(func(): director.skip()); top.add_child(skip)
	title_label = UiKit.title_label("", 25); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; box.add_child(title_label)
	body_label = UiKit.label("", 17, UiKit.COLOR_TEXT); body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(body_label)
	continue_button = UiKit.ornate_button("GOT IT", Vector2(220, 52)); continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_continue_info); box.add_child(continue_button)


func _show_step(step: Dictionary, index: int, total: int) -> void:
	if step.is_empty(): return
	visible = true; progress_label.text = "GUIDED RUN  •  %d / %d" % [index + 1, total]
	title_label.text = str(step.get("title", "Tutorial"))
	body_label.text = str(step.get("body", ""))
	var action := str(step.get("action", ""))
	continue_button.visible = action in ["intro", "inspect_enemy", "inspect_intent", "gain_mana"]
	_target = target_resolver.call(str(step.get("target", ""))) as Control
	_update_layout()


func _continue_info() -> void:
	var action := str(director.current_step().get("action", ""))
	if director.accept_action(action) and action == "gain_mana" and screen.has_method("tutorial_fill_mana"):
		screen.call("tutorial_fill_mana")


func _process(_delta: float) -> void:
	_update_layout()
	if pointer.visible:
		pointer.position.y += sin(Time.get_ticks_msec() * 0.008) * 0.18


func _update_layout() -> void:
	if size.x <= 0 or size.y <= 0: return
	var focus := Rect2(size * 0.5 - Vector2(100, 60), Vector2(200, 120))
	if _target != null and is_instance_valid(_target):
		var local_pos := get_global_transform().affine_inverse() * _target.global_position
		focus = Rect2(local_pos - Vector2(10, 8), _target.size + Vector2(20, 16))
	focus.position.x = clampf(focus.position.x, 8, size.x - 90)
	focus.position.y = clampf(focus.position.y, 8, size.y - 90)
	focus.size.x = minf(focus.size.x, size.x - focus.position.x - 8)
	focus.size.y = minf(focus.size.y, size.y - focus.position.y - 8)
	dim_panels[0].position = Vector2.ZERO; dim_panels[0].size = Vector2(size.x, focus.position.y)
	dim_panels[1].position = Vector2(0, focus.end.y); dim_panels[1].size = Vector2(size.x, maxf(0, size.y - focus.end.y))
	dim_panels[2].position = Vector2(0, focus.position.y); dim_panels[2].size = Vector2(focus.position.x, focus.size.y)
	dim_panels[3].position = Vector2(focus.end.x, focus.position.y); dim_panels[3].size = Vector2(maxf(0, size.x - focus.end.x), focus.size.y)
	card.size = Vector2(minf(560, size.x - 32), 230)
	card.position.x = (size.x - card.size.x) * 0.5
	card.position.y = 92 if focus.position.y > size.y * 0.52 else size.y - card.size.y - 36
	pointer.size = Vector2(60, 50); pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.position = Vector2(focus.get_center().x - 30, focus.position.y - 46)
	pointer.visible = _target != null


func _close() -> void:
	set_process(false)
	var tween := create_tween(); tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
