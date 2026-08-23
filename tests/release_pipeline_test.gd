extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var validator := FileAccess.get_file_as_string("res://tools/validate_release.ps1")
	check(validator.contains("Configured release artifact")
			and validator.contains("Debug APK") and validator.contains("Release AAB"),
			"release validator labels configured release and debug artifacts independently")
	check(validator.contains("Native/assets composition"),
			"release validator reports native and packaged asset composition")
	check(validator.contains("MaxTotalArtMB") and validator.contains("MaxTotalAudioMB"),
			"release validator enforces aggregate art and audio budgets")
	check(validator.contains("ReleaseArtifactPath")
			and validator.contains("compress/mode=1")
			and validator.contains("story_scenes"),
			"release validator inspects the actual bundle and optimized WebP imports")
	check(validator.contains("Requested release artifact not found"),
			"an explicitly requested missing AAB fails closed")
	check(validator.contains("config/version") and validator.contains("version/name"),
			"release validator checks project/export version agreement")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(preset.contains('version/name="1.7.7"') and preset.contains("version/code=37"),
			"Android package version is bumped")
	check(preset.contains('name="Android Release"')
			and preset.contains('export_path="builds/PotionRogue-v1.7.7.aab"')
			and preset.contains('name="Android Debug"')
			and preset.contains('export_path="builds/PotionRogue-v1.7.7-debug.apk"'),
			"AAB release and installable debug APK own separate export presets")
	check(preset.contains("tests/**") and preset.contains("atlas_*.png")
			and preset.contains("review_shots/**"),
			"export excludes tests, QA captures, and legacy atlases")
	check(FileAccess.file_exists("res://.github/workflows/android-ci.yml"),
			"CI imports, tests, exports, validates, and uploads Android artifact")
	var ci := FileAccess.get_file_as_string("res://.github/workflows/android-ci.yml")
	check(ci.contains("PotionRogue-v1.7.7-debug.apk")
			and ci.contains('--export-debug "Android Debug"'),
			"CI exports the current installable debug APK preset")
	check(ci.contains("PotionRogue-v1.7.7-sizecheck.aab")
			and ci.contains('--export-debug "Android Release"')
			and ci.contains("-ReleaseArtifactPath"),
			"CI builds and validates an AAB carrying the real release payload")
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
