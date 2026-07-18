extends Control
## Starting archetype selection. A choice is committed only on confirmation.

const KIT_COPY := {
	"ember_adept": ["EMBER ADEPT", "Fire combos and explosive damage",
			"FLASH BOIL", "Double the next Fire Potion"],
	"verdant_warden": ["VERDANT WARDEN", "Healing, shields and purification",
			"PURIFY", "Cleanse a curse and gain shield"],
	"void_brewer": ["VOID BREWER", "Poison, wild essence and control",
			"TRANSMUTE", "Turn one exposed layer into Wild Essence"],
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.005, 0.025, 0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := UiKit.safe_margin(self, 24, 34, 24)
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	root.add_child(UiKit.title_label("CHOOSE YOUR BREWER", 42))
	root.add_child(UiKit.label("Each kit changes your active skill and ultimate.",
			17, UiKit.COLOR_TEXT_DIM))
	for kit_id in ["ember_adept", "verdant_warden", "void_brewer"]:
		root.add_child(_kit_choice(kit_id))
	var back := UiKit.ornate_button("BACK TO HALL", Vector2(360, 64))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	root.add_child(back)


func _kit_choice(kit_id: String) -> PanelContainer:
	var copy: Array = KIT_COPY[kit_id]
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 22)
	panel.name = "KitChoice"
	panel.custom_minimum_size = Vector2(0, 210)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var sigil := Label.new()
	sigil.text = "◆"
	sigil.custom_minimum_size = Vector2(70, 0)
	sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil.add_theme_font_size_override("font_size", 44)
	sigil.add_theme_color_override("font_color", _kit_color(kit_id))
	row.add_child(sigil)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(UiKit.title_label(str(copy[0]), 25, _kit_color(kit_id)))
	info.add_child(UiKit.label(str(copy[1]), 15, UiKit.COLOR_TEXT))
	info.add_child(UiKit.label("ACTIVE — %s" % str(copy[2]), 14, UiKit.COLOR_GOLD))
	info.add_child(UiKit.label(str(copy[3]), 13, UiKit.COLOR_TEXT_DIM))
	var choose := UiKit.ornate_button("SELECT", Vector2(150, 62), _kit_color(kit_id))
	choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choose.pressed.connect(func() -> void:
		RunState.start_new_run(kit_id)
		get_tree().change_scene_to_file(RunState.resume_scene()))
	row.add_child(choose)
	return panel


func _kit_color(kit_id: String) -> Color:
	match kit_id:
		"verdant_warden": return Color("66d978")
		"void_brewer": return Color("c26cff")
		_: return Color("ff8a42")
