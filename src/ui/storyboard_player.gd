class_name StoryboardPlayer
extends Control
## Five-layer portrait cinematic renderer for deterministic authored beats.

signal finished(skipped: bool)

var _background_layer: Control
var _atmosphere_layer: Control
var _subject_layer: Control
var _foreground_layer: Control
var _caption_layer: Control
var _background: TextureRect
var _accent_veil: ColorRect
var _subject: TextureRect
var _eyebrow: Label
var _title: Label
var _body: Label
var _prompt: Label
var _pips: HBoxContainer
var _skip_button: Button
var _auto_timer: Timer
var _sequence: Array[Dictionary] = []
var _index := -1
var _beat_started_msec := 0
var _reduced_effects := false
var _holding_skip := false
var _skip_started_msec := 0
var _motion_tween: Tween
var _completed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build_layers()
	set_process(true)
	visible = false


func set_reduced_effects(value: bool) -> void:
	_reduced_effects = value


func reduced_effects() -> bool:
	return _reduced_effects


func play(sequence: Array) -> void:
	_sequence.clear()
	for raw_beat in sequence:
		if typeof(raw_beat) == TYPE_DICTIONARY:
			_sequence.append((raw_beat as Dictionary).duplicate(true))
	_index = -1
	_completed = false
	visible = true
	if _sequence.is_empty():
		_finish(false)
		return
	_advance()


func skip() -> void:
	if visible and not _completed:
		_finish(true)


func advance() -> void:
	if not visible or _completed:
		return
	if Time.get_ticks_msec() - _beat_started_msec < 220:
		return
	_advance()


func _advance() -> void:
	_stop_motion()
	_index += 1
	if _index >= _sequence.size():
		_finish(false)
		return
	_show_beat(_sequence[_index])


func _show_beat(beat: Dictionary) -> void:
	_beat_started_msec = Time.get_ticks_msec()
	var accent := Color(str(beat.get("accent", "9f6bd2")))
	_background.texture = VisualRegistry.texture_or_null(str(beat.get("background", "")))
	_accent_veil.color = Color(accent, 0.12)
	_eyebrow.text = str(beat.get("eyebrow", "POTION ROGUE"))
	_title.text = str(beat.get("title", "THE STORY CONTINUES"))
	_body.text = str(beat.get("body", ""))
	_prompt.text = "TAP TO CONTINUE  •  HOLD TO SKIP"
	_configure_subject(beat, accent)
	_configure_layout(str(beat.get("layout", "hero_center")))
	_rebuild_pips(accent)
	var state := str(beat.get("music_state", "story_explore"))
	if AudioManager != null:
		AudioManager.set_scene_state(state)
	_play_transition(accent, float(beat.get("duration", 2.0)))
	_auto_timer.start(maxf(float(beat.get("duration", 2.0)), 0.8))


func _configure_subject(beat: Dictionary, accent: Color) -> void:
	_subject.texture = null
	_subject.visible = false
	var subjects: Array = beat.get("subjects", [])
	if subjects.is_empty():
		return
	var config: Dictionary = subjects[0]
	var texture := VisualRegistry.texture_or_null(str(config.get("texture", "")))
	if texture == null:
		return
	_subject.texture = texture
	_subject.visible = true
	_subject.modulate = Color(1.05, 1.02, 1.08, 1.0)
	_subject.set_meta("story_scale", clampf(float(config.get("scale", 1.0)), 0.55, 1.25))
	_subject.tooltip_text = str(config.get("enemy_id", "Cinematic subject")).replace("_", " ").capitalize()
	_subject.add_theme_color_override("default_color", accent)


func _configure_layout(layout: String) -> void:
	_subject.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match layout:
		"subject_left":
			_subject.anchor_left = -0.05; _subject.anchor_right = 0.68
			_subject.anchor_top = 0.12; _subject.anchor_bottom = 0.73
		"subject_right":
			_subject.anchor_left = 0.32; _subject.anchor_right = 1.05
			_subject.anchor_top = 0.12; _subject.anchor_bottom = 0.73
		"split_omen":
			_subject.anchor_left = 0.36; _subject.anchor_right = 0.98
			_subject.anchor_top = 0.20; _subject.anchor_bottom = 0.70
		"panorama":
			_subject.anchor_left = 0.18; _subject.anchor_right = 0.82
			_subject.anchor_top = 0.18; _subject.anchor_bottom = 0.66
		_:
			_subject.anchor_left = 0.10; _subject.anchor_right = 0.90
			_subject.anchor_top = 0.13; _subject.anchor_bottom = 0.72
	_subject.offset_left = 0; _subject.offset_right = 0
	_subject.offset_top = 0; _subject.offset_bottom = 0


