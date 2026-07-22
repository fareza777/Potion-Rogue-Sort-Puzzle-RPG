class_name GuideScreen
extends Control
## Permanent, data-backed manual. Safe to open between or during encounters.

static var return_scene := ""
static var initial_section := "basics"

const ESSENCE_COLORS := {
	"red": Color("ff5548"), "green": Color("55df72"),
	"blue": Color("4ba8ff"), "purple": Color("b85cff"), "wild": Color("f4ca62"),
}

var _tabs: HBoxContainer
var _cards: VBoxContainer
var _title: Label
var _intro: Label
var _scroll: ScrollContainer
var _selected := "basics"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var shade := ColorRect.new(); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.006, 0.003, 0.018, 0.60); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := UiKit.safe_margin(self, 18, 30, 20)
	var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var eyebrow := UiKit.label("ALCHEMIST'S ARCHIVE", 13, Color("88dcff"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(eyebrow)
	var heading := UiKit.title_label("PLAYER GUIDE", 38, Color("f4d27a"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(heading)
	var tab_scroll := ScrollContainer.new(); tab_scroll.name = "GuideTabScroll"
	tab_scroll.custom_minimum_size.y = 58; tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; root.add_child(tab_scroll)
	_tabs = HBoxContainer.new(); _tabs.name = "GuideTabs"; _tabs.add_theme_constant_override("separation", 7)
	tab_scroll.add_child(_tabs)
	for item in GuideContent.sections():
		var id := str(item.id)
		var tab := UiKit.button(str(item.title), Vector2(126, 50), Color("9f73cf"))
		tab.name = "GuideTab_" + id; tab.pressed.connect(func() -> void: open_section(id))
		_tabs.add_child(tab)
	_scroll = ScrollContainer.new(); _scroll.name = "GuideScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 8; root.add_child(_scroll)
	_cards = VBoxContainer.new(); _cards.name = "GuideCards"
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 10); _scroll.add_child(_cards)
	_title = UiKit.title_label("", 29, Color("f5d681")); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards.add_child(_title)
	_intro = UiKit.label("", 17, UiKit.COLOR_TEXT); _intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _cards.add_child(_intro)
	var back := UiKit.ornate_button("RETURN", Vector2(340, 62)); back.name = "ReturnButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; back.pressed.connect(_return)
	root.add_child(back)
	open_section(initial_section)
	initial_section = "basics"
	AudioManager.play_music("dungeon"); AudioManager.set_scene_state("menu")


func open_section(id: String) -> void:
	_selected = id
	var data := GuideContent.section(_selected)
	_title.text = str(data.get("title", "GUIDE")); _intro.text = str(data.get("body", ""))
	for child in _cards.get_children():
		if child != _title and child != _intro: child.queue_free()
	for card in data.get("cards", []): _cards.add_child(_guide_card(card))
	if _selected == "reactions":
		var formulas := UiKit.ornate_button("OPEN FORMULA CODEX", Vector2(390, 62), Color("c989ff"))
		formulas.name = "FormulaCodexButton"; formulas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		formulas.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/reaction_codex.tscn"))
		_cards.add_child(formulas)
	else:
		var anchor := Control.new(); anchor.name = "FormulaCodexButton"; anchor.visible = false
		_cards.add_child(anchor)
	await get_tree().process_frame
	_scroll.scroll_vertical = 0
	for tab in _tabs.get_children(): tab.disabled = tab.name == "GuideTab_" + _selected


func _guide_card(data: Dictionary) -> PanelContainer:
	var card := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 18)
	card.custom_minimum_size.y = 116
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 7); card.add_child(column)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); column.add_child(row)
	for essence in data.get("essences", []):
		var dot := PanelContainer.new(); dot.custom_minimum_size = Vector2(30, 30)
		var style := StyleBoxFlat.new(); style.bg_color = ESSENCE_COLORS.get(str(essence), Color("7f718b"))
		style.border_color = Color("fff3cf"); style.set_border_width_all(2); style.set_corner_radius_all(15)
		dot.add_theme_stylebox_override("panel", style); row.add_child(dot)
	var title := UiKit.title_label(str(data.get("title", "LESSON")), 20, Color(str(data.get("accent", "f2cc72"))))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(title)
	var copy := UiKit.label(str(data.get("copy", "")), 16, UiKit.COLOR_TEXT)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(copy)
	return card


func _return() -> void:
	var destination := return_scene; return_scene = ""
	if destination.is_empty(): destination = RunState.resume_scene() if RunState.active else "res://scenes/main_menu.tscn"
	get_tree().change_scene_to_file(destination)
