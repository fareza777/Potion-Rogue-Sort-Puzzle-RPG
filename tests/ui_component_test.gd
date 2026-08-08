extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	check(UiThemeTokens.TOUCH_TARGET >= 56, "semantic touch target is at least 56 px")
	check(UiThemeTokens.space("xs") < UiThemeTokens.space("md")
			and UiThemeTokens.space("md") < UiThemeTokens.space("xxl"),
			"semantic spacing helper exposes one ordered six-step scale")
	check(UiThemeTokens.motion("standard") > UiThemeTokens.motion("quick"),
			"semantic motion helper separates quick and standard feedback")
	check(UiThemeTokens.ornament_level("supporting")
			< UiThemeTokens.ornament_level("hero"),
			"ornament hierarchy reserves decoration for hero surfaces")
	check(UiThemeTokens.type_size("display") > UiThemeTokens.type_size("title"),
			"semantic type scale has clear hierarchy")
	check(UiThemeTokens.contrast_ratio(UiKit.COLOR_TEXT, UiThemeTokens.SURFACE) >= 4.5
			and UiThemeTokens.contrast_ratio(UiKit.COLOR_TEXT_DIM,
					UiThemeTokens.SURFACE) >= 3.0,
			"body and caption colors remain readable on quiet surfaces")
	var quiet_path := "res://src/ui/components/quiet_surface.gd"
	check(ResourceLoader.exists(quiet_path), "quiet supporting surface component exists")
	if ResourceLoader.exists(quiet_path):
		var quiet = load(quiet_path).new()
		add_child(quiet)
		check(quiet is PanelContainer and quiet.name == "QuietSurface",
				"quiet surface avoids another oversized ornamental frame")
	var body := UiKit.body_label("Readable body copy")
	var caption := UiKit.caption_label("Readable caption")
	check(body.get_theme_font_size("font_size") >= UiThemeTokens.type_size("body"),
			"body label uses the semantic readable size")
	check(caption.get_theme_font_size("font_size") >= UiThemeTokens.type_size("caption"),
			"caption label uses the semantic caption size")
	var action := ActionIconButton.new()
	action.configure("undo", "Undo", "Undo last pour")
	check(action.custom_minimum_size.x >= 72 and action.icon != null,
			"action icon button is large and illustrated")
	check(action.has_theme_stylebox_override("focus"), "action buttons have visible focus state")
	var nav := BottomNav.new()
	add_child(nav)
	for id in ["hero", "upgrades", "home", "map", "settings"]:
		nav.add_item(id, id.capitalize(), Callable(), id == "home")
	var nav_row := nav.get_node_or_null("NavRow") as HBoxContainer
	check(nav_row != null and nav_row.get_child_count() == 5,
			"Hall nav owns five consistently aligned destinations")
	check(ResourceLoader.exists(VisualRegistry.ui_icon("areas")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("build")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("history")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("credits")),
			"generated expedition nav medallions resolve")
	check(ResourceLoader.exists(VisualRegistry.ui_icon("undo")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("home")),
			"generated Hall and battle art resolves")
	var hall := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	check(hall.contains("BottomNav.new()"), "Hall consumes reusable bottom navigation")
	var tactical_path := "res://src/ui/tactical_readout.gd"
	check(ResourceLoader.exists(tactical_path), "battle owns reusable tactical readout")
	if ResourceLoader.exists(tactical_path):
		var tactical_script := load(tactical_path)
		var tactical = tactical_script.new()
		add_child(tactical)
		check(tactical.custom_minimum_size.y >= 56,
				"tactical readout preserves readable mobile height")
		for node_name in ["ObjectiveText", "EnemyIntent", "EnemyTrick"]:
			check(tactical.find_child(node_name, true, false) != null,
					"tactical readout exposes " + node_name)
	var summary_path := "res://src/ui/build_summary.gd"
	check(ResourceLoader.exists(summary_path), "map owns reusable build summary")
	if ResourceLoader.exists(summary_path):
		var summary = load(summary_path).new()
		add_child(summary)
		summary.configure("ember_adept", ["molten_core"], ["flame_mastery"], ["emberheart"])
		for node_name in ["BuildKit", "BuildCounts", "BuildSynergy"]:
			check(summary.find_child(node_name, true, false) != null,
					"build summary exposes " + node_name)
	var area_source := FileAccess.get_file_as_string("res://src/ui/area_select_screen.gd")
	check(area_source.contains("AscensionSelector") and area_source.contains("set_selected_ascension"),
			"expedition selector exposes persistent Ascension controls")
	var campaign_offer := CampaignUnlockCard.new().configure(true)
	add_child(campaign_offer)
	check(campaign_offer.find_child("BuyFullCampaign", true, false) is Button,
			"campaign offer exposes a one-time purchase action")
	check(campaign_offer.find_child("RestoreCampaignPurchase", true, false) is Button,
			"campaign offer exposes Google Play restore")
	check(campaign_offer.find_child("CampaignUnlockPrice", true, false) != null
			and BillingService.PRODUCT_ID == "potion_rogue_full_campaign",
			"campaign offer shows the approved product and price contract")
	var settings_source := FileAccess.get_file_as_string("res://src/ui/settings_screen.gd")
	check(settings_source.contains("CampaignUnlockSettingsOffer"),
			"Settings keeps the campaign purchase easy to find")
	check(settings_source.contains("AppLinks.PRIVACY_POLICY_URL")
			and AppLinks.PRIVACY_POLICY_URL.begins_with("https://"),
			"Settings exposes the public English privacy policy")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
