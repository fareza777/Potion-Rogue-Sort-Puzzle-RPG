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

	# The reported bug was the card and its actions running off the bottom of
	# the screen, so this walks every authored page and checks the real rects.
	var screen := (load("res://scenes/onboarding.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var view := get_viewport().get_visible_rect()
	var pages: int = screen.get("PAGES").size()
	for page in pages:
		screen.set("_page", page)
		screen.call("_show_page", false)
		await get_tree().process_frame
		for node_name in ["OnboardingCard", "OnboardingActions", "OnboardingDots",
				"OnboardingNext", "OnboardingBack", "OnboardingSkip"]:
			var control := screen.find_child(node_name, true, false) as Control
			check(control != null, "page %d exposes %s" % [page, node_name])
			if control == null:
				continue
			var rect := control.get_global_rect()
			check(rect.position.y >= 0.0 and rect.end.y <= view.size.y + 0.5
					and rect.position.x >= 0.0 and rect.end.x <= view.size.x + 0.5,
					"page %d keeps %s fully on screen" % [page, node_name])

	# The card content must sit inside the ornate frame, not on top of it.
	var card := screen.find_child("OnboardingCard", true, false) as PanelContainer
	var content := screen.find_child("OnboardingCardContent", true, false) as Control
	if card != null and content != null:
		var inset := content.get_global_rect().position - card.get_global_rect().position
		check(inset.y >= 60.0 and inset.x >= 40.0,
				"card content clears the frame filigree")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
