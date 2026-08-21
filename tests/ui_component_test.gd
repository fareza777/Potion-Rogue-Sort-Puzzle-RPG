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
	var log_path := "res://src/ui/battle/battle_log.gd"
	check(ResourceLoader.exists(log_path), "battle owns a reusable combat journal")
	if ResourceLoader.exists(log_path):
		var battle_log = load(log_path).new()
		add_child(battle_log)
		check(battle_log.custom_minimum_size.y >= 56,
				"battle log preserves readable mobile height")
		for node_name in ["BattleLogHeading", "ObjectiveText", "BattleLogEntry0",
				"BattleLogEntry1", "BattleLogEntry2"]:
			check(battle_log.find_child(node_name, true, false) != null,
					"battle log exposes " + node_name)
		# The 1px-minimum-height pair that used to collapse this panel to an
		# empty black box must never come back.
		for entry_index in BattleLog.VISIBLE_ENTRIES:
			var entry := battle_log.find_child("BattleLogEntry%d" % entry_index,
					true, false) as Label
			check(entry != null and entry.autowrap_mode == TextServer.AUTOWRAP_OFF,
					"battle log entry %d never combines autowrap with ellipsis"
					% entry_index)
		battle_log.push_entry("Fire Burst — 14 damage", "reaction")
		battle_log.push_entry("Enemy attacks for 8", "enemy")
		battle_log.push_entry("Shield absorbs 5", "shield")
		battle_log.push_entry("Poison deals 4", "damage")
		battle_log.push_entry("Player brews Red", "player")
		var newest := battle_log.find_child("BattleLogEntry%d"
				% (BattleLog.VISIBLE_ENTRIES - 1), true, false) as Label
		check(newest != null and newest.text.contains("Player brews Red"),
				"battle log renders the newest entry at the bottom")
		check(battle_log.has_method("history_entries")
				and battle_log.has_method("open_history"),
				"battle log exposes its tappable full-history view")
		if battle_log.has_method("history_entries") and battle_log.has_method("open_history"):
			check((battle_log.call("history_entries") as Array).size() == 5,
					"compact battle log retains older entries for history")
			battle_log.call("open_history")
			await get_tree().process_frame
			var history_popup = battle_log.find_child("BattleLogHistoryPopup",
					true, false)
			var history_scroll := battle_log.find_child("BattleLogHistoryScroll",
					true, false) as ScrollContainer
			var history_box := battle_log.find_child("BattleLogHistoryBox",
					true, false) as PanelContainer
			check(history_popup != null and history_popup.visible
					and history_popup is Control,
					"tapping the battle log opens an in-game history overlay")
			check(history_scroll is ScrollContainer and history_box is PanelContainer,
					"zoomed battle history is a dedicated scrollable journal box")
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
	var remove_ads_offer := RemoveAdsCard.new().configure(true)
	add_child(remove_ads_offer)
	check(remove_ads_offer.find_child("BuyRemoveAds", true, false) is Button,
			"remove ads offer exposes a one-time purchase action")
	check(remove_ads_offer.find_child("RestoreRemoveAdsPurchase", true, false) is Button,
			"remove ads offer exposes Google Play restore")
	check(remove_ads_offer.find_child("RemoveAdsPrice", true, false) != null
			and BillingService.PRODUCT_ID == "potion_rogue_remove_ads",
			"remove ads offer shows the approved product and price contract")
	var settings_source := FileAccess.get_file_as_string("res://src/ui/settings_screen.gd")
	check(settings_source.contains("RemoveAdsSettingsOffer"),
			"Settings keeps the Remove Ads purchase easy to find")
	check(settings_source.contains("AdPrivacyButton"),
			"Settings exposes the ad privacy controls consent laws require")
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
