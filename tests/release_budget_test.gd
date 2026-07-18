extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(preset.contains("premium_icons_*.png"), "export excludes image-generation intermediates")
	check(FileAccess.file_exists("res://tools/validate_release.ps1"), "release validator exists")
	var validator := FileAccess.get_file_as_string("res://tools/validate_release.ps1")
	for budget in ["MaxApkMB", "MaxAssetMB", "MaxImageDimension"]:
		check(validator.contains(budget), "release validator declares " + budget)
	check(VisualRegistry.missing_runtime_assets().is_empty(), "all registered runtime assets resolve")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
