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
var _full_scene_shade: TextureRect
var _subject_halo: TextureRect
var _halo_gradient: Gradient
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
var _active_motion := "hover"
var _active_art_mode := "composite"
var _active_focal_point := Vector2(0.5, 0.42)
var _motes: AmbientParticles


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build_layers()
	set_process(true)
	visible = false


func set_reduced_effects(value: bool) -> void:
	_reduced_effects = value
	if _motes != null:
		_motes.set_reduced_effects(value)


func reduced_effects() -> bool:
	return _reduced_effects


func active_motion() -> String:
	return _active_motion


func active_art_mode() -> String:
	return _active_art_mode


func play(sequence: Array) -> void:
	_sequence.clear()
	for raw_beat in sequence:
		if typeof(raw_beat) == TYPE_DICTIONARY:
			_sequence.append((raw_beat as Dictionary).duplicate(true))
	_index = -1
	_completed = false
	visible = true
	if _motes != null:
		_motes.set_process(not _reduced_effects)
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
	_active_art_mode = str(beat.get("art_mode", "composite"))
	_active_focal_point = _read_focal_point(beat.get("focal_point", [0.5, 0.42]))
	_motes.set_palette(accent, Color("ffd06a").lerp(accent, 0.20))
	_background.texture = VisualRegistry.texture_or_null(str(beat.get("background", "")))
	_full_scene_shade.visible = _active_art_mode == "full_scene"
	_accent_veil.color = Color(accent, 0.12)
	_eyebrow.text = str(beat.get("eyebrow", "POTION ROGUE"))
	_title.text = str(beat.get("title", "THE STORY CONTINUES"))
	_body.text = str(beat.get("body", ""))
	var has_multiple_beats := _sequence.size() > 1
	_prompt.text = "TAP TO CONTINUE  •  HOLD TO SKIP" if has_multiple_beats \
			else "TAP TO CONTINUE"
	_skip_button.visible = has_multiple_beats
	_skip_button.text = "HOLD TO SKIP"
	if not has_multiple_beats:
		_holding_skip = false
	_configure_subject(beat, accent)
	_configure_layout(str(beat.get("layout", "hero_center")))
	_rebuild_pips(accent)
	var state := str(beat.get("music_state", "story_explore"))
	if AudioManager != null:
		AudioManager.set_scene_state(state)
	_play_transition(accent, float(beat.get("duration", 2.0)),
			str(beat.get("motion", "hover")), str(beat.get("transition", "crossfade")))
	if _active_art_mode == "full_scene":
		_auto_timer.stop()
	else:
		_auto_timer.start(maxf(float(beat.get("duration", 2.0)), 0.8))


func _configure_subject(beat: Dictionary, accent: Color) -> void:
	_subject.texture = null
	_subject.visible = false
	_subject_halo.visible = false
	if _active_art_mode == "full_scene":
		return
	var subjects: Array = beat.get("subjects", [])
	if subjects.is_empty():
		return
	var config: Dictionary = subjects[0]
	var texture := VisualRegistry.texture_or_null(str(config.get("texture", "")))
	if texture == null:
		return
	_subject.texture = texture
	_subject.visible = true
	_subject_halo.visible = true
	_halo_gradient.colors = PackedColorArray([Color(accent, 0.32), Color(accent, 0.0)])
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
	_subject_halo.anchor_left = _subject.anchor_left - 0.08
	_subject_halo.anchor_right = _subject.anchor_right + 0.08
	_subject_halo.anchor_top = _subject.anchor_top - 0.05
	_subject_halo.anchor_bottom = _subject.anchor_bottom + 0.05
	_subject_halo.offset_left = 0; _subject_halo.offset_right = 0
	_subject_halo.offset_top = 0; _subject_halo.offset_bottom = 0


