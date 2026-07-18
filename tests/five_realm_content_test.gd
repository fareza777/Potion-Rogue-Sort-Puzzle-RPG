extends Node

const NEW_IDS := [
	"frost_mite", "rime_squire", "icefang_wolf", "hoarfrost_witch",
	"crystal_yeti", "reliquary_seraph", "winter_lich", "ink_slime",
	"drowned_acolyte", "brine_stalker", "abyssal_crab", "lantern_horror",
	"plague_alchemist", "deep_oracle", "leviathan_apothecary",
]
const NEW_SIGNATURES := ["freeze", "mutate", "tide"]
const NEW_MODIFIERS := ["permafrost", "brittle_glass", "rising_tide", "abyssal_ink"]

var checks := 0
var failures := 0


func _ready() -> void:
	_test_campaign_contract()
	_test_roster_contract()
	_test_pressure_contract()
	_test_boss_contract()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_campaign_contract() -> void:
	check(GameState.area_ids() == ["shadow_crypt", "verdant_catacombs",
			"astral_foundry", "frostbound_reliquary", "abyssal_apothecary"],
			"five realms form the approved ordered campaign")
	var expected := {
		"frostbound_reliquary": {"after":"astral_foundry", "length":8,
				"boss_depth":8, "reward":100, "miniboss":[4]},
		"abyssal_apothecary": {"after":"frostbound_reliquary", "length":9,
				"boss_depth":9, "reward":130, "miniboss":[4, 6]},
	}
	var grammar_path := "res://src/run/area_grammar.gd"
	check(ResourceLoader.exists(grammar_path), "area grammar normalizer is registered")
	var grammar_script = load(grammar_path) if ResourceLoader.exists(grammar_path) else null
	for area_id in expected:
		var grammar: Dictionary = grammar_script.call("for_area", area_id) \
				if grammar_script != null else GameState.area(area_id)
		var contract: Dictionary = expected[area_id]
		check(str(grammar.get("unlock_after", "")) == contract.after,
				"realm unlock chain is authored: " + area_id)
		check(int(grammar.get("run_length", 0)) == contract.length
				and int(grammar.get("boss_depth", 0)) == contract.boss_depth,
				"realm run depth is authored: " + area_id)
		check(int(grammar.get("first_clear_reward", 0)) == contract.reward,
				"realm first-clear reward is authored: " + area_id)
		check(grammar.get("miniboss_depths", []) == contract.miniboss,
				"realm miniboss depths are authored: " + area_id)
		var graph := RunGenerator.new().generate(82461, area_id)
		var repeat := RunGenerator.new().generate(82461, area_id)
		check(JSON.stringify(graph) == JSON.stringify(repeat),
				"realm routes remain deterministic: " + area_id)
		var boss: Dictionary = graph.nodes.filter(func(node: Dictionary) -> bool:
			return str(node.kind) == "boss")[0]
		check(int(boss.floor) + 1 == contract.boss_depth,
				"boss occupies authored final depth: " + area_id)
		for depth in contract.miniboss:
			var checkpoint: Array = graph.nodes.filter(func(node: Dictionary) -> bool:
				return int(node.floor) + 1 == int(depth) and bool(node.get("miniboss", false)))
			check(not checkpoint.is_empty(),
					"mandatory miniboss occupies depth %d: %s" % [depth, area_id])
	var legacy := {"version":6, "max_ascension":4, "selected_ascension":3,
			"completed_areas":["shadow_crypt", "verdant_catacombs", "astral_foundry"],
			"unlocked_areas":["shadow_crypt", "verdant_catacombs", "astral_foundry"],
			"settings":{}}
	var migrated := SaveSystem.migrate(legacy)
	check(int(migrated.max_ascension) == 4 and int(migrated.selected_ascension) == 3,
			"migration preserves existing nonzero Ascension")
	check("frostbound_reliquary" in migrated.unlocked_areas,
			"migration derives the next realm from prior completions")
	var original_save := SaveSystem.data
	SaveSystem.data = migrated
	check(MetaProgression.new().ascension_unlocked(),
			"existing nonzero Ascension is never relocked by new realms")
	SaveSystem.data = original_save


