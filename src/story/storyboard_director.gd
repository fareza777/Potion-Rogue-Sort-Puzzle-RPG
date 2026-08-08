class_name StoryboardDirector
extends RefCounted
## Deterministically assembles short cinematics from authored shot grammar.
## It never mutates RunState and contains no runtime network dependency.

var catalog := StoryboardCatalog.new()
var art_catalog := StoryArtCatalog.new()


func compose(trigger: String, context: Dictionary) -> Array[Dictionary]:
	var grammar := catalog.trigger(trigger)
	var templates: Array = grammar.get("templates", [])
	if templates.is_empty():
		return []
	var realm := catalog.area(str(context.get("area_id", "shadow_crypt")))
	var kit := catalog.kit(str(context.get("kit_id", "ember_adept")))
	var seed_material := "%s|%s|%s|%s|%s" % [str(context.get("seed", 1)), trigger,
			str(context.get("node_id", "")), str(context.get("enemy_id", "")),
			JSON.stringify(context.get("story_flags", {}))]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_material.hash()) + 1
	var count := clampi(int(grammar.get("count", 1)), 1, templates.size())
	var story_art := art_catalog.resolve(trigger, context)
	# A full painting is a complete authored shot. Keep each presentation concise
	# so one illustration is not repeated under several consecutive captions.
	if not story_art.is_empty():
		count = 1
	var start := rng.randi_range(0, templates.size() - 1)
	var sequence: Array[Dictionary] = []
	var previous_layout := ""
	var previous_transition := ""
	for offset in count:
		var template: Dictionary = templates[(start + offset) % templates.size()]
		var beat := _compose_beat(template, trigger, context, realm, kit, story_art,
				rng, previous_layout, previous_transition)
		sequence.append(beat)
		previous_layout = str(beat.layout)
		previous_transition = str(beat.transition)
	return sequence


func _compose_beat(template: Dictionary, trigger: String, context: Dictionary,
		realm: Dictionary, kit: Dictionary, story_art: Dictionary,
		rng: RandomNumberGenerator,
		previous_layout: String, previous_transition: String) -> Dictionary:
	var layouts: Array = template.get("layouts", catalog.layouts())
	var layout := _pick_distinct(layouts, previous_layout, rng,
			catalog.layouts())
	var transitions: Array = realm.get("transitions", ["ink_wipe", "ember_bloom"])
	var transition := _pick_distinct(transitions, previous_transition, rng,
			["ink_wipe", "ember_bloom", "mist_dissolve"])
	var substitutions := _substitutions(context, realm, kit, rng)
	var title := _render(_pick_text(template.get("titles", ["THE STORY CONTINUES"]), rng),
			substitutions)
	var body := _render(_pick_text(template.get("bodies", [""]), rng), substitutions)
	var background := str(realm.get("background", ""))
	var art_mode := "composite"
	var scene_key := ""
	var focal_point: Variant = [0.5, 0.5]
	var subjects: Array = _subjects(str(template.get("subject", "none")), context)
	if not story_art.is_empty():
		background = str(story_art.get("path", background))
		art_mode = "full_scene"
		scene_key = str(story_art.get("scene_key", ""))
		focal_point = story_art.get("focal_point", [0.5, 0.42])
		subjects.clear()
		if trigger in ["battle_intro", "battle_escalation"]:
			title = str(substitutions.get("enemy", title))
		elif trigger == "event_reveal":
			title = str(substitutions.get("event", title))
	if not ResourceLoader.exists(background):
		background = str(GameState.area("shadow_crypt").get("background", ""))
	var node_token := str(context.get("node_id", "preview")).validate_node_name()
	var beat := {
		"id":"%s:%s:%s" % [trigger, str(template.get("id", "beat")), node_token],
		"layout":layout,
		"background":background,
		"subjects":subjects,
		"art_mode":art_mode,
		"scene_key":scene_key,
		"focal_point":focal_point,
		"eyebrow":_render(str(template.get("eyebrow", "POTION ROGUE")), substitutions),
		"title":title,
		"body":body,
		"accent":str(realm.get("accent", "9f6bd2")),
		"motion":str(template.get("motion", "slow_push")),
		"transition":transition,
		"music_state":str(template.get("music_state", "story_explore")),
		"duration":clampf(float(template.get("duration", 2.0)), 0.8, 4.5),
	}
	return beat


func _substitutions(context: Dictionary, realm: Dictionary, kit: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var omens: Array = realm.get("omens", ["The dungeon waits."])
	return {
		"area":str(context.get("area_name", realm.get("name", "The Dungeon"))).to_upper(),
		"kit":str(kit.get("name", "Alchemist")),
		"kit_voice":str(kit.get("voice", "The formula is ready.")),
		"enemy":str(context.get("enemy_name", "Unknown Guardian")).to_upper(),
		"event":str(context.get("event_name", "Mysterious Chamber")).to_upper(),
		"floor":str(maxi(int(context.get("floor", 1)), 1)),
		"battle_kind":str(context.get("kind", "battle")).replace("_", " ").to_upper(),
		"result":str(context.get("result_summary", "The choice has been applied.")),
		"omen":_pick_text(omens, rng),
	}


func _subjects(kind: String, context: Dictionary) -> Array[Dictionary]:
	if kind == "enemy":
		var enemy_id := str(context.get("enemy_id", ""))
		if not GameState.enemies.has(enemy_id):
			return []
		var config := VisualRegistry.enemy(enemy_id)
		var path := str(config.get("sprite", ""))
		if not ResourceLoader.exists(path):
			return []
		return [{"texture":path, "slot":"focus", "scale":float(config.get("scale", 1.0)),
				"enemy_id":enemy_id}]
	if kind == "potion":
		var path := "res://assets/art/storyboard/hero_potion_v1.png"
		return [{"texture":path, "slot":"focus", "scale":0.76}] \
				if ResourceLoader.exists(path) else []
	return []


func _pick_distinct(primary: Array, previous: String,
		rng: RandomNumberGenerator, fallback: Array) -> String:
	var candidates: Array[String] = []
	for raw_value in primary:
		var value := str(raw_value)
		if not value.is_empty() and value != previous:
			candidates.append(value)
	if candidates.is_empty():
		for raw_value in fallback:
			var value := str(raw_value)
			if not value.is_empty() and value != previous:
				candidates.append(value)
	return candidates[rng.randi_range(0, candidates.size() - 1)] \
			if not candidates.is_empty() else "crossfade"


func _pick_text(values: Array, rng: RandomNumberGenerator) -> String:
	return str(values[rng.randi_range(0, values.size() - 1)]) \
			if not values.is_empty() else ""


func _render(source: String, substitutions: Dictionary) -> String:
	var result := source
	for key in substitutions:
		result = result.replace("{" + str(key) + "}", str(substitutions[key]))
	return result
