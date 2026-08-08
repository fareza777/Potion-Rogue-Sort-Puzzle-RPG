class_name StoryArtCatalog
extends RefCounted
## Resolves authored full-scene story paintings without any network dependency.
## Exact encounter/event mappings win before a realm-and-tier fallback.

const MANIFEST_PATH := "res://data/story_art_manifest.json"
const SHOT_VARIANTS := [
	{"name":"center", "offset":[0.0, 0.0]},
	{"name":"advance", "offset":[-0.028, -0.012]},
	{"name":"counter", "offset":[0.028, 0.012]},
]

var _manifest: Dictionary = {}


func _init(manifest_override: Dictionary = {}) -> void:
	_manifest = manifest_override.duplicate(true) if not manifest_override.is_empty() \
			else _load_manifest()


func resolve(trigger: String, context: Dictionary) -> Dictionary:
	var area_id := str(context.get("area_id", ""))
	var areas: Dictionary = _manifest.get("areas", {})
	if area_id.is_empty() or not areas.has(area_id):
		return {}
	var area: Dictionary = areas[area_id]
	var candidates: Array[String] = []
	match trigger:
		"run_intro":
			candidates = [str(area.get("aftermath", "")), str(area.get("arrival", ""))]
		"realm_arrival", "route_choice":
			candidates = [str(area.get("arrival", "")), str(area.get("aftermath", ""))]
		"battle_intro", "battle_escalation":
			candidates = _encounter_candidates(area, context)
			candidates.append(str(area.get("arrival", "")))
		"event_reveal", "event_resolution":
			var events: Dictionary = _manifest.get("events", {})
			var event_id := str(context.get("event_id", ""))
			if not event_id.is_empty() and events.has(event_id):
				candidates.append(str(events[event_id]))
			candidates.append(str(area.get("arrival", "")))
		"battle_victory", "battle_defeat":
			candidates = [str(area.get("aftermath", "")), str(area.get("arrival", ""))]
		"run_epilogue":
			candidates = [str(area.get("arrival", "")), str(area.get("aftermath", ""))]
		_:
			return {}
	return _first_valid_scene(candidates, trigger, context)


func _encounter_candidates(area: Dictionary, context: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	var enemies: Dictionary = _manifest.get("enemies", {})
	var enemy_id := str(context.get("enemy_id", ""))
	if not enemy_id.is_empty() and enemies.has(enemy_id):
		candidates.append(str(enemies[enemy_id]))
	var tier := int(context.get("enemy_tier", 0))
	var kind := str(context.get("kind", "battle"))
	if kind == "boss":
		tier = 4
	elif kind in ["elite", "miniboss"]:
		tier = maxi(tier, 3)
	if tier <= 0:
		var floor := maxi(int(context.get("floor", 1)), 1)
		tier = 3 if floor >= 5 else (2 if floor >= 3 else 1)
	var tiers: Dictionary = area.get("tiers", {})
	var tier_scene := str(tiers.get(str(clampi(tier, 1, 4)), ""))
	if not candidates.has(tier_scene):
		candidates.append(tier_scene)
	return candidates


func _first_valid_scene(candidates: Array[String], trigger: String,
		context: Dictionary) -> Dictionary:
	for scene_key in candidates:
		var resolved := _scene(scene_key, trigger, context)
		if not resolved.is_empty():
			return resolved
	return {}


func _scene(scene_key: String, trigger: String, context: Dictionary) -> Dictionary:
	if scene_key.is_empty():
		return {}
	var scenes: Dictionary = _manifest.get("scenes", {})
	if not scenes.has(scene_key):
		return {}
	var config: Dictionary = scenes[scene_key]
	var path := str(config.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return {}
	var shot_identity := "%s|%s|%s|%s" % [str(context.get("seed", 0)),
			str(context.get("node_id", "")), trigger, scene_key]
	var shot_index := posmod(shot_identity.hash(), SHOT_VARIANTS.size())
	var shot: Dictionary = SHOT_VARIANTS[shot_index]
	var raw_focal: Variant = config.get("focal_point", [0.5, 0.42])
	var focal := Vector2(0.5, 0.42)
	if raw_focal is Array and raw_focal.size() >= 2:
		focal = Vector2(float(raw_focal[0]), float(raw_focal[1]))
	var offset: Array = shot.get("offset", [0.0, 0.0])
	focal += Vector2(float(offset[0]), float(offset[1]))
	return {
		"path":path,
		"scene_key":"%s:%s" % [scene_key, str(shot.get("name", "center"))],
		"base_scene_key":scene_key,
		"shot_variant":str(shot.get("name", "center")),
		"focal_point":[clampf(focal.x, 0.1, 0.9), clampf(focal.y, 0.1, 0.9)],
	}


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
