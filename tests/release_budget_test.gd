extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(preset.contains("premium_icons_*.png"), "export excludes image-generation intermediates")
	check(FileAccess.file_exists("res://tools/validate_release.ps1"), "release validator exists")
	var validator := FileAccess.get_file_as_string("res://tools/validate_release.ps1")
	for budget in ["MaxApkMB", "MaxAssetMB", "MaxAudioMB", "MaxImageDimension"]:
		check(validator.contains(budget), "release validator declares " + budget)
	check(VisualRegistry.missing_runtime_assets().is_empty(), "all registered runtime assets resolve")
	_check_story_art_imports()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _check_story_art_imports() -> void:
	var directory := DirAccess.open("res://assets/art/story_scenes")
	check(directory != null, "story-art directory is available")
	if directory == null:
		return
	var art_count := 0
	for file_name in directory.get_files():
		if not file_name.ends_with(".webp"):
			continue
		art_count += 1
		var path := "res://assets/art/story_scenes/" + file_name
		var texture := load(path) as Texture2D
		check(texture != null and texture.get_size() == Vector2(720, 1280),
				file_name + " is a valid 720x1280 story texture")
		var import_text := FileAccess.get_file_as_string(path + ".import")
		check(import_text.contains("compress/mode=1"),
				file_name + " uses package-safe lossy texture import")
	check(art_count == 40, "forty optimized story paintings ship with the release")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
