extends Control
## Full-height illustrated dungeon route with persistent run status and CTA.

const AREA_GRAMMAR := preload("res://src/run/area_grammar.gd")

var route_control: DungeonRoute
var tutorial_director: TutorialDirector


func _ready() -> void:
	AudioManager.set_area(str(RunState.current_area().get("music", "dungeon")))
	AudioManager.set_scene_state("explore")
	if not RunState.active:
		get_tree().change_scene_to_file("res://scenes/area_select.tscn")
		return
	if RunState.phase != RunState.PHASE_MAP:
		get_tree().change_scene_to_file(RunState.resume_scene())
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, str(RunState.current_area().get("background",
			"res://assets/art/backgrounds/shadow_crypt_battle.png")))
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.005, 0.025, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := UiKit.safe_margin(self, 18, 22, 20)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	root.add_child(_make_header())

	var route_panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 10)
	route_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(route_panel)
	route_control = DungeonRoute.new()
	route_control.name = "DungeonRoute"
	route_control.custom_minimum_size = Vector2(0, 860)
	route_panel.add_child(route_control)
	if not RunState.run_graph.is_empty():
		var boss_depth := int(AREA_GRAMMAR.for_area(RunState.area_id).get("run_length", 7)) - 1
		route_control.configure(RunState.run_graph, RunState.current_node_id, boss_depth)
		route_control.node_selected.connect(_on_node_selected)
	else:
		route_control.configure_legacy(RunState.battles(), RunState.battle_index)

	root.add_child(_make_status_panel())
	root.add_child(_make_route_legend())
	if not SaveSystem.is_tutorial_done() and SaveSystem.tutorial_step() >= 9:
		tutorial_director = TutorialDirector.new(); tutorial_director.configure()
		var tutorial := Tutorial.new(); add_child(tutorial)
		tutorial.setup(self, tutorial_director,
				func(_target: String) -> Control: return route_control)


func _on_node_selected(node_id: String) -> void:
	if not RunState.select_node(node_id): return
	if tutorial_director != null: tutorial_director.accept_action("choose_path")
	var kind := str(RunState.current_node().get("kind", "battle"))
	if kind in ["battle", "elite", "boss"]:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/event.tscn")


func _return_to_hall() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _make_header() -> PanelContainer:
	var header := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 10)
	header.custom_minimum_size = Vector2(0, 84)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", -3)
	row.add_child(copy)
	var title := UiKit.title_label(str(RunState.current_area().get("name", "Shadow Crypt")).to_upper(), 29)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	copy.add_child(title)
	var floor := int(RunState.current_node().get("floor", 0)) + 1
	var run_length := int(AREA_GRAMMAR.for_area(RunState.area_id).get("run_length", 7))
	var subtitle := UiKit.label("DEPTH %s OF %s  •  CHOOSE YOUR FATE" % [
			_roman(floor), _roman(run_length)], 12, UiKit.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	copy.add_child(subtitle)
	var back := UiKit.button("BACK TO HALL", Vector2(164, 48), UiKit.COLOR_GOLD)
	back.name = "BackToHallButton"
	back.add_theme_font_size_override("font_size", 16)
	back.tooltip_text = "Return to Hall — run progress is saved"
	back.pressed.connect(_return_to_hall)
	row.add_child(back)
	return header


func _make_route_legend() -> PanelContainer:
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 8)
	panel.name = "RouteLegend"
	panel.custom_minimum_size = Vector2(0, 46)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(UiKit.label("?  PATHS HIDE THEIR GUARDIAN", 11, Color("bca7ca")))
	row.add_child(UiKit.label("✦", 11, UiKit.COLOR_GOLD))
	row.add_child(UiKit.label("MORE FLAMES MEAN MORE RISK", 11, UiKit.COLOR_GOLD))
	return panel


func _roman(value: int) -> String:
	var remaining := maxi(value, 1)
	var result := ""
	var values := [10, 9, 5, 4, 1]
	var numerals := ["X", "IX", "V", "IV", "I"]
	for index in values.size():
		while remaining >= values[index]:
			result += numerals[index]
			remaining -= values[index]
	return result


func _make_status_panel() -> PanelContainer:
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 10)
	panel.custom_minimum_size = Vector2(0, 104)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var hp := RunState.player_hp
	var max_hp := int(RunState.stat("max_hp", float(GameState.player.get("max_hp", 50))))
	if hp < 0:
		hp = max_hp
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	row.add_child(UiKit.label("HP  %d / %d" % [hp, max_hp], 17, UiKit.COLOR_HP))
	row.add_child(UiKit.label("CRYSTALS  %d (+%d)" % [SaveSystem.crystals(), RunState.run_crystals], 17, Color("75d4ff")))
	var summary := BuildSummary.new()
	summary.configure(RunState.kit_id, RunState.relic_ids, RunState.upgrade_ids,
			RunState.mutation_ids, RunState.catalyst_ids)
	box.add_child(summary)
	return panel