func _play_transition(accent: Color, duration: float) -> void:
	var transition_duration := 0.16 if _reduced_effects else UiThemeTokens.motion("cinematic")
	modulate.a = 0.0
	_accent_veil.color = Color(accent, 0.34 if not _reduced_effects else 0.10)
	_background.pivot_offset = _background.size * 0.5
	_subject.pivot_offset = _subject.size * 0.5
	_background.scale = Vector2.ONE if _reduced_effects else Vector2(1.035, 1.035)
	_subject.position.y += 0.0 if _reduced_effects else 24.0
	_subject.modulate.a = 0.0
	_caption_layer.position.y = 0.0 if _reduced_effects else 18.0
	_caption_layer.modulate.a = 0.0
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(self, "modulate:a", 1.0, transition_duration)
	_motion_tween.tween_property(_accent_veil, "color:a", 0.10, transition_duration)
	_motion_tween.tween_property(_subject, "modulate:a", 1.0, transition_duration)
	_motion_tween.tween_property(_caption_layer, "modulate:a", 1.0, transition_duration)
	_motion_tween.tween_property(_caption_layer, "position:y", 0.0, transition_duration) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if not _reduced_effects:
		_motion_tween.tween_property(_subject, "position:y", _subject.position.y - 24.0,
				transition_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		_motion_tween.tween_property(_background, "scale", Vector2(1.085, 1.085),
				maxf(duration, 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _rebuild_pips(accent: Color) -> void:
	for child in _pips.get_children():
		child.queue_free()
	for pip_index in _sequence.size():
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(22 if pip_index == _index else 10, 6)
		var style := StyleBoxFlat.new()
		style.bg_color = accent if pip_index == _index else Color(1, 1, 1, 0.28)
		style.set_corner_radius_all(4)
		pip.add_theme_stylebox_override("panel", style)
		_pips.add_child(pip)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		advance()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		advance()
		accept_event()


func _process(_delta: float) -> void:
	if _holding_skip and Time.get_ticks_msec() - _skip_started_msec >= 650:
		_holding_skip = false
		skip()


func _finish(was_skipped: bool) -> void:
	if _completed:
		return
	_completed = true
	_stop_motion()
	visible = false
	finished.emit(was_skipped)


func _stop_motion() -> void:
	if _auto_timer != null:
		_auto_timer.stop()
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _exit_tree() -> void:
	_stop_motion()


func _build_layers() -> void:
	_background_layer = _full_layer("BackgroundLayer")
	_background = TextureRect.new()
	_background.name = "StoryBackground"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_layer.add_child(_background)

	_atmosphere_layer = _full_layer("AtmosphereLayer")
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.01, 0.003, 0.025, 0.36)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmosphere_layer.add_child(vignette)
	_accent_veil = ColorRect.new()
	_accent_veil.name = "TransitionVeil"
	_accent_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_accent_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmosphere_layer.add_child(_accent_veil)

	_subject_layer = _full_layer("SubjectLayer")
	_subject = TextureRect.new()
	_subject.name = "StorySubject"
	_subject.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_subject.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_subject.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_subject.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subject_layer.add_child(_subject)

	_foreground_layer = _full_layer("ForegroundLayer")
	var top_bar := ColorRect.new()
	top_bar.anchor_right = 1.0; top_bar.offset_bottom = 92
	top_bar.color = Color(0.008, 0.003, 0.018, 0.70)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground_layer.add_child(top_bar)
	var bottom_shade := ColorRect.new()
	bottom_shade.anchor_top = 0.66; bottom_shade.anchor_right = 1.0
	bottom_shade.anchor_bottom = 1.0
	bottom_shade.color = Color(0.008, 0.003, 0.018, 0.80)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground_layer.add_child(bottom_shade)
	var ornament := TextureRect.new()
	ornament.anchor_left = 0.04; ornament.anchor_right = 0.96
	ornament.anchor_top = 0.655; ornament.anchor_bottom = 0.725
	ornament.texture = VisualRegistry.texture_or_null("res://assets/art/ui/banner_turn.png")
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_SCALE
	ornament.modulate = Color(1, 0.88, 0.58, 0.78)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground_layer.add_child(ornament)

	_caption_layer = _full_layer("CaptionLayer")
	_build_caption()
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.timeout.connect(_advance)
	add_child(_auto_timer)


func _full_layer(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func _build_caption() -> void:
	var margin := MarginContainer.new()
	margin.anchor_left = 0.06; margin.anchor_right = 0.94
	margin.anchor_top = 0.70; margin.anchor_bottom = 0.96
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_caption_layer.add_child(margin)
	var surface := QuietSurface.new().set_accent(Color("d9b85e"), 0.78)
	margin.add_child(surface)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", UiThemeTokens.space("sm"))
	surface.add_child(copy)
	_eyebrow = UiKit.caption_label("POTION ROGUE", Color("9edfff"))
	_eyebrow.name = "StoryEyebrow"
	copy.add_child(_eyebrow)
	_title = UiKit.title_label("THE STORY CONTINUES", 34, Color("f5d681"))
	_title.name = "StoryTitle"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_title)
	_body = UiKit.body_label("", UiKit.COLOR_TEXT)
	_body.name = "StoryBody"
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(_body)
	_prompt = UiKit.caption_label("TAP TO CONTINUE  •  HOLD TO SKIP", UiKit.COLOR_TEXT_DIM)
	_prompt.name = "StoryPrompt"
	copy.add_child(_prompt)

	_pips = HBoxContainer.new()
	_pips.name = "ProgressPips"
	_pips.anchor_left = 0.5; _pips.anchor_right = 0.5
	_pips.offset_left = -90; _pips.offset_right = 90
	_pips.offset_top = 34; _pips.offset_bottom = 52
	_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips.add_theme_constant_override("separation", 7)
	_caption_layer.add_child(_pips)
	_skip_button = UiKit.button("HOLD TO SKIP", Vector2(170, 58), Color("d9b85e"))
	_skip_button.name = "StoryboardSkip"
	_skip_button.anchor_left = 1.0; _skip_button.anchor_right = 1.0
	_skip_button.offset_left = -194; _skip_button.offset_right = -20
	_skip_button.offset_top = 20; _skip_button.offset_bottom = 78
	_skip_button.add_theme_font_size_override("font_size", 15)
	_skip_button.button_down.connect(func() -> void:
		_holding_skip = true
		_skip_started_msec = Time.get_ticks_msec()
		_skip_button.text = "KEEP HOLDING…")
	_skip_button.button_up.connect(func() -> void:
		_holding_skip = false
		_skip_button.text = "HOLD TO SKIP")
	_caption_layer.add_child(_skip_button)
