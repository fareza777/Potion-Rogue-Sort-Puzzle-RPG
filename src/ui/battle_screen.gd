extends Control
## Battle screen: wires PuzzleBoard <-> BattleManager, renders the fight and
## handles the run flow (victory -> upgrade choice -> map, boss win -> run
## victory, defeat -> game over). All UI built via UiKit (placeholder-art phase).

var battle: BattleManager
var board: PuzzleBoard
var undo_left := 0

var battle_kind_label: Label
var enemy_name_label: Label
var enemy_display: EnemyDisplay
var enemy_hp_bar: ProgressBar
var enemy_hp_label: Label
var armor_label: Label
var poison_label: Label
var countdown_label: Label
var player_hp_bar: ProgressBar
var player_hp_label: Label
var shield_label: Label
var player_status_label: Label
var message_label: Label
var undo_button: Button
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_choices: VBoxContainer
var overlay_buttons: HBoxContainer


func _ready() -> void:
	# Allow running this scene directly (F6 / screenshot tool) without a run.
	if not RunState.active:
		RunState.start_new_run()

	_build_ui()

	battle = BattleManager.new()
	add_child(battle)
	battle.stats_changed.connect(_refresh)
	battle.potion_activated.connect(_on_potion_activated)
	battle.combo_triggered.connect(_on_combo_triggered)
	battle.enemy_damaged.connect(_on_enemy_damaged)
	battle.enemy_attacked.connect(_on_enemy_attacked)
	battle.enemy_enraged.connect(_on_enemy_enraged)
	battle.poison_ticked.connect(_on_poison_ticked)
	battle.player_poison_ticked.connect(_on_player_poison_ticked)
	battle.tube_lock_requested.connect(_on_tube_lock_requested)
	battle.battle_won.connect(_on_battle_won)
	battle.battle_lost.connect(_on_battle_lost)

	board.move_made.connect(battle.on_move)
	board.tube_completed.connect(battle.on_potion_completed)
	board.board_refilled.connect(func() -> void: _set_message("New potions brewed!"))

	var entry := RunState.current_battle()
	battle.setup(str(entry.get("enemy", "slime")))
	enemy_display.configure(battle.enemy_shape, battle.enemy_color)
	undo_left = battle.undos_allowed()
	_set_message("Sort potions of one color to unleash them!")
	_refresh()


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 44)   # notch safe zone
	margin.add_theme_constant_override("margin_bottom", 36)  # nav bar safe zone
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(_build_enemy_panel())
	root.add_child(_build_player_panel())

	message_label = UiKit.label("", 23, UiKit.COLOR_GOLD)
	message_label.custom_minimum_size = Vector2(0, 34)
	root.add_child(message_label)

	board = PuzzleBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board)

	root.add_child(_build_button_row())
	_build_overlay()


func _build_enemy_panel() -> PanelContainer:
	var panel := UiKit.panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	battle_kind_label = UiKit.label("", 18, UiKit.COLOR_TEXT_DIM)
	box.add_child(battle_kind_label)

	enemy_name_label = UiKit.title_label("", 32)
	box.add_child(enemy_name_label)

	enemy_display = EnemyDisplay.new()
	enemy_display.custom_minimum_size = Vector2(0, 160)
	box.add_child(enemy_display)

	enemy_hp_bar = UiKit.bar(UiKit.COLOR_ENEMY_HP)
	box.add_child(enemy_hp_bar)
	enemy_hp_label = UiKit.bar_label(enemy_hp_bar)

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 18)
	box.add_child(status_row)
	armor_label = UiKit.label("", 20, Color("c8c2b8"))
	status_row.add_child(armor_label)
	poison_label = UiKit.label("", 20, UiKit.COLOR_POISON)
	status_row.add_child(poison_label)

	countdown_label = UiKit.label("", 25, UiKit.COLOR_FIRE)
	box.add_child(countdown_label)
	return panel


func _build_player_panel() -> PanelContainer:
	var panel := UiKit.panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var hp_box := VBoxContainer.new()
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_box.add_theme_constant_override("separation", 4)
	row.add_child(hp_box)

	var hp_title := UiKit.label("Your HP", 18, UiKit.COLOR_TEXT_DIM)
	hp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_box.add_child(hp_title)

	player_hp_bar = UiKit.bar(UiKit.COLOR_HP)
	hp_box.add_child(player_hp_bar)
	player_hp_label = UiKit.bar_label(player_hp_bar)

	player_status_label = UiKit.label("", 18, UiKit.COLOR_POISON)
	player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_box.add_child(player_status_label)

	shield_label = UiKit.label("", 24, UiKit.COLOR_SHIELD)
	shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(shield_label)
	return panel


