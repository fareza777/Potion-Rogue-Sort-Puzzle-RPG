extends Control
## Branded handoff between the native splash and the first playable screen.
##
## The engine splash, this screen and the destination all share one background
## colour, and the destination is streamed on a worker thread while the crest
## animates. Nothing is ever swapped on a frame the player can see uncovered,
## which is what used to expose the raw clear colour as a grey flash.

## The crest never disappears faster than this, however quickly the next scene
## streams in — a splash that blinks past reads as a glitch, not as polish.
const MIN_SPLASH_SECONDS := 1.15
const LOADING_STEPS := ["DISTILLING THE DUNGEON", "WARMING THE ALEMBICS",
	"SEALING THE FLASKS"]

var _loading: Label
var _progress_fill: ColorRect
var _progress_track: Control
var _step := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var art := UiKit.battle_background(self,
			"res://assets/art/backgrounds/launch_splash_v3.jpg")
	art.modulate = Color(0.9, 0.94, 1.0, 0.0)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.002, 0.018, 0.22)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var stack := VBoxContainer.new()
	stack.name = "BootCrest"
	stack.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stack.position = Vector2(-300, 58)
	stack.size = Vector2(600, 180)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.modulate.a = 0.0
	add_child(stack)
	var title := UiKit.title_label("POTION ROGUE", 58, Color("f1cf79"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := UiKit.label("SORT  •  BREW  •  CONQUER", 17, Color("d8b6ff"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)

	_build_progress()
	# The veil starts opaque so the very first drawn frame is already the crest
	# fading up, never a half-built scene.
	SceneRouter.reveal(0.28)
	_play_intro(art, stack)
	await _hand_off()


func _build_progress() -> void:
	var holder := VBoxContainer.new()
	holder.name = "BootProgress"
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.offset_left = -160
	holder.offset_right = 160
	holder.offset_top = -132
	holder.offset_bottom = -70
	holder.add_theme_constant_override("separation", 12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_loading = UiKit.label(LOADING_STEPS[0] + "…", 13, Color("8edcff"))
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The splash art is busy right where this sits.
	_loading.add_theme_constant_override("outline_size", 5)
	_loading.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05, 0.92))
	holder.add_child(_loading)

	_progress_track = Control.new()
	_progress_track.name = "BootProgressTrack"
	_progress_track.custom_minimum_size = Vector2(320, 3)
	_progress_track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_progress_track)
	var track_bg := ColorRect.new()
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_bg.color = Color("f1cf79", 0.16)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_track.add_child(track_bg)
	_progress_fill = ColorRect.new()
	_progress_fill.name = "BootProgressFill"
	_progress_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_progress_fill.offset_right = 0
	_progress_fill.color = Color("f1cf79", 0.9)
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_track.add_child(_progress_fill)


func _play_intro(art: TextureRect, crest: VBoxContainer) -> void:
	crest.pivot_offset = crest.size * 0.5
	crest.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(art, "modulate:a", 1.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(crest, "modulate:a", 1.0, 0.55).set_delay(0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(crest, "scale", Vector2.ONE, 0.85).set_delay(0.10) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_loading, "modulate:a", 0.42, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_loading, "modulate:a", 1.0, 0.75) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Streams the destination while the crest plays, then hands over through the
## router so the swap itself is covered by the veil.
func _hand_off() -> void:
	var destination := "res://scenes/main_menu.tscn" if SaveSystem.is_onboarding_done() \
			else "res://scenes/onboarding.tscn"
	var started := Time.get_ticks_msec()
	ResourceLoader.load_threaded_request(destination, "PackedScene")
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(destination, progress)
		var ratio := float(progress[0]) if not progress.is_empty() else 0.0
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		# The bar tracks whichever is further behind: a cached scene that loads
		# instantly must not snap the bar to full and sit there, and a slow load
		# must not be hidden by the clock.
		_advance_progress(minf(minf(ratio, elapsed / MIN_SPLASH_SECONDS), 0.98))
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS \
				and elapsed >= MIN_SPLASH_SECONDS:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED \
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			break
		await get_tree().process_frame
	_advance_progress(1.0)
	SceneRouter.go_to(destination)


func _advance_progress(ratio: float) -> void:
	if not is_instance_valid(_progress_fill):
		return
	_progress_fill.offset_right = _progress_track.size.x * clampf(ratio, 0.0, 1.0)
	var step := clampi(int(ratio * float(LOADING_STEPS.size())), 0, LOADING_STEPS.size() - 1)
	if step != _step:
		_step = step
		_loading.text = LOADING_STEPS[step] + "…"
