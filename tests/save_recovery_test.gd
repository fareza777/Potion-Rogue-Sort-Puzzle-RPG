extends Node

var checks := 0
var failures := 0
const TEST_PATH := "user://potion_rogue_atomic_test.json"


func _ready() -> void:
	_cleanup()
	check(SaveSystem.has_method("parse_save_text") and SaveSystem.has_method("write_atomic")
			and SaveSystem.has_method("load_from_paths"), "save recovery API exists")
	if SaveSystem.has_method("parse_save_text"):
		check(SaveSystem.parse_save_text("not json").is_empty(), "corrupt JSON is rejected")
		var parsed: Dictionary = SaveSystem.parse_save_text('{"version":1,"crystals":7,"settings":{}}')
		check(int(parsed.get("version", 0)) == SaveSystem.SAVE_VERSION,
				"valid legacy JSON is migrated before use")
	if SaveSystem.has_method("write_atomic"):
		check(SaveSystem.write_atomic({"version":SaveSystem.SAVE_VERSION,"crystals":7}, TEST_PATH),
				"first atomic write succeeds")
		check(FileAccess.file_exists(TEST_PATH) and not FileAccess.file_exists(TEST_PATH + ".tmp"),
				"atomic write leaves only committed primary")
		check(SaveSystem.write_atomic({"version":SaveSystem.SAVE_VERSION,"crystals":12}, TEST_PATH),
				"second atomic write succeeds")
		check(FileAccess.file_exists(TEST_PATH + ".bak"), "valid previous save becomes backup")
		var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		corrupt.store_string("{broken"); corrupt.close()
		var recovered: Dictionary = SaveSystem.load_from_paths(TEST_PATH, TEST_PATH + ".bak")
		check(int(recovered.get("crystals", -1)) == 7, "corrupt primary recovers from backup")
	_cleanup()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH + suffix))


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
