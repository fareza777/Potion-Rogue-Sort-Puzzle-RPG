extends Node
## Autoload: DevTools
## Testing helpers driven by command-line user args (after "++"):
##   --screenshot=PATH    capture the viewport after a short delay, save PNG, quit.
##   --delay=SECONDS      override the capture delay (default 1.2).
##   --battle-index=N     start a run positioned at battle N (test elites/boss).
## Does nothing in normal play.


func _ready() -> void:
	var path := ""
	var delay := 1.2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--delay="):
			delay = float(arg.get_slice("=", 1))
		elif arg.begins_with("--battle-index="):
			RunState.start_new_run()
			RunState.battle_index = int(arg.get_slice("=", 1))
	if path != "":
		_capture(path, delay)


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("DevTools screenshot -> %s (err=%d)" % [path, err])
	get_tree().quit()
