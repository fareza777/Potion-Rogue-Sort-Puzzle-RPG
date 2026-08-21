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
const MAX_HISTORY_ENTRIES := 100
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
var _history_popup: Control
var _history_layer: CanvasLayer
var _history_stack: VBoxContainer
var _history_scroll: ScrollContainer
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
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL

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
	if _entries.size() > MAX_HISTORY_ENTRIES:
		_entries = _entries.slice(_entries.size() - MAX_HISTORY_ENTRIES)
	_render()
	_flash_newest()


func history_entries() -> Array:
	return _entries.duplicate(true)


func open_history() -> void:
	_ensure_history_overlay()
	if _history_popup == null:
		return
	_render_history()
	_history_popup.visible = true
	call_deferred("_scroll_history_to_bottom")


func close_history() -> void:
	if _history_popup != null:
		_history_popup.visible = false


func _exit_tree() -> void:
	close_history()
	if is_instance_valid(_history_layer):
		_history_layer.queue_free()
	_history_layer = null
	_history_popup = null
	_history_stack = null
	_history_scroll = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		open_history()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		open_history()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		open_history()
		accept_event()


## In-tree overlay, not a native Window/PopupPanel. Those look like a stretched
## OS dialog on Android and have crashed the activity on the battle-to-map swap.
func _ensure_history_overlay() -> void:
	if is_instance_valid(_history_popup):
		return
	_history_layer = CanvasLayer.new()
	_history_layer.name = "BattleLogHistoryLayer"
	_history_layer.layer = 80
	add_child(_history_layer)

	_history_popup = Control.new()
	_history_popup.name = "BattleLogHistoryPopup"
	_history_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_history_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_history_popup.visible = false
	_history_layer.add_child(_history_popup)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.005, 0.03, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_history()
		elif event is InputEventScreenTouch and event.pressed:
			close_history())
	_history_popup.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_popup.add_child(center)

	var view := get_viewport_rect().size
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 18)
	panel.custom_minimum_size = Vector2(minf(640.0, maxf(view.x - 36.0, 280.0)),
			minf(920.0, view.y * 0.78))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var heading := UiKit.title_label("BATTLE HISTORY", 26, UiKit.COLOR_GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(heading)
	var close := UiKit.cta_bar("CLOSE", Color("bda8c9"), 52)
	close.name = "BattleLogHistoryClose"
	close.custom_minimum_size = Vector2(128, 52)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(close_history)
	header.add_child(close)

	var hint := UiKit.caption_label("Newest actions at the bottom. Swipe inside the journal to review.",
			UiKit.COLOR_TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var journal := PanelContainer.new()
	journal.name = "BattleLogHistoryBox"
	journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.035, 0.016, 0.06, 0.96)
	inner.border_color = Color("795c31")
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(10)
	inner.content_margin_left = 12
	inner.content_margin_right = 12
	inner.content_margin_top = 10
	inner.content_margin_bottom = 10
	journal.add_theme_stylebox_override("panel", inner)
	root.add_child(journal)

	_history_scroll = ScrollContainer.new()
	_history_scroll.name = "BattleLogHistoryScroll"
	_history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_history_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	journal.add_child(_history_scroll)
	_history_stack = VBoxContainer.new()
	_history_stack.name = "BattleLogHistoryEntries"
	_history_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_stack.add_theme_constant_override("separation", 6)
	_history_scroll.add_child(_history_stack)


func _render_history() -> void:
	if _history_stack == null:
		return
	for child in _history_stack.get_children():
		child.queue_free()
	if _entries.is_empty():
		_history_stack.add_child(UiKit.body_label("No battle actions recorded yet.",
				UiKit.COLOR_TEXT_DIM))
		return
	for entry in _entries:
		var kind := str(entry.get("kind", "system"))
		var body := str(entry.get("text", ""))
		var count := int(entry.get("count", 1))
		if count > 1:
			body += "  ×%d" % count
		var line := UiKit.body_label("%s  %s" % [str(KIND_GLYPHS.get(kind, "·")), body],
				KIND_COLORS.get(kind, UiKit.COLOR_TEXT_DIM))
		line.add_theme_font_size_override("font_size", 17)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.custom_minimum_size.y = 36
		_history_stack.add_child(line)


func _scroll_history_to_bottom() -> void:
	if _history_scroll == null:
		return
	await get_tree().process_frame
	if _history_scroll != null:
		_history_scroll.scroll_vertical = int(_history_scroll.get_v_scroll_bar().max_value)


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
