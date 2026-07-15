extends Control
## Battle screen: builds the whole layout in code (placeholder UI phase),
## wires PuzzleBoard <-> BattleManager, and shows victory/defeat/pause overlays.
##
## Layout (portrait 720x1280):
##   [ enemy panel: name, sprite, HP bar, poison status, attack countdown ]
##   [ player panel: HP bar + shield ]
##   [ event message ]
##   [ puzzle board (6 tubes) ]
##   [ buttons: Undo | Restart | Pause ]

const BG_COLOR := Color("14101f")
const PANEL_COLOR := Color("241b38")
const ACCENT_COLOR := Color("b9a7e8")

var battle: BattleManager
var board: PuzzleBoard
var undo_left := 0

var enemy_name_label: Label
var enemy_display: EnemyDisplay
var enemy_hp_bar: ProgressBar
var enemy_hp_label: Label
var poison_label: Label
var countdown_label: Label
var player_hp_bar: ProgressBar
var player_hp_label: Label
var shield_label: Label
var message_label: Label
var undo_button: Button
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_buttons: HBoxContainer


func _ready() -> void:
	_build_ui()

	battle = BattleManager.new()
	add_child(battle)
	battle.stats_changed.connect(_refresh)
	battle.potion_activated.connect(_on_potion_activated)
	battle.enemy_attacked.connect(_on_enemy_attacked)
	battle.poison_ticked.connect(_on_poison_ticked)
	battle.battle_won.connect(_on_battle_won)
	battle.battle_lost.connect(_on_battle_lost)

	board.move_made.connect(battle.on_move)
	board.tube_completed.connect(battle.on_potion_completed)
	board.board_refilled.connect(func() -> void: _set_message("New potions brewed!"))

	battle.setup("slime")
	undo_left = int(GameState.player.get("undos_per_battle", 3))
	_set_message("Sort potions of the same color to attack!")
	_refresh()


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 48)   # notch safe zone
	margin.add_theme_constant_override("margin_bottom", 40)  # nav bar safe zone
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_enemy_panel())
	root.add_child(_build_player_panel())

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color("ffd77a"))
	message_label.custom_minimum_size = Vector2(0, 36)
	root.add_child(message_label)

	board = PuzzleBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board)

	root.add_child(_build_button_row())
	_build_overlay()


func _build_enemy_panel() -> PanelContainer:
	var panel := _make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	enemy_name_label = Label.new()
	enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_name_label.add_theme_font_size_override("font_size", 32)
	enemy_name_label.add_theme_color_override("font_color", ACCENT_COLOR)
	box.add_child(enemy_name_label)

	enemy_display = EnemyDisplay.new()
	enemy_display.custom_minimum_size = Vector2(0, 170)
	box.add_child(enemy_display)

	enemy_hp_bar = _make_bar(Color("d94f4f"))
	box.add_child(enemy_hp_bar)
	enemy_hp_label = _make_bar_label(enemy_hp_bar)

	poison_label = Label.new()
	poison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poison_label.add_theme_font_size_override("font_size", 22)
	poison_label.add_theme_color_override("font_color", Color("c07ce8"))
	box.add_child(poison_label)

	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 26)
	countdown_label.add_theme_color_override("font_color", Color("ff9d7a"))
	box.add_child(countdown_label)
	return panel


func _build_player_panel() -> PanelContainer:
	var panel := _make_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var hp_box := VBoxContainer.new()
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hp_box)

	var hp_title := Label.new()
	hp_title.text = "Your HP"
	hp_title.add_theme_font_size_override("font_size", 20)
	hp_box.add_child(hp_title)

	player_hp_bar = _make_bar(Color("4ecf6a"))
	hp_box.add_child(player_hp_bar)
	player_hp_label = _make_bar_label(player_hp_bar)

	shield_label = Label.new()
	shield_label.add_theme_font_size_override("font_size", 26)
	shield_label.add_theme_color_override("font_color", Color("4a9de8"))
	shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(shield_label)
	return panel


