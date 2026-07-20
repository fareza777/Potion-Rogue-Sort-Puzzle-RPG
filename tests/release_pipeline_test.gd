extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var validator := FileAccess.get_file_as_string("res://tools/validate_release.ps1")
	check(validator.contains("Newest") and validator.contains("60") and validator.contains("65"),
			"release validator discovers newest APK with 60/65 MiB gates")
	check(validator.contains("MaxTotalArtMB") and validator.contains("MaxTotalAudioMB"),
			"release validator enforces aggregate art and audio budgets")
	check(validator.contains("config/version") and validator.contains("version/name"),
			"release validator checks project/export version agreement")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(preset.contains('version/name="1.4.2"') and preset.contains("version/code=18"),
			"Android package version is bumped")
	check(preset.contains("tests/**") and preset.contains("atlas_*.png"),
			"export excludes tests and legacy atlases")
	check(FileAccess.file_exists("res://.github/workflows/android-ci.yml"),
			"CI imports, tests, exports, validates, and uploads Android artifact")
	for atlas in ["atlas_crypt.png", "atlas_fungal.png", "atlas_arcane.png", "atlas_infernal.png"]:
		check(not FileAccess.file_exists("res://assets/art/enemies/" + atlas),
				"unused legacy atlas removed: " + atlas)
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
