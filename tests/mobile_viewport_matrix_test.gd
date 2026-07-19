extends Node

const SIZES := [Vector2i(576, 1280), Vector2i(720, 1280), Vector2i(1080, 2400)]

var checks := 0
var failures := 0


func _ready() -> void:
	var synthetic := Control.new()
	synthetic.size = Vector2(576, 1280)
	var clipped := Button.new(); clipped.name = "ClippedAction"
	clipped.position = Vector2(540, 100); clipped.size = Vector2(80, 40)
	synthetic.add_child(clipped); add_child(synthetic)
	var issues := MobileLayoutAudit.inspect(synthetic, Vector2(576, 1280))
	check(issues.size() >= 2, "audit detects clipped and undersized controls")
	synthetic.queue_free()
	for viewport_size in SIZES:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		add_child(viewport)
		var screen := preload("res://scenes/area_select.tscn").instantiate() as Control
		viewport.add_child(screen)
		await get_tree().process_frame
		await get_tree().process_frame
		var area_issues := MobileLayoutAudit.inspect(screen, viewport_size)
		if not area_issues.is_empty(): print("LAYOUT ISSUES  ", area_issues)
		check(area_issues.is_empty(), "Areas passes %dx%d layout audit" % [
				viewport_size.x, viewport_size.y])
		viewport.queue_free()
		await get_tree().process_frame
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
