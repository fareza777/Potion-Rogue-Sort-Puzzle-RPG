extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	check(ResourceLoader.exists("res://src/ui/fx_pool.gd"), "bounded FX pool exists")
	check(ResourceLoader.exists("res://src/ui/resource_texture_cache.gd"), "texture cache exists")
	if ResourceLoader.exists("res://src/ui/fx_pool.gd"):
		var pool = load("res://src/ui/fx_pool.gd").new(); add_child(pool)
		for index in 100:
			var effect := Node2D.new(); add_child(effect); pool.track(effect)
		check(pool.active_count() <= 48, "FX pool enforces 48-node ceiling")
		pool.queue_free()
	if ResourceLoader.exists("res://src/ui/resource_texture_cache.gd"):
		var cache = load("res://src/ui/resource_texture_cache.gd")
		var one = cache.bar_texture("player", Color.RED, true)
		var two = cache.bar_texture("player", Color.RED, true)
		check(one == two, "identical resource bars share one texture")
	var audio_source := FileAccess.get_file_as_string("res://src/autoload/audio_manager.gd")
	check(audio_source.contains("fallback_factory: Callable"),
			"ambient fallback synthesis is lazy")
	var has_states := AudioManager.has_method("set_scene_state")
	check(has_states, "music has explicit scene-state transitions")
	var supported: Array = AudioManager.accepted_scene_states() if AudioManager.has_method("accepted_scene_states") else []
	for state in ["hall", "explore", "event", "battle", "elite", "boss", "victory", "defeat",
			"story_explore", "story_danger", "story_victory", "story_defeat"]:
		check(state in supported, "music state accepted: " + state)
	check(ResourceLoader.exists("res://src/testing/runtime_budget_probe.gd"),
			"development runtime budget probe exists")
	var battle_fx = load("res://src/ui/battle_fx.gd").new()
	check(battle_fx.has_method("contact") and battle_fx.has_method("victory"),
			"battle FX separates contact and victory presentation phases")
	battle_fx.free()
	var enemy_display = load("res://src/battle/enemy_display.gd").new()
	check(enemy_display.has_method("play_recover"),
			"enemy motion has an explicit recovery phase")
	enemy_display.free()
	var ambient = load("res://src/ui/ambient_particles.gd").new()
	check(ambient.has_method("set_palette"),
			"ambient motes accept realm-specific cinematic color direction")
	ambient.free()
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
