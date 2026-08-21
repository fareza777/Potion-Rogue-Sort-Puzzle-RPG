extends Node
## Global orchestration only. RunState remains authoritative at every moment.

const PLAYER_SCENE := preload("res://scenes/storyboard_player.tscn")
const CRITICAL_TRIGGERS := ["battle_defeat", "run_epilogue", "battle_victory"]

var _director := StoryboardDirector.new()
var _layer: CanvasLayer
var _current: StoryboardPlayer
var _busy := false
var _pending: Dictionary = {}


func play(trigger: String, overrides := {}) -> bool:
	var context := StoryboardContext.from_run(trigger, overrides)
	var sequence := _director.compose(trigger, context)
	if sequence.is_empty():
		return false
	if _busy:
		if trigger in CRITICAL_TRIGGERS and _pending.is_empty():
			_pending = {"trigger":trigger, "overrides":(overrides as Dictionary).duplicate(true)}
		return false
	_busy = true
	_ensure_layer()
	_current = PLAYER_SCENE.instantiate()
	_layer.add_child(_current)
	_current.set_reduced_effects(bool(SaveSystem.setting("reduced_effects")))
	for beat in sequence:
		if RunState.active:
			RunState.record_replay("story_beat", {"id":str(beat.get("id", "")),
					"trigger":trigger})
	_current.play(sequence)
	await _current.finished
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
	_busy = false
	if not _pending.is_empty():
		var queued := _pending.duplicate(true)
		_pending = {}
		call_deferred("_play_pending", queued)
	return true


func is_playing() -> bool:
	return _busy


## Regular victories should reveal their reward immediately. The authored
## full-screen outcome painting is reserved for the final boss, where it reads
## as a campaign beat instead of looking like a stray enemy screen.
func should_play_victory_story(encounter_kind: String, is_last: bool) -> bool:
	return is_last or encounter_kind == "boss"


func cancel() -> void:
	_pending = {}
	if is_instance_valid(_current):
		_current.skip()


func _play_pending(request: Dictionary) -> void:
	await play(str(request.get("trigger", "")), request.get("overrides", {}))


func _ensure_layer() -> void:
	if is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.name = "StoryboardCanvas"
	_layer.layer = 200
	add_child(_layer)
