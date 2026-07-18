extends Node
## Headless presentation contract tests. These exercise resource lookup and
## presentation fallbacks without coupling visual code to battle outcomes.

var _failures := 0
var _checks := 0
const GENERATED_ENEMIES := [
	"bone_rat", "grave_archer", "wailing_spirit", "crypt_knight", "ossuary_priest",
	"sporeling", "myconid_brute", "rotcap_shaman", "mossback_toad", "bloom_horror",
	"rune_wisp", "mimic_flask", "clockwork_imp", "void_acolyte", "prism_sentinel",
	"cinder_hound", "ash_harpy", "magma_beetle", "flame_wraith", "furnace_titan",
]


func _ready() -> void:
	check(VisualRegistry.enemy("slime").get("sprite", "") != "",
			"slime sprite mapping")
	for enemy_id in GameState.enemies:
		var enemy_style := VisualRegistry.enemy(str(enemy_id))
		check(not enemy_style.is_empty(), "enemy mapping: " + str(enemy_id))
		check(VisualRegistry.enemy_texture(str(enemy_id)) != null,
				"enemy texture resolves: " + str(enemy_id))
		if str(enemy_id) in GENERATED_ENEMIES:
			check(not str(enemy_style.get("sprite", "")).is_empty(),
					"generated enemy has individual sprite: " + str(enemy_id))
			check(str(enemy_style.get("atlas", "")).is_empty(),
					"generated enemy avoids runtime atlas: " + str(enemy_id))
			check(not (VisualRegistry.enemy_texture(str(enemy_id)) is AtlasTexture),
					"generated enemy texture is not sliced: " + str(enemy_id))
		check(str(enemy_style.get("motion_profile", "")) in [
			"elastic", "brittle", "pounce", "heavy", "caster", "inferno",
		], "enemy motion profile: " + str(enemy_id))
	for color in GameState.potions:
		check(not VisualRegistry.potion(str(color)).is_empty(),
				"potion mapping: " + str(color))
	check(VisualRegistry.texture_or_null("res://missing.png") == null,
			"missing texture fallback")
	var missing := VisualRegistry.missing_runtime_assets()
	check(missing.is_empty(),
			"registered runtime assets exist: " + ", ".join(missing))
	for path in [
		"res://assets/art/app_icon.png",
		"res://assets/art/backgrounds/shadow_crypt_battle.png",
		"res://assets/art/backgrounds/main_hall_v2.png",
		"res://assets/art/backgrounds/verdant_catacombs_battle.png",
		"res://assets/art/backgrounds/astral_foundry_battle.png",
		"res://assets/art/potions/bottle_frame.png",
		"res://assets/art/ui/battle_panel.png",
		"res://assets/art/ui/banner_turn.png",
		"res://assets/art/ui/button_round.png",
		"res://assets/art/ui/icon_undo.png",
		"res://assets/art/ui/icon_remix.png",
		"res://assets/art/ui/icon_pause.png",
	]:
		check(ResourceLoader.exists(path), "loadable art: " + path)
	check(ProjectSettings.get_setting("application/config/icon", "") ==
			"res://assets/art/app_icon.png", "branded application icon configured")
	for scene_path in ["res://scenes/main_menu.tscn", "res://scenes/area_select.tscn", "res://scenes/kit_select.tscn",
			"res://scenes/map.tscn",
			"res://scenes/battle.tscn", "res://scenes/shop.tscn",
			"res://scenes/settings.tscn", "res://scenes/credits.tscn",
			"res://scenes/event.tscn"]:
		var smoke_scene := load(scene_path) as PackedScene
		check(smoke_scene != null, "scene loads: " + scene_path)
		if smoke_scene != null:
			var smoke_instance := smoke_scene.instantiate()
			check(smoke_instance != null, "scene instantiates: " + scene_path)
			smoke_instance.free()
	var enemy_view := EnemyDisplay.new()
	add_child(enemy_view)
	enemy_view.custom_minimum_size = Vector2(520, 300)
	check(enemy_view.has_method("configure_enemy"), "enemy configuration interface")
	check(enemy_view.has_method("play_intro"), "enemy intro interface")
	check(enemy_view.has_method("play_anticipate"), "enemy anticipate interface")
	check(enemy_view.has_method("play_attack"), "enemy attack interface")
	check(enemy_view.has_method("play_defeat"), "enemy defeat interface")
	if enemy_view.has_method("configure_enemy") and enemy_view.has_method("uses_sprite_art"):
		enemy_view.call("configure_enemy", "slime", "slime", "6fce4e")
		check(bool(enemy_view.call("uses_sprite_art")), "slime uses registered sprite")
	else:
		check(false, "slime uses registered sprite")
	var expected_profiles := {
		"slime": "elastic",
		"skeleton": "brittle",
		"poison_beast": "pounce",
		"stone_golem": "heavy",
		"dark_mage": "caster",
		"blood_slime": "elastic",
		"fire_golem": "inferno",
	}
	check(enemy_view.has_method("motion_profile"), "enemy motion profile interface")
	if enemy_view.has_method("motion_profile"):
		for enemy_id in expected_profiles:
			enemy_view.call("configure_enemy", enemy_id, enemy_id, "ffffff")
			check(enemy_view.call("motion_profile") == expected_profiles[enemy_id],
					"enemy display profile: " + enemy_id)
	enemy_view.queue_free()
	var potion_view := PotionTube.new()
	add_child(potion_view)
	check(potion_view.has_method("flash_complete"), "potion complete animation interface")
	check(potion_view.has_method("play_invalid"), "potion invalid animation interface")
	potion_view.queue_free()
	var premium_board := PuzzleBoard.new()
	check(premium_board.has_method("layout_columns"),
			"premium potion board exposes column count")
	check(premium_board.has_method("tube_display_size"),
			"premium potion board exposes bottle proportion")
	if premium_board.has_method("layout_columns"):
		check(int(premium_board.call("layout_columns")) == 6,
				"premium potion board uses one six-bottle row")
	if premium_board.has_method("tube_display_size"):
		var bottle_size: Vector2 = premium_board.call("tube_display_size")
		var aspect := bottle_size.x / bottle_size.y
		check(bottle_size.x >= 96.0,
				"premium potion bottles are large touch targets")
		check(aspect >= 0.38 and aspect <= 0.50,
				"premium potion bottle keeps compact aspect")
	var board_source := FileAccess.get_file_as_string("res://src/puzzle/puzzle_board.gd")
	check(board_source.contains('name = "PotionShelf"'),
			"premium potion board exposes a centered shelf")
	check(not board_source.contains('name = "AlchemyTray"'),
			"premium potion row has no boxed alchemy tray")
	premium_board.free()
	var fx := BattleFx.new()
	add_child(fx)
	check(fx.has_method("hit"), "battle hit effect interface")
	check(fx.has_method("pour"), "battle pour effect interface")
	check(fx.has_method("heal"), "battle heal effect interface")
	check(fx.has_method("shield"), "battle shield effect interface")
	check(fx.has_method("poison"), "battle poison effect interface")
	check(fx.has_method("projectile"), "battle projectile effect interface")
	check(fx.has_method("enemy_strike"), "battle strike effect interface")
	check(fx.has_method("warning_pulse"), "battle warning pulse interface")
	check(fx.has_method("set_reduced_effects"), "reduced effects interface")
	if fx.has_method("set_reduced_effects"):
		fx.call("set_reduced_effects", true)
		check(bool(fx.get("reduced_effects")), "reduced effects state")
	else:
		check(false, "reduced effects state")
	fx.queue_free()
	check(ResourceLoader.exists("res://src/ui/ornate_resource_bar.gd"),
			"ornate resource bar script exists")
	var route_contract := DungeonRoute.new()
	check(route_contract.has_method("configure_graph"), "branching map consumes run graph")
	check(route_contract.has_signal("node_selected"), "branching map exposes reachable selection")
	var route_source := FileAccess.get_file_as_string("res://src/ui/dungeon_route.gd")
	check(route_source.contains("[0.19, 0.5, 0.81]"), "branching map uses three lanes")
	check(route_contract.has_method("disclosure_state"), "route exposes fog disclosure state")
	if route_contract.has_method("disclosure_state"):
		var fog_graph := {"nodes": [
			{"id":"past", "floor":0, "lane":1, "kind":"battle", "enemy":"slime", "links":["now"], "visited":true},
			{"id":"now", "floor":1, "lane":1, "kind":"battle", "enemy":"skeleton", "links":["choice"], "visited":false},
			{"id":"choice", "floor":2, "lane":1, "kind":"elite", "enemy":"crypt_knight", "links":["future"], "visited":false},
			{"id":"future", "floor":3, "lane":1, "kind":"event", "enemy":"slime", "event_id":"bone_oracle", "links":[], "visited":false},
		]}
		route_contract.configure_graph(fog_graph, "now", ["choice"])
		check(route_contract.call("disclosure_state", "past") == "revealed", "visited route is revealed")
		check(route_contract.call("disclosure_state", "choice") == "mystery", "reachable route remains mysterious")
		check(route_contract.call("disclosure_state", "future") == "fog", "future route remains uncharted")
		var choice := route_contract.get_node_or_null("GraphNode_choice") as Control
		check(choice != null and choice.find_children("*", "TextureRect", true, false).is_empty(),
				"mystery node does not render enemy portrait")
	var map_source := FileAccess.get_file_as_string("res://src/ui/map_screen.gd")
	check(map_source.contains('name = "BackToHallButton"'), "map exposes Back to Hall action")
	check(map_source.contains('func _return_to_hall()'), "map exposes Hall navigation handler")
	check(map_source.contains('change_scene_to_file("res://scenes/main_menu.tscn")'),
			"map Hall action returns to main menu")
	check(not map_source.contains("RunState.active = false"), "map Hall action preserves active run")
	check(map_source.contains("PATHS HIDE THEIR GUARDIAN")
			and map_source.contains("MORE FLAMES MEAN MORE RISK"),
			"map explains fog-of-war legend")
	check(map_source.contains("RunState.current_area()"), "map renders current area identity")
	check(not map_source.contains("if not RunState.active:\n\t\tRunState.start_new_run()"),
			"map never silently starts a run")
	var menu_source_campaign := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	check(menu_source_campaign.contains('change_scene_to_file("res://scenes/area_select.tscn")'),
			"New Run routes through expedition selection")
	var area_source := FileAccess.get_file_as_string("res://src/ui/area_select_screen.gd")
	check(area_source.contains("SaveSystem.is_area_unlocked"), "expedition selection respects campaign locks")
	check(area_source.contains("RunState.pending_area_id"), "expedition selection carries chosen area")
	route_contract.free()
	var vital_bar := OrnateResourceBar.new()
	check(vital_bar.has_method("configure"), "ornate bar configuration interface")
	check(vital_bar.has_method("set_values"), "ornate bar value interface")
	check(vital_bar.has_method("set_badge"), "ornate bar badge interface")
	vital_bar.free()
	var vital_source := FileAccess.get_file_as_string(
			"res://src/ui/ornate_resource_bar.gd")
	check(vital_source.contains("TextureProgressBar"),
			"ornate bar uses textured jewel fill")
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(battle_source.contains("RunState.current_area()"), "battle renders current area identity")
	check(not battle_source.contains('RunState.run_config.get("area_name"'),
			"battle header never leaks legacy Shadow Crypt copy")
	check(not battle_source.contains('enemy_id == "fire_golem"'), "battle supports every authored boss")
	check(battle_source.contains('"Next Expedition"'), "boss clear offers the newly unlocked expedition")
	check(battle_source.contains('func _go_to_area_select()'), "battle exposes campaign navigation")
	check(battle_source.contains('"Replay Area"'), "boss clear keeps area replayable")
	check(battle_source.contains('name = "EnemyVitalBar"'),
			"battle exposes framed enemy vital bar")
	check(battle_source.contains('name = "PlayerVitalBar"'),
			"battle exposes framed player vital bar")
	for tactical_name in ["ObjectivePanel", "EnemyIntent", "ManaMeter",
			"ComboSlots", "SkillButton", "UltimateButton"]:
		check(battle_source.contains('name = "' + tactical_name + '"'),
				"battle exposes tactical " + tactical_name)
	for component_name in ["EncounterHeader", "WarningPlaque", "ActionPedestal"]:
		check(battle_source.contains('name = "' + component_name + '"'),
				"battle exposes premium " + component_name)
	var textured_panel := UiKit.textured_panel(
			"res://assets/art/ui/battle_panel.png", 26)
	check(textured_panel.custom_minimum_size.y > 0.0,
			"textured panel has minimum size")
	var icon_control := UiKit.icon_button(
			"res://assets/art/ui/icon_undo.png", 3, "Undo last pour")
	check(icon_control.tooltip_text == "Undo last pour", "icon button tooltip")
	check(icon_control.custom_minimum_size.x >= 84.0, "icon button touch target")
	var kit := UiKit.new()
	check(kit.has_method("ornate_button"), "ornate button factory")
	check(kit.has_method("enemy_portrait"), "enemy portrait factory")
	check(kit.has_method("map_node_button"), "map node factory")
	var registry := VisualRegistry.new()
	check(registry.has_method("ui_icon"), "UI icon registry interface")
	if registry.has_method("ui_icon"):
		for icon_id in ["undo", "mix", "pause", "music", "sound", "vibration"]:
			var icon_path := str(registry.call("ui_icon", icon_id))
			check(ResourceLoader.exists(icon_path), "registered UI icon: " + icon_id)
			var icon_texture := load(icon_path) as Texture2D
			check(icon_texture != null and icon_texture.get_width() == 512 \
					and icon_texture.get_height() == 512,
					"UI icon dimensions: " + icon_id)
	check(kit.has_method("layout_profile"), "responsive layout profile interface")
	if kit.has_method("layout_profile"):
		var standard: Dictionary = kit.call("layout_profile", Vector2(720, 1280))
		var tall: Dictionary = kit.call("layout_profile", Vector2(576, 1280))
		check(standard.get("name") == "standard", "standard portrait profile")
		check(tall.get("name") == "tall", "tall phone profile")
		var ratio_sum := float(tall.get("arena_ratio", 0.0)) \
				+ float(tall.get("status_ratio", 0.0)) \
				+ float(tall.get("board_ratio", 0.0)) \
				+ float(tall.get("controls_ratio", 0.0))
		check(is_equal_approx(ratio_sum, 1.0), "responsive battle bands fill height")
		check(float(tall.get("safe_horizontal", 0.0)) >= 20.0,
				"tall profile keeps safe margins")
	var menu_source := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	check(menu_scene != null, "main menu scene loads")
	if menu_scene != null:
		var menu_instance := menu_scene.instantiate()
		check(menu_instance != null, "main menu scene instantiates")
		menu_instance.free()
	check(VisualRegistry.background("main_hall") ==
			"res://assets/art/backgrounds/main_hall_v2.png",
			"main hall uses generated premium alchemy art")
	for menu_component in ["HallLogo", "HeroAlchemy", "CommandStack",
			"BottomNavigation"]:
		check(menu_source.contains('name = "' + menu_component + '"'),
				"main menu exposes premium " + menu_component)
	check(ResourceLoader.exists("res://src/ui/ambient_particles.gd"),
			"hall ambient particles script exists")
	var ambient := AmbientParticles.new()
	check(ambient.has_method("set_reduced_effects"),
			"hall ambient particles reduced-effects interface")
	ambient.free()
	var settings_source := FileAccess.get_file_as_string("res://src/ui/settings_screen.gd")
	for row_name in ["MusicRow", "SoundRow", "VibrationRow", "AssistModeRow"]:
		check(settings_source.contains('name = "' + row_name + '"'),
				"settings exposes aligned " + row_name)
	check(settings_source.contains('name = "ReplayTutorial"'),
			"settings exposes tutorial replay")
	var tutorial_source := FileAccess.get_file_as_string("res://src/ui/tutorial.gd")
	for tutorial_node in ["TutorialDimTop", "TutorialDimBottom", "TutorialDimLeft",
			"TutorialDimRight", "TutorialPointer", "TutorialCard", "TutorialSkip"]:
		check(tutorial_source.contains(tutorial_node),
				"guided tutorial exposes " + tutorial_node)
	var route := DungeonRoute.new()
	check(route.has_method("configure"), "dungeon route data interface")
	check(DungeonRoute.NODE_POSITIONS.size() == 7,
			"dungeon route has seven illustrated encounters")
	route.queue_free()
	for audio_path in [
		"res://assets/audio/dungeon_ambient.wav",
		"res://assets/audio/boss_ambient.wav",
	]:
		check(ResourceLoader.exists(audio_path), "loadable ambient: " + audio_path)
	check(AudioManager.has_method("crossfade_music"), "ambient crossfade interface")
	check(AudioManager.has_method("set_combat_layer"), "layered combat music interface")
	check(AudioManager.has_method("preview_music"), "music preview interface")
	check(settings_source.contains('name = "MusicPreviewRow"'), "settings exposes music preview row")
	check(fx.has_method("play_combo"), "combo spectacle interface")
	check(fx.has_method("play_ultimate"), "ultimate spectacle interface")
	check(fx.has_method("play_phase_transition"), "boss phase spectacle interface")
	var shop_source := FileAccess.get_file_as_string("res://src/ui/shop_screen.gd")
	check(shop_source.contains('name = "WorkshopHeader"'), "workshop responsive header")
	check(shop_source.contains('name = "UpgradeSigil"'),
			"workshop upgrade rows use illustrated sigils")
	var credits_source := FileAccess.get_file_as_string("res://src/ui/credits_screen.gd")
	check(credits_source.contains('name = "CreditsPanel"'), "credits full-height panel")
	textured_panel.queue_free()
	icon_control.queue_free()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
