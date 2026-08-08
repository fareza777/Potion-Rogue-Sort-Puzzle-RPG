extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 78)
	var event_screen: Node = load("res://scenes/event.tscn").instantiate()
	add_child(event_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var choice_box := event_screen.get("choice_box") as VBoxContainer
	check(choice_box != null, "event screen exposes its authored choices")
	if choice_box == null:
		finish(event_screen)
		return
	var buttons := choice_box.get_children().filter(func(child): return child is BaseButton)
	check(not buttons.is_empty(), "event owns at least one choice")
	check(buttons.all(func(button): return (button as BaseButton).disabled),
			"permanent event choices stay disabled during the story reveal")
	var event_id := str(event_screen.get("event_id"))
	var event_resolver = event_screen.get("resolver")
	var choices: Dictionary = event_resolver.events.get(event_id, {}).get("choices", {})
	var first_choice := str(choices.keys()[0]) if not choices.is_empty() else ""
	var before := RunState.serialize_boundary()
	if not first_choice.is_empty():
		event_screen.call("_choose", first_choice)
		await get_tree().process_frame
	check(RunState.serialize_boundary() == before,
			"early keyboard or programmatic activation cannot apply an event choice")
	StoryboardService.cancel()
	await get_tree().process_frame
	await get_tree().process_frame
	check(event_screen.get("_reveal_complete") == true,
			"event explicitly records completion of the reveal")
	check(buttons.all(func(button): return not (button as BaseButton).disabled),
			"choices unlock only after the story panel closes")
	finish(event_screen)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)


func finish(event_screen: Node) -> void:
	StoryboardService.cancel()
	if is_instance_valid(event_screen):
		event_screen.queue_free()
	AudioManager.stop_music()
	await get_tree().create_timer(0.08).timeout
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
