class_name BattleLog
extends PanelContainer
## The running combat journal under the vitals. It replaces the old static
## objective/intent strip: every meaningful beat of the fight — potions brewed,
## reactions fired, damage taken, enemy tells, objective progress — lands here
## in the order it happened, newest line at the bottom.
##
## Labels here deliberately never combine `AUTOWRAP_WORD_SMART` with
## `OVERRUN_TRIM_ELLIPSIS`: that pair reports a 1px minimum height, which is
## what silently collapsed this panel to an empty black box.

const VISIBLE_ENTRIES := 3
const ENTRY_HEIGHT := 20
const HEADER_HEIGHT := 18
## Deliberately below the caption token: the journal has to stay compact enough
## that the potion board keeps its height on short phones.
const ENTRY_FONT_SIZE := 12
const HEADER_FONT_SIZE := 11

## Every log line is tagged so its colour carries meaning at a glance.
const KIND_COLORS := {
	"player": Color("ffd98a"),
	"damage": Color("ff9b6d"),
	"heal": Color("7ee0a0"),
	"shield": Color("7fc9ff"),
	"reaction": Color("d9a4ff"),
	"enemy": Color("ff8a68"),
	"trick": Color("d9a4ff"),
	"objective": Color("f1c45c"),
	"system": Color("c6b2e2"),
}
const KIND_GLYPHS := {
	"player": "◆",
	"damage": "✦",
	"heal": "✚",
	"shield": "◈",
	"reaction": "✷",
	"enemy": "⚔",
	"trick": "◆",
	"objective": "◈",
	"system": "·",
}

var objective_label: Label
var _entry_labels: Array[Label] = []
var _entries: Array[Dictionary] = []
var _last_intent := ""
var _last_trick := ""
var _built := false


func _init() -> void:
	name = "BattleLog"
	custom_minimum_size = Vector2(0, HEADER_HEIGHT + 1 + VISIBLE_ENTRIES * ENTRY_HEIGHT + 6)


func _ready() -> void:
	if _built:
		return
	_built = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.012, 0.045, 0.94)
	style.border_color = Color("795c31")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.name = "BattleLogStack"
	stack.add_theme_constant_override("separation", 0)
	add_child(stack)

	var header := HBoxContainer.new()
	header.name = "BattleLogHeader"
	header.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	header.add_theme_constant_override("separation", 10)
	stack.add_child(header)
	var heading := _line("⚗  BATTLE LOG", Color("c8a761"), HEADER_FONT_SIZE)
	heading.name = "BattleLogHeading"
	heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	heading.custom_minimum_size = Vector2(116, HEADER_HEIGHT)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	objective_label = _line("", UiKit.COLOR_GOLD, HEADER_FONT_SIZE)
	objective_label.name = "ObjectiveText"
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(objective_label)

	var rule := ColorRect.new()
	rule.name = "BattleLogRule"
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color("795c31", 0.5)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(rule)

	for index in VISIBLE_ENTRIES:
		var entry := _line("", UiKit.COLOR_TEXT_DIM)
		entry.name = "BattleLogEntry%d" % index
		entry.custom_minimum_size = Vector2(0, ENTRY_HEIGHT)
		entry.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_entry_labels.append(entry)
		stack.add_child(entry)
	_render()


## Appends a line. `kind` picks the colour and glyph; repeats of the newest line
## are collapsed into a "xN" counter so combo spam stays readable.
func push_entry(text: String, kind := "system") -> void:
	if text.strip_edges().is_empty():
		return
	if not _entries.is_empty():
		var newest: Dictionary = _entries[_entries.size() - 1]
		if str(newest.get("text", "")) == text and str(newest.get("kind", "")) == kind:
			newest["count"] = int(newest.get("count", 1)) + 1
			_render()
			return
	_entries.append({"text": text, "kind": kind, "count": 1})
	if _entries.size() > VISIBLE_ENTRIES:
		_entries = _entries.slice(_entries.size() - VISIBLE_ENTRIES)
	_render()
	_flash_newest()


func set_objective(text: String) -> void:
	if objective_label == null:
		return
	objective_label.text = text
	objective_label.tooltip_text = text


## Fed by the battle screen on every tactical refresh. Only genuine changes to
## the enemy's telegraphed action or active puzzle trick become log lines, so
## the countdown ticking down move by move never floods the journal.
func update_payload(intent: Dictionary, trick: Dictionary) -> void:
	var intent_label := str(intent.get("label", "Attack"))
	var intent_damage := int(intent.get("damage_max", 0))
	var intent_key := "%s|%d" % [intent_label, intent_damage]
	if intent_key != _last_intent:
		_last_intent = intent_key
		push_entry("Enemy readies %s — %d dmg in %d moves" % [intent_label,
				intent_damage, int(intent.get("moves", 0))], "enemy")
	var trick_id := str(trick.get("id", ""))
	if trick_id != _last_trick:
		_last_trick = trick_id
		if not trick_id.is_empty():
			push_entry("Puzzle trick: %s in %d moves" % [
					str(trick.get("label", trick_id.capitalize())),
					int(trick.get("moves_remaining", 0))], "trick")


func _render() -> void:
	var offset := VISIBLE_ENTRIES - _entries.size()
	for index in _entry_labels.size():
		var label := _entry_labels[index]
		var entry_index := index - offset
		if entry_index < 0:
			label.text = ""
			label.tooltip_text = ""
			continue
		var entry: Dictionary = _entries[entry_index]
		var kind := str(entry.get("kind", "system"))
		var count := int(entry.get("count", 1))
		var body := str(entry.get("text", ""))
		if count > 1:
			body += "  ×%d" % count
		label.text = "%s  %s" % [str(KIND_GLYPHS.get(kind, "·")), body]
		label.tooltip_text = body
		var color: Color = KIND_COLORS.get(kind, UiKit.COLOR_TEXT_DIM)
		# Older lines recede so the eye lands on the most recent beat.
		var age := _entries.size() - 1 - entry_index
		label.add_theme_color_override("font_color",
				color.lerp(Color(0.42, 0.38, 0.5), 0.30 * float(age)))


func _flash_newest() -> void:
	if not is_inside_tree() or _entry_labels.is_empty():
		return
	var newest := _entry_labels[_entry_labels.size() - 1]
	newest.modulate.a = 0.0
	newest.position.x = 10.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(newest, "modulate:a", 1.0, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(newest, "position:x", 0.0, 0.22) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _line(text: String, color: Color, size := ENTRY_FONT_SIZE) -> Label:
	var label := UiKit.label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
