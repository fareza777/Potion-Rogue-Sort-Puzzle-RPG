extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var legacy := {"version":1,"crystals":5,"perma":{"hp":2},"settings":{},"active_run":{"active":true}}
	var once := SaveSystem.migrate(legacy); var twice := SaveSystem.migrate(once)
	check(once == twice, "migration is idempotent")
	check(once.crystals == 15 and once.legacy_run_compensated and not once.active_run.active,
			"legacy active run receives one compensation")
	RunState.start_new_run("void_brewer"); var boundary := RunState.serialize_boundary()
	check(RunState.resume_from_save(boundary), "v2 run resumes at map boundary")
	check(RunState.kit_id == "void_brewer" and not RunState.run_graph.is_empty(), "resume restores kit and graph")
	boundary.mutations = ["emberheart", "corrupt_id"]
	check(RunState.resume_from_save(boundary) and RunState.mutation_ids == ["emberheart"], "resume discards corrupt content ids")
	print("---\n%d checks, %d failures" % [checks, failures]); get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
