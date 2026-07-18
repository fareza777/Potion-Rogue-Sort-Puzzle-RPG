class_name TacticalReadout
extends PanelContainer
## Responsive two-row tactical hierarchy for objective, intent, and enemy trick.

var objective_label: Label
var intent_label: Label
var trick_label: Label


func _init() -> void:
	name = "TacticalReadout"
	custom_minimum_size = Vector2(0, 64)


func _ready() -> void:
	if objective_label != null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.012, 0.045, 0.94)
	style.border_color = Color("795c31")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	add_child(stack)
	objective_label = UiKit.label("OBJECTIVE", 12, UiKit.COLOR_GOLD)
	objective_label.name = "ObjectiveText"
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_label.tooltip_text = objective_label.text
	stack.add_child(objective_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stack.add_child(row)
	intent_label = UiKit.label("NEXT", 12, UiKit.COLOR_FIRE)
	intent_label.name = "EnemyIntent"
	intent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	intent_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(intent_label)
	trick_label = UiKit.label("TRICK", 11, Color("d9a4ff"))
	trick_label.name = "EnemyTrick"
	trick_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trick_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(trick_label)


func set_objective(text: String) -> void:
	objective_label.text = text
	objective_label.tooltip_text = text


func update_payload(objective: String, intent: Dictionary, trick: Dictionary) -> void:
	set_objective(objective)
	var intent_text := "NEXT  %s  %d dmg  •  %d moves" % [
		str(intent.get("label", "Attack")),
		int(intent.get("damage_max", 0)),
		int(intent.get("moves", 0)),
	]
	intent_label.text = intent_text
	intent_label.tooltip_text = intent_text
	var trick_id := str(trick.get("id", ""))
	var trick_text := "NO PUZZLE TRICK" if trick_id.is_empty() else "TRICK  %s  •  %d moves" % [
		str(trick.get("label", trick_id.capitalize())),
		int(trick.get("moves_remaining", 0)),
	]
	trick_label.text = trick_text
	trick_label.tooltip_text = trick_text