func _test_roster_contract() -> void:
	var enemies := GameState.load_data_file("enemies.json", {})
	check(enemies.size() == 42, "enemy roster contains exactly 42 entries")
	var discovered: Array[String] = []
	for enemy_id in enemies:
		if str(enemy_id) in NEW_IDS:
			discovered.append(str(enemy_id))
	discovered.sort()
	var approved: Array[String] = []
	approved.assign(NEW_IDS)
	approved.sort()
	check(discovered == approved, "roster contains exactly the fifteen approved IDs")
	var sprites := {}
	for enemy_id in NEW_IDS:
		var enemy: Dictionary = enemies.get(enemy_id, {})
		check(not enemy.is_empty() and int(enemy.get("tier", 0)) in range(1, 5)
				and int(enemy.get("hp", 0)) > 0 and int(enemy.get("attack", 0)) > 0
				and int(enemy.get("attack_every", 0)) >= 2,
				"enemy has valid family/tier/stats: " + enemy_id)
		check(str(enemy.get("family", "")) in ["frost", "abyss"],
				"enemy belongs to a new realm family: " + enemy_id)
		check(str((enemy.get("signature", {}) as Dictionary).get("id", ""))
				in EnemySignatureController.VALID_IDS,
				"enemy has a supported signature: " + enemy_id)
		var intents_valid := not (enemy.get("intent_pool", []) as Array).is_empty()
		for entry in enemy.get("intent_pool", []):
			intents_valid = intents_valid and GameState.intents.has(str(entry.get("id", "")))
		check(intents_valid, "enemy intents resolve: " + enemy_id)
		var sprite := str(enemy.get("sprite", ""))
		check(not sprite.is_empty() and not sprites.has(sprite) and not enemy.has("atlas"),
				"enemy has a unique individual sprite path: " + enemy_id)
		sprites[sprite] = true
		for field in ["display_scale", "baseline_offset", "impact_anchor",
				"projectile_anchor", "motion_profile"]:
			check(enemy.has(field), "enemy display metadata has %s: %s" % [field, enemy_id])
	for area_id in ["frostbound_reliquary", "abyssal_apothecary"]:
		var area := GameState.area(area_id)
		var boss_id := str(area.boss)
		var normal_pool: Array = []
		for pool_name in ["intro", "tier_1", "tier_2", "tier_3", "elite"]:
			normal_pool.append_array(area.enemy_pools.get(pool_name, []))
		check(boss_id not in normal_pool, "boss is excluded from normal pools: " + area_id)
		var intro_valid := true
		for enemy_id in area.enemy_pools.intro:
			intro_valid = intro_valid and int(enemies[enemy_id].tier) == 1
		check(intro_valid, "early encounter pool contains only T1 enemies: " + area_id)


func _test_pressure_contract() -> void:
	for signature_id in NEW_SIGNATURES:
		check(signature_id in EnemySignatureController.VALID_IDS,
				"new signature is registered: " + signature_id)
		var controller := EnemySignatureController.new()
		controller.configure(signature_id, {"signature":{"id":signature_id,
				"label":signature_id.capitalize(), "every_moves":2}}, 33)
		check(not bool(controller.on_player_move(null).get("triggered", false))
				and bool(controller.on_player_move(null).get("triggered", false)),
				"new signature respects its countdown: " + signature_id)
		var saved := controller.snapshot()
		var restored := EnemySignatureController.new()
		restored.configure(signature_id, {"signature":{"id":signature_id,
				"label":signature_id.capitalize(), "every_moves":2}}, 33)
		check(restored.restore(saved) and restored.snapshot() == saved,
				"new signature snapshot restores exactly: " + signature_id)
	for modifier_id in NEW_MODIFIERS:
		check(GameState.modifiers.has(modifier_id)
				and not str(GameState.modifiers[modifier_id].get("description", "")).is_empty(),
				"new modifier has readable data: " + modifier_id)
		var board := PuzzleBoard.new()
		add_child(board)
		board.generate_tutorial_board()
		var modifier := ModifierController.new()
		check(modifier.configure([modifier_id] as Array[String], 91, board),
				"new modifier configures safely: " + modifier_id)
		check(BoardSolver.has_solution(board.export_state(), PotionTube.CAPACITY),
				"new modifier preserves a solvable board: " + modifier_id)
		check(modifier.has_method("snapshot") and modifier.has_method("restore"),
				"new modifier exposes snapshot APIs: " + modifier_id)
		var saved: Dictionary = modifier.call("snapshot") if modifier.has_method("snapshot") else {}
		var restored := ModifierController.new()
		check(restored.has_method("restore") and bool(restored.call("restore", saved, board))
				and restored.call("snapshot") == saved,
				"new modifier restores exact state: " + modifier_id)
		board.free()


func _test_boss_contract() -> void:
	var bosses := GameState.load_data_file("bosses.json", {})
	var expected := {
		"winter_lich":{"thresholds":[1.0, 0.68, 0.34], "action":"frost_bind"},
		"leviathan_apothecary":{"thresholds":[1.0, 0.66, 0.32], "action":"tidal_rotate"},
	}
	for boss_id in expected:
		var phases: Array = bosses.get(boss_id, {}).get("phases", [])
		check(phases.size() == 3, "boss has three authored phases: " + boss_id)
		if phases.size() != 3:
			continue
		var thresholds: Array = phases.map(func(phase: Dictionary) -> float:
			return float(phase.threshold))
		check(thresholds == expected[boss_id].thresholds,
				"boss phase thresholds match the approved spec: " + boss_id)
		check(str(phases[1].get("board_action", "")) == expected[boss_id].action
				and bool(phases[2].get("ultimate_window", false)),
				"boss mutation and ultimate window are authored: " + boss_id)
		var controller := BossPhaseController.new()
		controller.configure(boss_id, 100)
		controller.update_hp(60)
		var saved := controller.snapshot()
		check(str(saved.get("pending_action_id", "")) == expected[boss_id].action,
				"boss snapshot retains its pending action: " + boss_id)
		var restored := BossPhaseController.new()
		check(restored.has_method("restore") and bool(restored.call("restore", saved)),
				"boss phase snapshot restores: " + boss_id)
		check(restored.pending_board_action() == expected[boss_id].action
				and restored.pending_board_action().is_empty(),
				"resume applies a pending boss action exactly once: " + boss_id)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
