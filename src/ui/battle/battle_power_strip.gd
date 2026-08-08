class_name BattlePowerStrip
extends PanelContainer
## Compact battle-resource presenter. It owns visual controls only; combat
## rules remain in SkillController and BattleScreen.

signal skill_requested
signal ultimate_requested
signal codex_requested

var mana_bar: ProgressBar
var mana_label: Label
var reaction_chamber: ReactionChamber
var skill_button: Button
var ultimate_button: Button
var skill_reason: Label
var ultimate_reason: Label


func _init() -> void:
	name = "BattlePowerStrip"
	custom_minimum_size = Vector2(0, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.012, 0.045, 0.94)
	style.border_color = Color(UiThemeTokens.BORDER, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = UiThemeTokens.space("sm")
	style.content_margin_right = UiThemeTokens.space("sm")
	style.content_margin_top = UiThemeTokens.space("xs")
	style.content_margin_bottom = UiThemeTokens.space("xs")
	add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	add_child(stack)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiThemeTokens.space("sm"))
	stack.add_child(row)

	var mana_stack := VBoxContainer.new()
	mana_stack.custom_minimum_size = Vector2(120, 52)
	mana_stack.add_theme_constant_override("separation", 1)
	row.add_child(mana_stack)
	mana_label = UiKit.caption_label("MANA  0/100", Color("73d9ff"))
	mana_label.name = "ManaLabel"
	mana_stack.add_child(mana_label)
	mana_bar = UiKit.bar(Color("368ed8"), 18)
	mana_bar.name = "ManaMeter"
	mana_bar.max_value = 100
	mana_stack.add_child(mana_bar)

	reaction_chamber = ReactionChamber.new()
	reaction_chamber.name = "ComboSlots"
	reaction_chamber.custom_minimum_size.x = 120
	reaction_chamber.codex_requested.connect(func() -> void: codex_requested.emit())
	row.add_child(reaction_chamber)

	skill_button = UiKit.button("SKILL", Vector2(112, 52), Color("70d9ff"))
	skill_button.name = "SkillButton"
	skill_button.clip_text = true
	skill_button.add_theme_font_size_override("font_size", UiKit.scaled_text_size(14))
	skill_button.pressed.connect(func() -> void: skill_requested.emit())
	row.add_child(skill_button)
	ultimate_button = UiKit.button("ULT 0%", Vector2(92, 52), Color("ffb84d"))
	ultimate_button.name = "UltimateButton"
	ultimate_button.clip_text = true
	ultimate_button.add_theme_font_size_override("font_size", UiKit.scaled_text_size(14))
	ultimate_button.pressed.connect(func() -> void: ultimate_requested.emit())
	row.add_child(ultimate_button)

	var reasons := HBoxContainer.new()
	reasons.add_theme_constant_override("separation", UiThemeTokens.space("sm"))
	stack.add_child(reasons)
	skill_reason = UiKit.caption_label("", Color("a9dfff"))
	skill_reason.name = "SkillDisabledReason"
	skill_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reasons.add_child(skill_reason)
	ultimate_reason = UiKit.caption_label("", Color("ffd17b"))
	ultimate_reason.name = "UltimateDisabledReason"
	ultimate_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ultimate_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ultimate_reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reasons.add_child(ultimate_reason)


func update_model(model: Dictionary) -> void:
	var mana := clampi(int(model.get("mana", 0)), 0, 100)
	mana_bar.value = mana
	mana_label.text = "MANA  %d/100" % mana
	var history: Array[String] = []
	for raw_essence in model.get("history", []):
		history.append(str(raw_essence))
	reaction_chamber.set_history(history)

	skill_button.text = str(model.get("skill_name", "SKILL")).to_upper()
	skill_button.disabled = not bool(model.get("skill_ready", false))
	skill_reason.text = str(model.get("skill_disabled_reason", "READY"))
	skill_reason.tooltip_text = skill_reason.text
	skill_button.tooltip_text = str(model.get("skill_tooltip", skill_reason.text))

	var charge := clampi(int(model.get("ultimate_charge", 0)), 0, 100)
	ultimate_button.text = "ULT %d%%" % charge
	ultimate_button.disabled = not bool(model.get("ultimate_ready", false))
	ultimate_reason.text = str(model.get("ultimate_disabled_reason", "READY"))
	ultimate_reason.tooltip_text = ultimate_reason.text
	ultimate_button.tooltip_text = str(model.get("ultimate_tooltip", ultimate_reason.text))
