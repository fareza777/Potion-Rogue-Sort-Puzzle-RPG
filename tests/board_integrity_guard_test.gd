extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var guard := BoardIntegrityGuard.new()
	var partial := {"version":1, "state":[["red"], ["green"], [], [], [], []],
			"capacities":[4, 4, 4, 4, 4, 4]}
	check(guard.inspect(partial).status == "recoverable",
			"incomplete color sets are recoverable")
	check(guard.inspect({"version":1, "state":"bad"}).status == "invalid",
			"malformed board snapshots are invalid")
	var generated := BoardFactory.generate(91, "standard")
	check(guard.inspect({"version":1, "state":generated.state,
			"capacities":[4, 4, 4, 4, 4, 4]}).status == "valid",
			"solver-verified boards remain valid")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
