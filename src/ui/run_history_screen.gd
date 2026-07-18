extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var margin := UiKit.safe_margin(self, 24, 44, 24)
	var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 12); margin.add_child(root)
	root.add_child(UiKit.title_label("RUN HISTORY", 38))
	root.add_child(UiKit.label("Your latest 20 expeditions — newest first", 16, UiKit.COLOR_TEXT_DIM))
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 8); scroll.add_child(list)
	var records := MetaProgression.new().history()
	if records.is_empty(): list.add_child(UiKit.label("No completed runs yet.", 20, UiKit.COLOR_TEXT))
	for raw_record in records:
		var record: Dictionary = raw_record
		var card := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 16); card.custom_minimum_size.y = 88
		var copy := "%s  •  %s  •  Depth %d  •  %d crystals\nSeed %s" % [str(record.get("result", "run")).to_upper(), str(record.get("mode", "normal")).to_upper(), int(record.get("depth", 0)), int(record.get("crystals", 0)), str(record.get("seed", 0))]
		card.add_child(UiKit.label(copy, 16, UiKit.COLOR_TEXT)); list.add_child(card)
	var back := UiKit.ornate_button("BACK", Vector2(300, 62)); back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/area_select.tscn")); root.add_child(back)
