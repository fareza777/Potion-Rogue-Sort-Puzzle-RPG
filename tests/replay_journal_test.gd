extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var journal := ReplayJournal.new()
	for index in 305:
		journal.record("move", {"from":index % 6, "to":(index + 1) % 6})
	var snapshot := journal.snapshot()
	check((snapshot.events as Array).size() == 300, "journal keeps only the latest 300 events")
	var restored := ReplayJournal.new()
	check(restored.restore(snapshot), "valid journal snapshot restores")
	check(restored.checksum() == journal.checksum(), "restored journal keeps deterministic checksum")
	var corrupt := snapshot.duplicate(true); corrupt["checksum"] = 7
	check(not ReplayJournal.new().restore(corrupt), "checksum mismatch is rejected")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
