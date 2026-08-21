class_name Tutorial
extends Control
## Full-screen guided tutorial spotlight. Four dim panels leave a real input
## window around the active target while the instruction card stays readable.

const INFO_ACTIONS := ["intro", "play"]

var director: TutorialDirector
var screen: Control
var target_resolver: Callable
var dim_panels: Array[ColorRect] = []
var card: PanelContainer
var card_box: VBoxContainer
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
		dim.color = Color(0.005, 0.003, 0.012, 0.72); dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim); dim_panels.append(dim)
	pointer = Label.new(); pointer.name = "TutorialPointer"; pointer.text = "▼"
	pointer.add_theme_font_size_override("font_size", 36)
	pointer.add_theme_color_override("font_color", Color("ffd56b"))
	pointer.add_theme_color_override("font_outline_color", Color(0.07, 0.03, 0.11, 0.9))
	pointer.add_theme_constant_override("outline_size", 6)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(pointer)
	card = PanelContainer.new()
	card.name = "TutorialCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.clip_contents = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.045, 0.13, 0.97)
	style.border_color = Color("e8c069")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	card_box = VBoxContainer.new()
	card_box.name = "TutorialCardBox"
	card_box.add_theme_constant_override("separation", 10)
	card.add_child(card_box)
	var top := HBoxContainer.new(); card_box.add_child(top)
	progress_label = UiKit.label("1 / 4", 13, Color("c99cff"))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(progress_label)
	var skip := UiKit.button("SKIP", Vector2(92, 40), Color("bda8c9")); skip.name = "TutorialSkip"
	skip.add_theme_font_size_override("font_size", 14)
	skip.pressed.connect(func(): director.skip()); top.add_child(skip)
	title_label = UiKit.title_label("", 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = false
	card_box.add_child(title_label)
	body_label = UiKit.label("", 16, UiKit.COLOR_TEXT)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.clip_text = false
	body_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_box.add_child(body_label)
	continue_button = UiKit.cta_bar("GOT IT", UiKit.COLOR_GOLD, 52)
	continue_button.name = "TutorialContinue"
	continue_button.pressed.connect(_continue_info)
	card_box.add_child(continue_button)


func _show_step(step: Dictionary, index: int, total: int) -> void:
	if step.is_empty(): return
	visible = true
	progress_label.text = "GUIDED RUN  •  %d / %d" % [index + 1, total]
	title_label.text = str(step.get("title", "Tutorial")).to_upper()
	body_label.text = str(step.get("body", ""))
	var action := str(step.get("action", ""))
	continue_button.visible = action in INFO_ACTIONS
	var needs_board_input := action == "play"
	for dim in dim_panels:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE if needs_board_input \
				else Control.MOUSE_FILTER_STOP
	if action == "intro":
		_target = card
	else:
		_target = target_resolver.call(str(step.get("target", ""))) as Control
	_update_layout()


func _continue_info() -> void:
	var action := str(director.current_step().get("action", ""))
	director.accept_action(action)


func _process(_delta: float) -> void:
	_update_layout()
	if pointer.visible:
		pointer.position.y += sin(Time.get_ticks_msec() * 0.008) * 0.18


func _update_layout() -> void:
	if size.x <= 0 or size.y <= 0: return
	var card_width := minf(size.x - 40.0, 560.0)
	body_label.custom_minimum_size.x = maxf(card_width - 48.0, 200.0)
	title_label.custom_minimum_size.x = body_label.custom_minimum_size.x
	card.reset_size()
	var wanted := card.get_combined_minimum_size()
	var card_height := clampf(wanted.y, 156.0, minf(size.y * 0.36, size.y - 72.0))
	card.size = Vector2(card_width, card_height)
	card.position.x = (size.x - card.size.x) * 0.5
	# Keep the lesson card at the top so the potion shelf stays fully tappable.
	card.position.y = 24.0
	var focus := Rect2(size * 0.5 - Vector2(100, 60), Vector2(200, 120))
	if _target != null and is_instance_valid(_target) and _target != card:
		var local_pos := get_global_transform().affine_inverse() * _target.global_position
		focus = Rect2(local_pos - Vector2(10, 8), _target.size + Vector2(20, 16))
	elif _target == card:
		focus = Rect2(card.position, card.size)
	focus.position.x = clampf(focus.position.x, 8, size.x - 90)
	focus.position.y = clampf(focus.position.y, 8, size.y - 90)
	focus.size.x = minf(focus.size.x, size.x - focus.position.x - 8)
	focus.size.y = minf(focus.size.y, size.y - focus.position.y - 8)
	dim_panels[0].position = Vector2.ZERO
	dim_panels[0].size = Vector2(size.x, focus.position.y)
	dim_panels[1].position = Vector2(0, focus.end.y)
	dim_panels[1].size = Vector2(size.x, maxf(0, size.y - focus.end.y))
	dim_panels[2].position = Vector2(0, focus.position.y)
	dim_panels[2].size = Vector2(focus.position.x, focus.size.y)
	dim_panels[3].position = Vector2(focus.end.x, focus.position.y)
	dim_panels[3].size = Vector2(maxf(0, size.x - focus.end.x), focus.size.y)
	pointer.size = Vector2(60, 50); pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pointer.position = Vector2(focus.get_center().x - 30, focus.position.y - 46)
	var action := str(director.current_step().get("action", "")) if director != null else ""
	pointer.visible = _target != null and _target != card and action in ["select_source", "select_target"]


func _close() -> void:
	set_process(false)
	var tween := create_tween(); tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
