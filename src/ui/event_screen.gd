extends Control

var event_id := "whispering_well"
var resolver := EventResolver.new()
var choice_box: VBoxContainer
var status: Label

func _ready() -> void:
	AudioManager.set_area(str(RunState.current_area().get("music", "dungeon")))
	AudioManager.set_scene_state("event")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var shade := ColorRect.new(); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.005, 0.03, 0.7); add_child(shade)
	var node := RunState.current_node(); var kind := str(node.get("kind", "event"))
	event_id = str(node.get("event_id", _event_for_kind(kind)))
	var event: Dictionary = resolver.events.get(event_id, {})
	var margin := UiKit.safe_margin(self, 28, 90, 32)
	var root := VBoxContainer.new(); root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 22); margin.add_child(root)
	root.add_child(UiKit.title_label(str(event.get("name", "MYSTERIOUS CHAMBER")).to_upper(), 38))
	var art := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 28)
	art.custom_minimum_size = Vector2(0, 420); art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(art)
	var text := UiKit.label(str(event.get("text", "The dungeon waits.")), 22, UiKit.COLOR_TEXT)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	art.add_child(text)
	status = UiKit.label("Choose one. The result is permanent for this run.", 15, UiKit.COLOR_TEXT_DIM)
	root.add_child(status)
	choice_box = VBoxContainer.new(); choice_box.add_theme_constant_override("separation", 12); root.add_child(choice_box)
	for choice_id in event.get("choices", {}):
		var choice: Dictionary = event.choices[choice_id]
		var summary := resolver.choice_summary(event_id, str(choice_id))
		var button := UiKit.ornate_button("%s\n%s" % [str(choice.label).to_upper(), summary],
				Vector2(560, 108))
		button.add_theme_font_size_override("font_size", 20)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_choose.bind(str(choice_id))); choice_box.add_child(button)

func _choose(choice_id: String) -> void:
	var result := resolver.apply(event_id, choice_id, RunState)
	if not result.ok: status.text = "Cannot choose: " + str(result.reason); return
	RunState.checkpoint(RunState.PHASE_MAP)
	for child in choice_box.get_children(): child.queue_free()
	status.text = "APPLIED  •  " + str(result.get("result_summary", "Choice sealed."))
	var continue_button := UiKit.ornate_button("RETURN TO MAP", Vector2(430, 68))
	continue_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map.tscn"))
	choice_box.add_child(continue_button)

func _event_for_kind(kind: String) -> String:
	match kind:
		"treasure": return "cursed_chest"
		"campfire": return "ember_camp"
		"shop": return "bound_alchemist"
		_: return ["whispering_well", "mirror_cauldron", "bone_oracle"][abs(RunState.run_seed) % 3]
