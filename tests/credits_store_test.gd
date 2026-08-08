extends Node

const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.farezagames.potionrogue"

var checks := 0
var failures := 0


func _ready() -> void:
	var links_source := FileAccess.get_file_as_string("res://src/autoload/app_links.gd")
	check(links_source.contains('const PLAY_STORE_URL := "' + PLAY_STORE_URL + '"'),
			"AppLinks owns the production Google Play listing")
	var credits_source := FileAccess.get_file_as_string("res://src/ui/credits_screen.gd")
	check(credits_source.contains("Created by F7 Developer"),
			"Credits use the exact release creator line")
	check(not credits_source.contains("FAREZA GAMES")
			and not credits_source.contains("Built with Godot")
			and not credits_source.contains("Cinzel typeface"),
			"Credits omit internal production copy")
	check(credits_source.contains("OS.shell_open(AppLinks.PLAY_STORE_URL)"),
			"Credits rating action opens the centralized listing")

	var credits: Control = load("res://scenes/credits.tscn").instantiate()
	add_child(credits)
	await get_tree().process_frame
	check(credits.find_child("RateOnPlayStoreButton", true, false) is Button,
			"Credits expose a Google Play rating button")
	check(credits.find_child("PrivacyPolicyButton", true, false) is Button,
			"Credits retain the privacy policy action")
	check(_all_label_text(credits).contains("Created by F7 Developer"),
			"Creator line renders in the Credits scene")
	credits.queue_free()
	await get_tree().process_frame

	var settings: Control = load("res://scenes/settings.tscn").instantiate()
	add_child(settings)
	await get_tree().process_frame
	check(settings.find_child("RateOnPlayStoreButton", true, false) is Button,
			"Settings expose the same Google Play rating action")
	settings.queue_free()

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _all_label_text(root: Node) -> String:
	var text := ""
	for label in root.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  " + label)
	else:
		failures += 1
		push_error("FAIL  " + label)
