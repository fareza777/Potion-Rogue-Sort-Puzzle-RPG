extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	_content_contracts()
	_seed_sweep()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _content_contracts() -> void:
	check(GameState.kits.size() == 3, "three starting kits")
	check(GameState.objectives.size() == 5, "five encounter objectives")
	check(GameState.modifiers.size() == 12, "twelve puzzle modifiers")
	check(GameState.load_data_file("mutations.json", {}).size() == 24, "twenty-four mutations")
	check(GameState.load_data_file("relics.json", {}).size() == 18, "eighteen relics")
	check(GameState.load_data_file("catalysts.json", {}).size() == 12, "twelve catalysts")
	check(GameState.load_data_file("upgrades.json", {}).size() >= 10, "ten supporting upgrades")
	check(GameState.load_data_file("events.json", {}).size() >= 15, "at least fifteen authored events")
	check(GameState.load_data_file("bosses.json", {}).fire_golem.phases.size() == 3, "one three-phase boss")
	check(GameState.enemies.size() == 42, "forty-two enemy roster")
	var slime: Dictionary = GameState.enemies.slime
	check(int(slime.attack) <= int(GameState.player.max_hp * 0.1) and int(slime.attack_every) >= 4,
			"first encounter stays inside onboarding damage band")

func _seed_sweep() -> void:
	var rewards := RewardGenerator.new()
	for seed in 1000:
		var graph := RunGenerator.new().generate(seed)
		var ids := {}; for node in graph.nodes: ids[str(node.id)] = true
		check(ids.has(str(graph.boss)), "seed %d has reachable boss id" % seed)
		var trio := rewards.choices("mutation", 3, seed, {"tags":["fire"],"owned":[]})
		check(trio.size() == 3 and trio[0] != trio[1] and trio[1] != trio[2] and trio[0] != trio[2],
				"seed %d has unique reward trio" % seed)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL  ", label)
