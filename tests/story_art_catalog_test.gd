extends Node

const AREAS := [
	"shadow_crypt", "verdant_catacombs", "astral_foundry",
	"frostbound_reliquary", "abyssal_apothecary",
]
const BOSSES := {
	"shadow_crypt":"fire_golem",
	"verdant_catacombs":"bloom_horror",
	"astral_foundry":"furnace_titan",
	"frostbound_reliquary":"winter_lich",
	"abyssal_apothecary":"leviathan_apothecary",
}
const EVENTS := [
	"whispering_well", "bound_alchemist", "mirror_cauldron", "bone_oracle",
	"cursed_chest", "ember_camp", "spore_garden", "prism_archive",
	"frost_shrine", "drowned_altar",
]

var checks := 0
var failures := 0


func _ready() -> void:
	var catalog_path := "res://src/story/story_art_catalog.gd"
	var manifest_path := "res://data/story_art_manifest.json"
	check(ResourceLoader.exists(catalog_path), "focused StoryArtCatalog exists")
	check(FileAccess.file_exists(manifest_path), "offline story-art manifest exists")
	if failures > 0:
		finish()
		return
	var catalog = load(catalog_path).new()
	for area_id in AREAS:
		var arrival: Dictionary = catalog.resolve("realm_arrival", {
				"seed":4401, "node_id":"arrival", "area_id":area_id, "floor":1})
		check_art(arrival, area_id + " resolves a full-scene arrival")
		var vow: Dictionary = catalog.resolve("run_intro", {
				"seed":4401, "node_id":"vow", "area_id":area_id, "floor":1})
		check_art(vow, area_id + " resolves a full-scene expedition vow")
		check(str(vow.get("scene_key", "")) != str(arrival.get("scene_key", "")),
				area_id + " does not repeat one painting across consecutive run opening beats")
		for tier in [1, 2, 3]:
			var encounter: Dictionary = catalog.resolve("battle_intro", {
					"seed":4401 + tier, "node_id":"tier_%d" % tier,
					"area_id":area_id, "enemy_id":"unmapped_enemy", "enemy_tier":tier,
					"kind":"battle", "floor":tier})
			check_art(encounter, "%s resolves tier %d encounter art" % [area_id, tier])
		var boss: Dictionary = catalog.resolve("battle_intro", {
				"seed":4410, "node_id":"boss", "area_id":area_id,
				"enemy_id":BOSSES[area_id], "enemy_tier":4,
				"kind":"boss", "floor":7})
		check_art(boss, area_id + " resolves exact boss art")
		var victory: Dictionary = catalog.resolve("battle_victory", {
				"seed":4411, "node_id":"victory", "area_id":area_id,
				"enemy_id":BOSSES[area_id], "kind":"boss"})
		check_art(victory, area_id + " resolves outcome art")
		var epilogue: Dictionary = catalog.resolve("run_epilogue", {
				"seed":4412, "node_id":"epilogue", "area_id":area_id,
				"enemy_id":BOSSES[area_id], "kind":"boss"})
		check_art(epilogue, area_id + " resolves a realm epilogue")
		check(str(epilogue.get("scene_key", "")) != str(victory.get("scene_key", "")),
				area_id + " does not repeat victory art immediately in the epilogue")
	for event_id in EVENTS:
		var event_art: Dictionary = catalog.resolve("event_reveal", {
				"seed":5501, "node_id":event_id, "area_id":"shadow_crypt",
				"event_id":event_id})
		check_art(event_art, event_id + " resolves an authored event painting")
	var exact_context := {"seed":7713, "node_id":"crypt_boss",
			"area_id":"shadow_crypt", "enemy_id":"fire_golem", "enemy_tier":4,
			"kind":"boss"}
	var first: Dictionary = catalog.resolve("battle_intro", exact_context)
	var second: Dictionary = catalog.resolve("battle_intro", exact_context)
	check(first == second, "identical story context resolves identical art")
	check(str(first.get("scene_key", "")).contains("fire_golem"),
			"exact enemy mapping wins before realm tier fallback")
	check(catalog.resolve("battle_intro", {"area_id":"unknown_realm",
			"enemy_id":"unknown_enemy", "enemy_tier":9}).is_empty(),
			"invalid content returns an empty safe fallback")
	finish()


func check_art(result: Dictionary, label: String) -> void:
	check(not result.is_empty(), label)
	if result.is_empty():
		return
	check(str(result.get("path", "")).begins_with("res://assets/art/story_scenes/"),
			label + " uses the dedicated full-scene library")
	check(ResourceLoader.exists(str(result.get("path", ""))),
			label + " texture resolves")
	check(not str(result.get("scene_key", "")).is_empty(), label + " has stable identity")


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