func _build_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)

	undo_button = UiKit.button("Undo", Vector2(200, 62))
	undo_button.pressed.connect(_on_undo_pressed)
	row.add_child(undo_button)

	var restart := UiKit.button("New Mix", Vector2(200, 62))
	restart.pressed.connect(_on_restart_pressed)
	row.add_child(restart)

	var pause := UiKit.button("Pause", Vector2(200, 62))
	pause.pressed.connect(_show_pause)
	row.add_child(pause)
	return row


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 100
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks input to the board
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := UiKit.panel(UiKit.COLOR_GOLD_DIM)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	overlay_title = UiKit.title_label("", 46)
	box.add_child(overlay_title)

	overlay_body = UiKit.label("", 23)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_body)

	overlay_choices = VBoxContainer.new()
	overlay_choices.add_theme_constant_override("separation", 12)
	box.add_child(overlay_choices)

	overlay_buttons = HBoxContainer.new()
	overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_buttons.add_theme_constant_override("separation", 18)
	box.add_child(overlay_buttons)


# --- Rendering --------------------------------------------------------------

func _refresh() -> void:
	var entry := RunState.current_battle()
	var kind := str(entry.get("kind", "battle"))
	var stage := "%s — Battle %d / %d" % [
		str(RunState.run_config.get("area_name", "Dungeon")),
		RunState.battle_index + 1, RunState.battles().size()]
	match kind:
		"elite": stage += "  [ELITE]"
		"boss": stage += "  [BOSS]"
	battle_kind_label.text = stage

	enemy_name_label.text = battle.enemy_name \
			+ ("  (Enraged!)" if battle.enraged else "")
	enemy_hp_bar.max_value = battle.enemy_max_hp
	enemy_hp_bar.value = battle.enemy_hp
	enemy_hp_label.text = "%d / %d" % [battle.enemy_hp, battle.enemy_max_hp]
	enemy_display.enraged = battle.enraged

	armor_label.text = "Armor %d" % battle.enemy_armor if battle.enemy_armor > 0 else ""
	poison_label.text = ("Poison %d dmg / %d turns"
			% [battle.poison_damage, battle.poison_turns]) \
			if battle.poison_turns > 0 else ""

	var moves := battle.moves_until_attack
	countdown_label.text = "Enemy attacks in %d move%s!" \
			% [moves, "" if moves == 1 else "s"]
	countdown_label.add_theme_color_override("font_color",
			Color("ff5a3a") if moves <= 1 else UiKit.COLOR_FIRE)

	player_hp_bar.max_value = battle.player_max_hp
	player_hp_bar.value = battle.player_hp
	player_hp_label.text = "%d / %d" % [battle.player_hp, battle.player_max_hp]
	shield_label.text = "Shield %d" % battle.shield if battle.shield > 0 else "No Shield"
	player_status_label.text = ("Poisoned! %d dmg / %d turns"
			% [battle.player_poison_damage, battle.player_poison_turns]) \
			if battle.player_poison_turns > 0 else ""

	undo_button.text = "Undo (%d)" % undo_left
	undo_button.disabled = undo_left <= 0 or not board.can_undo() or battle.battle_over


func _set_message(text: String) -> void:
	message_label.text = text


func _enemy_center() -> Vector2:
	return enemy_display.global_position + enemy_display.size / 2.0


func _player_bar_center() -> Vector2:
	return player_hp_bar.global_position + player_hp_bar.size / 2.0


# --- Game events ------------------------------------------------------------

func _on_potion_activated(color: String, text: String) -> void:
	_set_message(text)
	match color:
		"green":
			UiKit.float_text(self, _player_bar_center(), text.get_slice("  ", 1),
					UiKit.COLOR_HP)
		"blue":
			UiKit.float_text(self, _player_bar_center(), text.get_slice("  ", 1),
					UiKit.COLOR_SHIELD)


func _on_enemy_damaged(amount: int) -> void:
	enemy_display.play_hit()
	UiKit.float_text(self, _enemy_center() + Vector2(randf_range(-40, 40), -20),
			"-%d" % amount, UiKit.COLOR_FIRE, 40)


