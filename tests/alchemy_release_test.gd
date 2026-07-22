extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	print("Alchemy release checks started")
	var lab := BalanceSimulator.new()
	check(lab.has_method("alchemy_report"), "balance lab exposes reaction metrics")
	if lab.has_method("alchemy_report"):
		print("Sampling reaction balance")
		var report: Dictionary = BalanceSimulator.alchemy_report(8)
		print("Reaction balance sampled")
		check(int(report.get("loop_violations", 1)) == 0, "no free reaction loop")
		check(float(report.get("early_base_win_rate", 0.0)) >= 0.65,
				"early game remains base-potion viable")
		check(float(report.get("three_color_value", 0.0)) > float(report.get("two_color_value", 0.0)),
				"three-color formulas reward their sequencing cost")
		check(float(report.get("reaction_frequency", -1.0)) >= 0.0,
				"reaction frequency is reported")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var export := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(project.contains('config/version="1.5.2"'), "project version is 1.5.2")
	check(export.contains("version/code=23"), "Android version code is 23")
	check(export.contains('version/name="1.5.2"'), "Android version name is 1.5.2")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
