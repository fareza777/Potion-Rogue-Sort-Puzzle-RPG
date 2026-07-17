extends Node
## Autoload: DevTools
## Testing helpers driven by command-line user args (after "++"):
##   --screenshot=PATH    capture the viewport after a short delay, save PNG, quit.
##   --delay=SECONDS      override the capture delay (default 1.2).
##   --battle-index=N     start a run positioned at battle N (test elites/boss).
##   --enemy=ID           open battle on a specific enemy (visual QA only).
##   --tutorial           replay the tutorial from step one before capture.
## Does nothing in normal play.


func _ready() -> void:
	var path := ""
	var delay := 1.2
	var requested_enemy := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--delay="):
			delay = float(arg.get_slice("=", 1))
		elif arg.begins_with("--battle-index="):
			RunState.start_new_run()
			RunState.battle_index = int(arg.get_slice("=", 1))
		elif arg.begins_with("--enemy="):
			requested_enemy = arg.get_slice("=", 1)
		elif arg == "--tutorial":
			SaveSystem.replay_tutorial()
	if not requested_enemy.is_empty():
		_prepare_enemy(requested_enemy)
	if path != "":
		_capture(path, delay)


func _prepare_enemy(enemy_id: String) -> void:
	if not GameState.enemies.has(enemy_id): return
	RunState.start_new_run()
	for node in RunState.run_graph.get("nodes", []):
		if int(node.get("floor", 0)) == 1:
			node.kind = "battle"
			node.enemy = enemy_id
			node.contract.enemy_id = enemy_id
			RunState.current_node_id = str(node.id)
			return


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("DevTools screenshot -> %s (err=%d)" % [path, err])
	get_tree().quit()
