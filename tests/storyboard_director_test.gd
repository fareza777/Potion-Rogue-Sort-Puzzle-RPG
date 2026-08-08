extends Node

const TRIGGERS := ["run_intro", "realm_arrival", "route_choice", "event_reveal",
		"event_resolution", "battle_intro", "battle_escalation",
		"battle_victory", "battle_defeat", "run_epilogue"]
const REQUIRED := ["id", "layout", "background", "title", "accent", "motion",
		"transition", "duration"]

var checks := 0
var failures := 0


func _ready() -> void:
	var director_path := "res://src/story/storyboard_director.gd"
	var context_path := "res://src/story/storyboard_context.gd"
	var catalog_path := "res://src/story/storyboard_catalog.gd"
	check(ResourceLoader.exists(director_path), "pure Storyboard Director exists")
	check(ResourceLoader.exists(context_path), "run context adapter exists")
	check(ResourceLoader.exists(catalog_path), "authored storyboard catalog exists")
	check(FileAccess.file_exists("res://data/storyboards.json"),
			"story grammar is authored as offline data")
	if failures > 0:
		finish()
		return
	var director = load(director_path).new()
	var context := {"seed":99173, "node_id":"f3_l2", "area_id":"shadow_crypt",
			"area_name":"Shadow Crypt", "kit_id":"ember_adept",
			"enemy_id":"crypt_knight", "enemy_name":"Crypt Knight",
			"event_id":"mirror_cauldron", "event_name":"Mirror Cauldron",
			"kind":"elite", "floor":3, "hp_ratio":0.42,
			"story_flags":{"mirror_marked":true}, "result_summary":"Gain a relic"}
	for trigger in TRIGGERS:
		var sequence: Array = director.compose(trigger, context)
		check(not sequence.is_empty(), trigger + " composes at least one authored beat")
		_validate_sequence(sequence, trigger)
	var first: Array = director.compose("battle_intro", context)
	var second: Array = director.compose("battle_intro", context)
	check(first == second, "identical context composes an identical sequence")
	check(str(first[0].get("art_mode", "")) == "full_scene",
			"battle introduction begins with a full narrative painting")
	check(str(first[0].get("background", "")).begins_with(
			"res://assets/art/story_scenes/"),
			"battle introduction does not reuse the plain battle background")
	check((first[0].get("subjects", []) as Array).is_empty(),
			"full-scene encounter does not paste an isolated enemy sprite")
	check(not str(first[0].get("scene_key", "")).is_empty(),
			"full-scene encounter records stable art identity")
	check(str(first[0].get("title", "")) == "CRYPT KNIGHT",
			"encounter painting names the monster instead of showing generic copy")
	var event_sequence: Array = director.compose("event_reveal", context)
	check(str(event_sequence[0].get("art_mode", "")) == "full_scene",
			"event reveal begins with a full narrative painting")
	check((event_sequence[0].get("subjects", []) as Array).is_empty(),
			"event reveal never falls back to a pasted potion subject")
	check(str(event_sequence[0].get("title", "")) == "MIRROR CAULDRON",
			"event painting clearly names the authored event")
	var changed := context.duplicate(true)
	changed.node_id = "f4_l0"
	var variant: Array = director.compose("battle_intro", changed)
	check(_beat_ids(first) != _beat_ids(variant),
			"a different node deterministically varies the authored shot selection")
	check(director.compose("unknown_trigger", context).is_empty(),
			"missing story content falls through without blocking gameplay")
	var invalid := context.duplicate(true)
	invalid.enemy_id = "missing_enemy"
	var fallback: Array = director.compose("battle_intro", invalid)
	check(not fallback.is_empty(), "missing subject art retains a caption fallback")
	for beat in fallback:
		for subject in beat.get("subjects", []):
			check(not str(subject.get("texture", "")).contains("missing_enemy"),
					"invalid subject references are omitted")
	var victory_sequence: Array = director.compose("battle_victory", context)
	check(str(victory_sequence[0].get("art_mode", "")) == "full_scene",
			"victory is presented as a narrative outcome painting")
	check((victory_sequence[0].get("subjects", []) as Array).is_empty(),
			"victory no longer alternates back to an isolated potion cutout")
	finish()


func _validate_sequence(sequence: Array, trigger: String) -> void:
	var previous_layout := ""
	var previous_transition := ""
	for beat in sequence:
		for key in REQUIRED:
			check(beat.has(key), trigger + " beat owns " + key)
		check(ResourceLoader.exists(str(beat.get("background", ""))),
				trigger + " background resolves")
		check(float(beat.get("duration", 0.0)) > 0.0,
				trigger + " duration is positive")
		check(previous_layout.is_empty() or str(beat.layout) != previous_layout,
				trigger + " avoids adjacent layout repetition")
		check(previous_transition.is_empty() or str(beat.transition) != previous_transition,
				trigger + " avoids adjacent transition repetition")
		previous_layout = str(beat.layout)
		previous_transition = str(beat.transition)


func _beat_ids(sequence: Array) -> Array[String]:
	var ids: Array[String] = []
	for beat in sequence:
		ids.append(str(beat.get("id", "")))
	return ids


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