func _play_transition(accent: Color, duration: float, motion: String, transition: String) -> void:
	_active_motion = motion
	var transition_duration := 0.16 if _reduced_effects else UiThemeTokens.motion("cinematic")
	var base_scale := Vector2.ONE * float(_subject.get_meta("story_scale", 1.0))
	var start_scale := base_scale
	var end_scale := base_scale
	var start_offset := Vector2.ZERO
	var end_offset := Vector2.ZERO
	var start_rotation := 0.0
	if not _reduced_effects:
		match motion:
			"slow_push":
				start_scale = base_scale * 0.91; end_scale = base_scale * 1.02
			"quick_push", "impact_push", "reveal_rise":
				start_scale = base_scale * 0.82; start_offset.y = 26.0
			"slow_retreat", "compress_fade", "fall_fade":
				start_scale = base_scale * 1.08; end_scale = base_scale * 0.96
				end_offset.y = 12.0
			"lateral_drift", "parallax_drift":
				start_offset.x = -30.0; end_offset.x = 10.0
			"danger_pulse", "threat_pulse", "memory_pulse":
				start_scale = base_scale * 0.94; end_scale = base_scale * 1.035
				start_rotation = -0.012
			"drift_up", "ember_hover", "hover", "prism_bloom", "relic_glow", \
					"rise_glow", "seal_glow":
				start_offset.y = 28.0; end_offset.y = -5.0
				start_scale = base_scale * 0.96; end_scale = base_scale * 1.015
			_:
				start_offset.y = 18.0
	modulate.a = 0.0
	var veil_color := accent
	var veil_peak := 0.34
	if "frost" in transition or "white" in transition or "prism" in transition:
		veil_color = accent.lightened(0.35); veil_peak = 0.46
	elif "ink" in transition or "shadow" in transition or "deep" in transition:
		veil_color = Color(0.015, 0.005, 0.035); veil_peak = 0.55
	_accent_veil.color = Color(veil_color, 0.10 if _reduced_effects else veil_peak)
	_background.pivot_offset = Vector2(_background.size.x * _active_focal_point.x,
			_background.size.y * _active_focal_point.y)
	_subject.pivot_offset = _subject.size * 0.5
	var background_start_scale := Vector2.ONE if _reduced_effects else \
			(Vector2(1.025, 1.025) if _active_art_mode == "full_scene" \
			else Vector2(1.035, 1.035))
	var background_end_scale := Vector2.ONE if _reduced_effects else \
			(Vector2(1.070, 1.070) if _active_art_mode == "full_scene" \
			else Vector2(1.085, 1.085))
	_background.scale = background_start_scale
	_background.modulate = Color(0.76, 0.78, 0.88, 1.0) \
			if (not _reduced_effects and ("ink" in transition or "shadow" in transition)) \
			else Color.WHITE
	var settled_position := _subject.position + end_offset
	_subject.position += start_offset
	_subject.scale = start_scale
	_subject.rotation = start_rotation
	if _subject.visible:
		_subject.modulate.a = 0.0
		_subject_halo.modulate.a = 0.0
	_caption_layer.position.y = 0.0 if _reduced_effects else 18.0
	_caption_layer.modulate.a = 0.0
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(self, "modulate:a", 1.0, transition_duration)
	_motion_tween.tween_property(_accent_veil, "color:a", 0.10, transition_duration)
	if _subject.visible:
		_motion_tween.tween_property(_subject, "modulate:a", 1.0, transition_duration)
		_motion_tween.tween_property(_subject_halo, "modulate:a", 0.82, transition_duration)
	_motion_tween.tween_property(_caption_layer, "modulate:a", 1.0, transition_duration)
	_motion_tween.tween_property(_caption_layer, "position:y", 0.0, transition_duration) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if not _reduced_effects:
		if _subject.visible:
			_motion_tween.tween_property(_subject, "position", settled_position,
					maxf(duration, transition_duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_motion_tween.tween_property(_subject, "scale", end_scale,
					maxf(duration, transition_duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_motion_tween.tween_property(_subject, "rotation", 0.0,
					transition_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_motion_tween.tween_property(_background, "modulate", Color.WHITE,
				transition_duration)
		_motion_tween.tween_property(_background, "scale", background_end_scale,
				maxf(duration, 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _rebuild_pips(accent: Color) -> void:
	for child in _pips.get_children():
		child.queue_free()
	_pips.visible = _sequence.size() > 1
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
	if _motes != null:
		_motes.set_process(false)
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
	_motes = AmbientParticles.new()
	_motes.name = "StoryMotes"
	_motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_atmosphere_layer.add_child(_motes)

	_subject_layer = _full_layer("SubjectLayer")
	_subject_halo = TextureRect.new()
	_subject_halo.name = "SubjectHalo"
	_halo_gradient = Gradient.new()
	_halo_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	_halo_gradient.colors = PackedColorArray([Color(0.62, 0.42, 0.85, 0.30), Color.TRANSPARENT])
	var halo_texture := GradientTexture2D.new()
	halo_texture.width = 256; halo_texture.height = 256
	halo_texture.fill = GradientTexture2D.FILL_RADIAL
	halo_texture.fill_from = Vector2(0.5, 0.5); halo_texture.fill_to = Vector2(1.0, 0.5)
	halo_texture.gradient = _halo_gradient
	_subject_halo.texture = halo_texture
	_subject_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_subject_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_subject_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subject_layer.add_child(_subject_halo)
	_subject = TextureRect.new()
	_subject.name = "StorySubject"
	_subject.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_subject.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_subject.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_subject.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subject_layer.add_child(_subject)

	_foreground_layer = _full_layer("ForegroundLayer")
	_full_scene_shade = TextureRect.new()
	_full_scene_shade.name = "FullSceneShade"
	_full_scene_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene_gradient := Gradient.new()
	scene_gradient.offsets = PackedFloat32Array([0.0, 0.50, 0.72, 1.0])
	scene_gradient.colors = PackedColorArray([
		Color(0.008, 0.003, 0.018, 0.04), Color(0.008, 0.003, 0.018, 0.08),
		Color(0.008, 0.003, 0.018, 0.58), Color(0.008, 0.003, 0.018, 0.94),
	])
	var scene_shade_texture := GradientTexture2D.new()
	scene_shade_texture.width = 16; scene_shade_texture.height = 512
	scene_shade_texture.fill = GradientTexture2D.FILL_LINEAR
	scene_shade_texture.fill_from = Vector2(0.5, 0.0)
	scene_shade_texture.fill_to = Vector2(0.5, 1.0)
	scene_shade_texture.gradient = scene_gradient
	_full_scene_shade.texture = scene_shade_texture
	_full_scene_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_full_scene_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_full_scene_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_scene_shade.visible = false
	_foreground_layer.add_child(_full_scene_shade)
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
	_auto_timer.name = "StoryboardAutoAdvance"
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


func _read_focal_point(value: Variant) -> Vector2:
	var point := Vector2(0.5, 0.42)
	if value is Vector2:
		point = value
	elif value is Array and value.size() >= 2:
		point = Vector2(float(value[0]), float(value[1]))
	return Vector2(clampf(point.x, 0.1, 0.9), clampf(point.y, 0.1, 0.9))
