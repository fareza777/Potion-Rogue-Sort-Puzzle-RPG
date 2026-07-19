extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var director := BattlePresentationDirector.new()
	var normal := director.sequence("potion_complete", false)
	check(normal == ["anticipation", "impact", "reaction", "settle"],
			"battle feedback has a stable readable phase order")
	check(director.duration("critical", false) > director.duration("hit", false),
			"critical moments receive more presentation weight")
	check(director.duration("critical", true) < director.duration("critical", false),
			"reduced effects shortens presentation without removing feedback")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
