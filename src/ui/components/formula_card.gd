class_name FormulaCard
extends QuietSurface
## Readable, restrained formula presentation. The illustrated sockets carry
## the alchemy identity while the supporting surface keeps long copy calm.


func configure(formula_id: String, formula: Dictionary, discovered: bool) -> FormulaCard:
	name = "FormulaCard_" + formula_id
	custom_minimum_size.y = 126
	set_accent(Color("c989ff") if discovered else Color("61556e"), 0.68)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiThemeTokens.space("lg"))
	add_child(row)

	var recipe := VBoxContainer.new()
	recipe.custom_minimum_size.x = 142
	recipe.alignment = BoxContainer.ALIGNMENT_CENTER
	recipe.add_theme_constant_override("separation", UiThemeTokens.space("xs"))
	row.add_child(recipe)
	var category := UiKit.caption_label(_category(formula, discovered),
			Color("a9dfff") if discovered else UiKit.COLOR_TEXT_DIM)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	recipe.add_child(category)
	var sockets := HBoxContainer.new()
	sockets.name = "FormulaSockets"
	sockets.alignment = BoxContainer.ALIGNMENT_BEGIN
	sockets.add_theme_constant_override("separation", UiThemeTokens.space("xs"))
	recipe.add_child(sockets)
	for raw_essence in formula.get("pattern", []):
		sockets.add_child(FormulaSocket.new().configure(str(raw_essence), discovered))

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", UiThemeTokens.space("xs"))
	row.add_child(copy)
	var title_text := str(formula.get("name", formula_id)).to_upper() if discovered \
			else "UNDISCOVERED FORMULA"
	var title := UiKit.title_label(title_text, UiThemeTokens.type_size("subtitle"),
			Color("f5d681") if discovered else Color("9a8fa6"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(title)
	var description := str(formula.get("description", "")) if discovered \
			else "Complete potions in the right sequence to reveal this reaction."
	var body := UiKit.body_label(description,
			UiKit.COLOR_TEXT if discovered else UiKit.COLOR_TEXT_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	copy.add_child(body)
	return self


func _category(formula: Dictionary, discovered: bool) -> String:
	if not discovered:
		return "LOCKED RECIPE"
	var tags: Array = formula.get("tags", [])
	var category := str(tags[0]).to_upper() if not tags.is_empty() else "REACTION"
	return "%d-ESSENCE • %s" % [formula.get("pattern", []).size(), category]
