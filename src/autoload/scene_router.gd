extends CanvasLayer
## Autoload: SceneRouter
## Every scene change in the game goes through here. A full-screen veil covers
## the swap so the engine clear colour is never visible, and the next scene is
## loaded on a worker thread so the main loop keeps drawing while it streams in.
##
## Without this, `change_scene_to_file` frees the running scene and blocks the
## main thread until the replacement finishes loading: the player sees the raw
## clear colour for as long as the load takes.

const VEIL_COLOR := Color(0.008, 0.004, 0.025, 1.0)
const FADE_OUT := 0.16
const FADE_IN := 0.24
## The veil is held for at least this long so very fast swaps still read as a
## deliberate transition instead of a flicker.
const MIN_VEIL_SECONDS := 0.10

signal transition_started(path: String)
signal transition_finished(path: String)

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.name = "TransitionVeil"
	_veil.color = VEIL_COLOR
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	_veil.visible = false
	add_child(_veil)


func is_transitioning() -> bool:
	return _busy


## Fades out, streams the scene in on a worker thread, swaps, fades back in.
## Safe to call from a node that is about to be freed: the whole sequence runs
## on this autoload.
func go_to(path: String) -> void:
	if _busy or path.is_empty():
		return
	_busy = true
	transition_started.emit(path)
	await _fade_to(1.0, FADE_OUT)
	# Taps during the swap would land on whichever scene happens to exist.
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var held_since := Time.get_ticks_msec()
	var packed := await _load_threaded(path)
	if packed == null:
		# A failed stream must never strand the player behind the veil.
		push_warning("SceneRouter: threaded load failed for %s, loading directly." % path)
		get_tree().change_scene_to_file(path)
	else:
		get_tree().change_scene_to_packed(packed)
	# The swap is deferred: give the incoming scene a frame to build its tree
	# and a second one to render before anything is revealed.
	await get_tree().process_frame
	await get_tree().process_frame
	var held := (Time.get_ticks_msec() - held_since) / 1000.0
	if held < MIN_VEIL_SECONDS:
		await get_tree().create_timer(MIN_VEIL_SECONDS - held).timeout
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _fade_to(0.0, FADE_IN)
	_busy = false
	transition_finished.emit(path)


## Reveals whatever is on screen right now. The boot screen uses this to hand
## over from the native splash without a flash.
func reveal(duration := FADE_IN) -> void:
	if _veil == null:
		return
	_veil.visible = true
	_veil.modulate.a = 1.0
	await _fade_to(0.0, duration)


func _fade_to(alpha: float, duration: float) -> void:
	_veil.visible = true
	if is_equal_approx(_veil.modulate.a, alpha):
		_veil.visible = alpha > 0.0
		return
	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", alpha, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_veil.visible = alpha > 0.0


func _load_threaded(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		return null
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return null
		await get_tree().process_frame
	return null
