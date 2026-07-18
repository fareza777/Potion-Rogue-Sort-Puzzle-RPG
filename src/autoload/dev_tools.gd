extends Node
## Autoload: DevTools
## Testing helpers driven by command-line user args (after "++"):
##   --screenshot=PATH    capture the viewport after a short delay, save PNG, quit.
##   --delay=SECONDS      override the capture delay (default 1.2).
##   --battle-index=N     start a run positioned at battle N (test elites/boss).
##   --enemy=ID           open battle on a specific enemy (visual QA only).
##   --area=ID            open a generated run in a specific campaign area.
##   --phase=map|battle|boss  prepare a deterministic visual-regression state.
##   --tutorial           replay the tutorial from step one before capture.
##   --skip-tutorial      hide onboarding overlays for clean regression captures.
## Does nothing in normal play.


func _ready() -> void:
	var path := ""
	var delay := 1.2
	var requested_enemy := ""
	var requested_area := ""
	var requested_phase := ""
	var requested_battle_index := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--delay="):
			delay = float(arg.get_slice("=", 1))
		elif arg.begins_with("--battle-index="):
			requested_battle_index = int(arg.get_slice("=", 1))
		elif arg.begins_with("--enemy="):
			requested_enemy = arg.get_slice("=", 1)
		elif arg.begins_with("--area="):
			requested_area = arg.get_slice("=", 1)
		elif arg.begins_with("--phase="):
			requested_phase = arg.get_slice("=", 1).to_lower()
		elif arg == "--tutorial":
			SaveSystem.replay_tutorial()
		elif arg == "--skip-tutorial":
			# Capture-only memory mutation; intentionally does not call save().
			SaveSystem.data["tutorial_done"] = true
			SaveSystem.data["tutorial_state"] = "complete"
	if not requested_area.is_empty() or not requested_phase.is_empty() \
			or not requested_enemy.is_empty() or requested_battle_index >= 0:
		_prepare_area(requested_area if not requested_area.is_empty() else "shadow_crypt")
	if not requested_enemy.is_empty():
		_prepare_enemy(requested_enemy)
	if requested_battle_index >= 0:
		RunState.battle_index = requested_battle_index
	if not requested_phase.is_empty():
		_prepare_capture_phase(requested_phase)
	if path != "":
		_capture(path, delay)


func _prepare_enemy(enemy_id: String) -> void:
	if not GameState.enemies.has(enemy_id): return
	if not RunState.active: _prepare_area("shadow_crypt")
	for node in RunState.run_graph.get("nodes", []):
		if int(node.get("floor", 0)) == 1:
			node.kind = "battle"
			node.enemy = enemy_id
			node.contract.enemy_id = enemy_id
			RunState.current_node_id = str(node.id)
			RunState.phase = RunState.PHASE_BATTLE
			RunState.phase_payload = {}
			return


func _prepare_area(area_id: String) -> void:
	if GameState.area(area_id).is_empty(): return
	RunState.area_id = area_id
	RunState.pending_area_id = area_id
	RunState.run_seed = 170717
	RunState.run_graph = RunGenerator.new().generate(RunState.run_seed, area_id)
	RunState.current_node_id = str(RunState.run_graph.get("start", "f0_l1"))
	RunState.active = true
	RunState.run_mode = "normal"
	RunState.run_ascension = 0
	RunState.battle_index = 0
	RunState.player_hp = int(RunState.stat("max_hp", float(GameState.player.get("max_hp", 50))))
	RunState.phase = RunState.PHASE_MAP
	RunState.phase_payload = {}


func _prepare_capture_phase(capture_phase: String) -> void:
	match capture_phase:
		"map":
			RunState.phase = RunState.PHASE_MAP
			RunState.phase_payload = {}
		"boss":
			_prepare_boss()
		"battle", "signature":
			_prepare_first_battle()


func _prepare_first_battle() -> void:
	for node in RunState.run_graph.get("nodes", []):
		if int(node.get("floor", 0)) == 1 and str(node.get("kind", "")) in ["battle", "elite"]:
			RunState.current_node_id = str(node.get("id", ""))
			RunState.phase = RunState.PHASE_BATTLE
			RunState.phase_payload = {}
			return


func _prepare_boss() -> void:
	for node in RunState.run_graph.get("nodes", []):
		if str(node.get("kind", "")) == "boss":
			RunState.current_node_id = str(node.get("id", ""))
			RunState.battle_index = 6
			RunState.phase = RunState.PHASE_BATTLE
			RunState.phase_payload = {}
			return


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("DevTools screenshot -> %s (err=%d)" % [path, err])
	get_tree().quit()