func _build_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)

	undo_button = _make_button("Undo")
	undo_button.pressed.connect(_on_undo_pressed)
	row.add_child(undo_button)

	var restart := _make_button("New Mix")
	restart.pressed.connect(_on_restart_pressed)
	row.add_child(restart)

	var pause := _make_button("Pause")
	pause.pressed.connect(_show_pause)
	row.add_child(pause)
	return row


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks input to the board
	overlay.add_child(dim)

	var panel := _make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 44)
	box.add_child(overlay_title)

	overlay_body = Label.new()
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.add_theme_font_size_override("font_size", 24)
	box.add_child(overlay_body)

	overlay_buttons = HBoxContainer.new()
	overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_buttons.add_theme_constant_override("separation", 20)
	box.add_child(overlay_buttons)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(14)
	style.border_color = Color("4a3b6b")
	style.set_border_width_all(2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 34)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("161022")
	bg_style.set_corner_radius_all(8)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar


## Centered value label drawn on top of a bar ("45/60").
func _make_bar_label(bar: ProgressBar) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	bar.add_child(label)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 64)
	button.add_theme_font_size_override("font_size", 24)
	return button


# --- Game events ------------------------------------------------------------

func _refresh() -> void:
	enemy_name_label.text = battle.enemy_name
	enemy_hp_bar.max_value = battle.enemy_max_hp
	enemy_hp_bar.value = battle.enemy_hp
	enemy_hp_label.text = "%d / %d" % [battle.enemy_hp, battle.enemy_max_hp]

	poison_label.text = ("Poisoned: %d dmg, %d turns left"
			% [battle.poison_damage, battle.poison_turns]) \
			if battle.poison_turns > 0 else ""

	var moves := battle.moves_until_attack
	countdown_label.text = "Enemy attacks in %d move%s!" \
			% [moves, "" if moves == 1 else "s"]

	player_hp_bar.max_value = battle.player_max_hp
	player_hp_bar.value = battle.player_hp
	player_hp_label.text = "%d / %d" % [battle.player_hp, battle.player_max_hp]
	shield_label.text = "Shield %d" % battle.shield

	undo_button.text = "Undo (%d)" % undo_left
	undo_button.disabled = undo_left <= 0 or not board.can_undo() or battle.battle_over


func _set_message(text: String) -> void:
	message_label.text = text


func _on_potion_activated(color: String, text: String) -> void:
	_set_message(text)
	if color == "red":
		enemy_display.play_hit()


func _on_enemy_attacked(damage: int, blocked: int) -> void:
	if blocked > 0 and damage > blocked:
		_set_message("%s attacks! Shield blocks %d, you take %d."
				% [battle.enemy_name, blocked, damage - blocked])
	elif blocked >= damage:
		_set_message("%s attacks! Shield blocks everything." % battle.enemy_name)
	else:
		_set_message("%s attacks for %d damage!" % [battle.enemy_name, damage])


func _on_poison_ticked(damage: int) -> void:
	enemy_display.play_hit()
	_set_message("Poison deals %d damage!" % damage)


func _on_battle_won() -> void:
	board.enabled = false
	_show_overlay("Victory!", "The %s is defeated.\nMore battles coming in the next phase!"
			% battle.enemy_name, [
		["Play Again", _restart_battle],
		["Main Menu", _go_to_menu],
	])


func _on_battle_lost() -> void:
	board.enabled = false
	_show_overlay("Defeated...", "The %s got the best of you.\nTry a different potion order!"
			% battle.enemy_name, [
		["Retry", _restart_battle],
		["Main Menu", _go_to_menu],
	])


func _show_pause() -> void:
	if battle.battle_over:
		return
	board.enabled = false
	_show_overlay("Paused", "", [
		["Resume", _hide_overlay],
		["Restart", _restart_battle],
		["Main Menu", _go_to_menu],
	])


## buttons: Array of [text, Callable] pairs.
func _show_overlay(title: String, body: String, buttons: Array) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_body.visible = body != ""
	for child in overlay_buttons.get_children():
		child.queue_free()
	for entry in buttons:
		var button := _make_button(entry[0])
		button.pressed.connect(entry[1])
		overlay_buttons.add_child(button)
	overlay.visible = true


func _hide_overlay() -> void:
	overlay.visible = false
	if not battle.battle_over:
		board.enabled = true


# --- Button handlers --------------------------------------------------------

func _on_undo_pressed() -> void:
	if undo_left <= 0:
		return
	if board.undo():
		undo_left -= 1
		battle.on_undo()
		_set_message("Move undone.")
		_refresh()


func _on_restart_pressed() -> void:
	if battle.battle_over:
		return
	board.generate_board()
	_set_message("Potions remixed!")
	_refresh()


func _restart_battle() -> void:
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