func _on_combo_triggered(text: String) -> void:
	_set_message(text)
	UiKit.float_text(self, _enemy_center() + Vector2(-80, 60), text,
			UiKit.COLOR_GOLD, 28)


func _on_enemy_attacked(damage: int, blocked: int, crit: bool) -> void:
	var prefix := "CRITICAL! " if crit else ""
	if blocked >= damage:
		_set_message("%s%s attacks! Shield blocks everything." % [prefix, battle.enemy_name])
	elif blocked > 0:
		_set_message("%s%s attacks! Shield blocks %d, you take %d."
				% [prefix, battle.enemy_name, blocked, damage - blocked])
	else:
		_set_message("%s%s attacks for %d damage!" % [prefix, battle.enemy_name, damage])
	if damage > blocked:
		UiKit.float_text(self, _player_bar_center(), "-%d" % (damage - blocked),
				UiKit.COLOR_ENEMY_HP, 36)


func _on_enemy_enraged() -> void:
	_set_message("%s is ENRAGED!" % battle.enemy_name)
	UiKit.float_text(self, _enemy_center(), "ENRAGED!", Color("ff3a2a"), 44)


func _on_poison_ticked(damage: int) -> void:
	_set_message("Poison deals %d damage!" % damage)


func _on_player_poison_ticked(damage: int) -> void:
	if damage > 0:
		UiKit.float_text(self, _player_bar_center(), "-%d poison" % damage,
				UiKit.COLOR_POISON, 30)
	else:
		_set_message("You are poisoned!")


func _on_tube_lock_requested(moves: int) -> void:
	board.lock_random_tube(moves)
	_set_message("%s seals a tube for %d moves!" % [battle.enemy_name, moves])


# --- Run flow ----------------------------------------------------------------

func _on_battle_won() -> void:
	board.enabled = false
	var was_last := RunState.is_last_battle()
	RunState.complete_battle(battle.player_hp, battle.crystals_reward)
	if was_last:
		_show_overlay("Boss Defeated!",
				"You conquered the %s!\nCrystals earned this run: %d\nTotal crystals: %d"
				% [str(RunState.run_config.get("area_name", "dungeon")),
					RunState.run_crystals, SaveSystem.crystals()],
				[["Main Menu", _go_to_menu]])
	else:
		_show_upgrade_choice()


func _show_upgrade_choice() -> void:
	var choices := RunState.roll_upgrade_choices()
	var body := "+%d crystals\nChoose an upgrade:" % battle.crystals_reward
	_show_overlay("Victory!", body, [])
	for id in choices:
		var card := UiKit.button("%s\n%s" % [RunState.upgrade_name(id),
				RunState.upgrade_description(id)], Vector2(520, 84))
		card.pressed.connect(_on_upgrade_picked.bind(str(id)))
		overlay_choices.add_child(card)


func _on_upgrade_picked(id: String) -> void:
	RunState.pick_upgrade(id)
	# Instant-effect extras carried by some upgrades (e.g. Vital Tonic).
	var heal_now := int(RunState.upgrade_pool.get(id, {}).get("heal_now", 0))
	if heal_now > 0:
		RunState.player_hp = mini(RunState.player_hp + heal_now,
				int(RunState.stat("max_hp", float(GameState.player.get("max_hp", 50)))))
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _on_battle_lost() -> void:
	board.enabled = false
	var kept := RunState.fail_run()
	_show_overlay("Defeated...",
			"You fell in battle %d of %d.\nCrystals kept: %d\nTotal crystals: %d"
			% [RunState.battle_index + 1, RunState.battles().size(),
				kept, SaveSystem.crystals()],
			[["New Run", _start_new_run], ["Main Menu", _go_to_menu]])


func _show_pause() -> void:
	if battle.battle_over:
		return
	board.enabled = false
	_show_overlay("Paused", "", [
		["Resume", _hide_overlay],
		["Abandon Run", _go_to_menu],
	])


## buttons: Array of [text, Callable] pairs.
func _show_overlay(title: String, body: String, buttons: Array) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_body.visible = body != ""
	for child in overlay_choices.get_children():
		child.queue_free()
	for child in overlay_buttons.get_children():
		child.queue_free()
	for entry in buttons:
		var button := UiKit.button(entry[0], Vector2(220, 64))
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


func _start_new_run() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
