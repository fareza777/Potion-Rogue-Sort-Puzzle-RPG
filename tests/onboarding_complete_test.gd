extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/onboarding_screen.gd")
	for chapter in ["sort", "brew", "survive", "react", "cast", "explore"]:
		check(source.contains('"id":"%s"' % chapter), "Onboarding includes " + chapter)
	check(source.contains("OnboardingDemo"), "Onboarding embeds an animated demonstration")
	check(source.contains('setting("reduced_effects")'), "Onboarding respects Reduced Effects")
	check(source.contains("PAGES.size()"), "Onboarding progress adapts to every chapter")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
