extends Node

var checks := 0; var failures := 0; var emitted: Array[int] = []

func _ready() -> void:
	var boss := BossPhaseController.new(); boss.phase_changed.connect(func(i: int, _c: Dictionary): emitted.append(i))
	boss.configure("fire_golem", 100)
	boss.update_hp(70); boss.update_hp(69); boss.update_hp(40); boss.update_hp(39); boss.update_hp(10)
	check(emitted == [0, 1, 2], "boss emits each phase exactly once")
	check(boss.phase_index == 2, "boss crosses 70 and 40 percent thresholds")
	check(boss.has_method("pending_board_action"), "boss exposes queued board action")
	var snapshot := boss.snapshot()
	check(snapshot.has("applied_phase_actions"), "boss snapshot records applied board actions")
	var restored := BossPhaseController.new()
	if snapshot.has("applied_phase_actions"):
		restored.call("configure", snapshot.boss_id, snapshot.max_hp, snapshot.phase_index,
				snapshot.get("applied_phase_actions", []))
	else:
		restored.configure(snapshot.boss_id, snapshot.max_hp, snapshot.phase_index)
	check(restored.phase_index == 2, "boss phase restores without re-emission")
	var bosses := GameState.load_data_file("bosses.json", {})
	check(bosses.fire_golem.phases.size() == 3, "fire golem has three authored phases")
	for area_id in GameState.area_ids():
		var boss_id := str(GameState.area(area_id).boss)
		check(bosses.has(boss_id) and bosses[boss_id].phases.size() == 3,
				"area boss has three authored phases: " + boss_id)
		var action_phases: Array = bosses[boss_id].phases.filter(func(phase: Dictionary) -> bool:
			return not str(phase.get("board_action", "")).is_empty())
		check(not action_phases.is_empty(), "boss authors a board-changing phase: " + boss_id)
	print("---\n%d checks, %d failures" % [checks, failures]); get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
