extends Control
## Battle screen: wires PuzzleBoard <-> BattleManager, renders the fight and
## handles the run flow (victory -> upgrade choice -> map, boss win -> run
## victory, defeat -> game over). All UI built via UiKit (placeholder-art phase).

var battle: BattleManager
var board: PuzzleBoard
var undo_left := 0
var _last_moves_until_attack := -1

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
var undo_count_label: Label
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_choices: VBoxContainer
var overlay_buttons: HBoxContainer
var battle_fx: BattleFx
var _layout_profile: Dictionary


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
	battle.last_remedy_triggered.connect(_on_last_remedy)
	battle.battle_won.connect(_on_battle_won)
	battle.battle_lost.connect(_on_battle_lost)

	board.move_made.connect(battle.on_move)
	board.move_made.connect(func() -> void: AudioManager.play("pour"))
	board.pour_presented.connect(_on_pour_presented)
	board.tube_completed.connect(battle.on_potion_completed)
	board.tube_completed.connect(func(_c: String) -> void: AudioManager.play("complete"))
	board.tube_locked.connect(func() -> void: AudioManager.play("lock"))
	board.board_refilled.connect(func() -> void: _set_message("New potions brewed!"))

	var entry := RunState.current_battle()
	battle.setup(str(entry.get("enemy", "slime")))
	enemy_display.configure_enemy(str(entry.get("enemy", "slime")),
			battle.enemy_shape, battle.enemy_color)
	enemy_display.play_intro()
	undo_left = battle.undos_allowed()
	_set_message("Sort potions of one color to unleash them!")

	AudioManager.play_music("boss" if RunState.is_boss_battle() else "dungeon")
	if not SaveSystem.is_tutorial_done() and RunState.battle_index == 0:
		board.generate_tutorial_board()
		var tutorial := Tutorial.new()
		tutorial.setup(board, battle)
		_insert_above_board(tutorial)
	_refresh()


## Places a control directly above the puzzle board in the main column.
func _insert_above_board(control: Control) -> void:
	var parent := board.get_parent()
	parent.add_child(control)
	parent.move_child(control, board.get_index())


# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self,
			"res://assets/art/backgrounds/shadow_crypt_battle.png")
	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.015, 0.012, 0.025, 0.18)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	_layout_profile = UiKit.layout_profile(get_viewport_rect().size)
	var margin := UiKit.safe_margin(self,
			int(_layout_profile.get("safe_horizontal", 18)),
			int(_layout_profile.get("safe_top", 30)),
			int(_layout_profile.get("safe_bottom", 24)))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	root.add_child(_build_top_strip())
	var enemy_panel := _build_enemy_panel()
	enemy_panel.name = "ArenaBand"
	root.add_child(enemy_panel)
	var player_panel := _build_player_panel()
	player_panel.name = "StatusBand"
	root.add_child(player_panel)
	root.add_child(_build_turn_banner())

	message_label = UiKit.label("", 20, UiKit.COLOR_GOLD)
	message_label.custom_minimum_size = Vector2(0, 28)
	message_label.add_theme_constant_override("outline_size", 5)
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	root.add_child(message_label)

	board = PuzzleBoard.new()
	board.name = "PotionBoardBand"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board)
	board.apply_layout_profile(_layout_profile)

	var controls := _build_button_row()
	controls.name = "ControlsBand"
	root.add_child(controls)
	battle_fx = BattleFx.new()
	add_child(battle_fx)
	battle_fx.set_reduced_effects(bool(ProjectSettings.get_setting(
			"potion_rogue/reduced_effects", false)))
	_build_overlay()


func _build_top_strip() -> PanelContainer:
	var panel := UiKit.panel(Color("7d6030"))
	panel.custom_minimum_size = Vector2(0, 50)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	battle_kind_label = UiKit.label("", 17, UiKit.COLOR_TEXT)
	battle_kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	battle_kind_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(battle_kind_label)
	var currency := UiKit.label("◆  %d" % SaveSystem.crystals(), 20, Color("72cfff"))
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(currency)
	return panel


func _build_enemy_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	enemy_name_label = UiKit.title_label("", 34)
	enemy_name_label.custom_minimum_size = Vector2(0, 42)
	box.add_child(enemy_name_label)

	enemy_hp_bar = UiKit.bar(UiKit.COLOR_ENEMY_HP, 30.0)
	box.add_child(enemy_hp_bar)
	enemy_hp_label = UiKit.bar_label(enemy_hp_bar)

	enemy_display = EnemyDisplay.new()
	enemy_display.custom_minimum_size = Vector2(0, 300 if _layout_profile.get("name") == "tall" else 330)
	enemy_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(enemy_display)

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 18)
	box.add_child(status_row)
	armor_label = UiKit.label("", 18, Color("d8d0bd"))
	status_row.add_child(armor_label)
	poison_label = UiKit.label("", 18, UiKit.COLOR_POISON)
	status_row.add_child(poison_label)

	countdown_label = UiKit.label("", 22, UiKit.COLOR_FIRE)
	countdown_label.custom_minimum_size = Vector2(0, 28)
	countdown_label.add_theme_constant_override("outline_size", 5)
	countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	box.add_child(countdown_label)
	return box


func _build_player_panel() -> PanelContainer:
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 14)
	panel.custom_minimum_size = Vector2(0, 68)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var hp_box := VBoxContainer.new()
	hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_box.add_theme_constant_override("separation", 4)
	row.add_child(hp_box)

	var hp_title := UiKit.label("Your HP", 15, UiKit.COLOR_TEXT_DIM)
	hp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_box.add_child(hp_title)

	player_hp_bar = UiKit.bar(UiKit.COLOR_HP, 26.0)
	hp_box.add_child(player_hp_bar)
	player_hp_label = UiKit.bar_label(player_hp_bar)

	player_status_label = UiKit.label("", 15, UiKit.COLOR_POISON)
	player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_box.add_child(player_status_label)

	shield_label = UiKit.label("", 20, UiKit.COLOR_SHIELD)
	shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(shield_label)
	return panel


func _build_turn_banner() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 58)
	var texture := TextureRect.new()
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.texture = VisualRegistry.texture_or_null("res://assets/art/ui/banner_turn.png")
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(texture)
	var label := UiKit.title_label("YOUR TURN", 28, Color("f5d681"))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(label)
	return holder


func _build_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, 106)
	row.add_theme_constant_override("separation", 42)

	undo_button = UiKit.icon_button(VisualRegistry.ui_icon("undo"), -1,
			"Undo the last pour")
	undo_count_label = UiKit.label("3", 18, Color("f5d681"))
	undo_count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	undo_count_label.offset_left = -30
	undo_count_label.offset_top = -30
	undo_count_label.offset_right = -4
	undo_count_label.offset_bottom = -4
	undo_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	undo_count_label.add_theme_constant_override("outline_size", 4)
	undo_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	undo_button.add_child(undo_count_label)
	undo_button.pressed.connect(_on_undo_pressed)
	row.add_child(_action_stack(undo_button, "Undo"))

	var restart := UiKit.icon_button(VisualRegistry.ui_icon("mix"), -1,
			"Brew a new potion mix")
	restart.pressed.connect(_on_restart_pressed)
	row.add_child(_action_stack(restart, "New Mix"))

	var pause := UiKit.icon_button(VisualRegistry.ui_icon("pause"), -1,
			"Pause the battle")
	pause.pressed.connect(_show_pause)
	row.add_child(_action_stack(pause, "Pause"))
	return row


func _action_stack(button: Button, caption: String) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -4)
	stack.add_child(button)
	var label := UiKit.label(caption, 15, UiKit.COLOR_GOLD)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	stack.add_child(label)
	return stack


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

	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 30)
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
	_animate_bar(enemy_hp_bar, battle.enemy_hp)
	enemy_hp_label.text = "%d / %d" % [battle.enemy_hp, battle.enemy_max_hp]
	enemy_display.enraged = battle.enraged

	armor_label.text = "Armor %d" % battle.enemy_armor if battle.enemy_armor > 0 else ""
	poison_label.text = ("Poison %d dmg / %d turns"
			% [battle.poison_damage, battle.poison_turns]) \
			if battle.poison_turns > 0 else ""

	var moves := battle.moves_until_attack
	if moves == 1 and _last_moves_until_attack != 1:
		enemy_display.play_anticipate()
	_last_moves_until_attack = moves
	countdown_label.text = "Enemy attacks in %d move%s!" \
			% [moves, "" if moves == 1 else "s"]
	countdown_label.add_theme_color_override("font_color",
			Color("ff5a3a") if moves <= 1 else UiKit.COLOR_FIRE)

	player_hp_bar.max_value = battle.player_max_hp
	_animate_bar(player_hp_bar, battle.player_hp)
	player_hp_label.text = "%d / %d" % [battle.player_hp, battle.player_max_hp]
	shield_label.text = "Shield %d" % battle.shield if battle.shield > 0 else "No Shield"
	player_status_label.text = ("Poisoned! %d dmg / %d turns"
			% [battle.player_poison_damage, battle.player_poison_turns]) \
			if battle.player_poison_turns > 0 else ""

	undo_count_label.text = str(undo_left)
	undo_button.disabled = undo_left <= 0 or not board.can_undo() or battle.battle_over


func _set_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 0.45
	var tween := create_tween()
	tween.tween_property(message_label, "modulate:a", 1.0, 0.16)


func _animate_bar(bar: ProgressBar, target: float) -> void:
	if not is_instance_valid(bar):
		return
	var tween := create_tween()
	tween.tween_property(bar, "value", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _enemy_center() -> Vector2:
	return enemy_display.global_position + enemy_display.size / 2.0


func _player_bar_center() -> Vector2:
	return player_hp_bar.global_position + player_hp_bar.size / 2.0


# --- Game events ------------------------------------------------------------

func _on_potion_activated(color: String, text: String) -> void:
	_set_message(text)
	AudioManager.vibrate(25)
	match color:
		"red":
			AudioManager.play("fire")
			battle_fx.projectile(_player_bar_center(), _enemy_center(), Color("ff8a42"))
		"green":
			AudioManager.play("heal")
			battle_fx.heal(_player_bar_center())
			UiKit.float_text(self, _player_bar_center(), text.get_slice("  ", 1),
					UiKit.COLOR_HP)
		"blue":
			AudioManager.play("shield")
			battle_fx.shield(_player_bar_center())
			UiKit.float_text(self, _player_bar_center(), text.get_slice("  ", 1),
					UiKit.COLOR_SHIELD)
		"purple":
			AudioManager.play("poison")
			battle_fx.poison(_enemy_center())


func _on_pour_presented(from: Vector2, to: Vector2, color: String, count: int) -> void:
	var style := VisualRegistry.potion(color)
	battle_fx.pour(from, to, style.get("glow", Color.WHITE), count)


func _on_enemy_damaged(amount: int) -> void:
	enemy_display.play_hit()
	battle_fx.hit(enemy_display, 1.0)
	AudioManager.play("enemy_hit")
	UiKit.float_text(self, _enemy_center() + Vector2(randf_range(-40, 40), -20),
			"-%d" % amount, UiKit.COLOR_FIRE, 40)


func _on_combo_triggered(text: String) -> void:
	_set_message(text)
	UiKit.float_text(self, _enemy_center() + Vector2(-80, 60), text,
			UiKit.COLOR_GOLD, 28)


func _on_enemy_attacked(damage: int, blocked: int, crit: bool) -> void:
	enemy_display.play_attack()
	battle_fx.enemy_strike(_enemy_center(), _player_bar_center())
	var prefix := "CRITICAL! " if crit else ""
	if blocked >= damage:
		_set_message("%s%s attacks! Shield blocks everything." % [prefix, battle.enemy_name])
	elif blocked > 0:
		_set_message("%s%s attacks! Shield blocks %d, you take %d."
				% [prefix, battle.enemy_name, blocked, damage - blocked])
	else:
		_set_message("%s%s attacks for %d damage!" % [prefix, battle.enemy_name, damage])
	if damage > blocked:
		AudioManager.play("player_hit")
		AudioManager.vibrate(60)
		UiKit.float_text(self, _player_bar_center(), "-%d" % (damage - blocked),
				UiKit.COLOR_ENEMY_HP, 36)
	else:
		AudioManager.play("shield")


func _on_last_remedy(heal: int) -> void:
	AudioManager.play("heal")
	_set_message("Last Remedy saves you! +%d HP" % heal)
	UiKit.float_text(self, _player_bar_center(), "+%d Last Remedy" % heal,
			UiKit.COLOR_HP, 30)


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
	enemy_display.play_defeat()
	AudioManager.play("victory")
	AudioManager.stop_music()
	var was_last := RunState.is_last_battle()
	var was_elite := str(RunState.current_battle().get("kind", "battle")) == "elite"
	RunState.complete_battle(battle.player_hp, battle.crystals_reward)
	if was_last:
		_show_overlay("Boss Defeated!",
				"You conquered the %s!\nCrystals earned this run: %d\nTotal crystals: %d"
				% [str(RunState.run_config.get("area_name", "dungeon")),
					RunState.run_crystals, SaveSystem.crystals()],
				[["Main Menu", _go_to_menu]])
	elif was_elite:
		_show_relic_choice()
	else:
		_show_upgrade_choice()


func _show_upgrade_choice() -> void:
	var choices := RunState.roll_upgrade_choices()
	var body := "+%d crystals\nChoose an upgrade:" % battle.crystals_reward
	_show_overlay("Victory!", body, [])
	for id in choices:
		var card := UiKit.ornate_button("%s\n%s" % [RunState.upgrade_name(id),
				RunState.upgrade_description(id)], Vector2(520, 84))
		card.pressed.connect(_on_upgrade_picked.bind(str(id)))
		overlay_choices.add_child(card)


func _show_relic_choice() -> void:
	var choices := RunState.roll_relic_choices()
	if choices.is_empty():
		_show_upgrade_choice()
		return
	var body := "+%d crystals\nThe elite guarded a relic. Claim one:" \
			% battle.crystals_reward
	_show_overlay("Elite Vanquished!", body, [])
	for id in choices:
		var card := UiKit.ornate_button("%s\n%s" % [RunState.relic_name(id),
				RunState.relic_description(id)], Vector2(520, 84), Color("c07ce8"))
		card.pressed.connect(_on_relic_picked.bind(str(id)))
		overlay_choices.add_child(card)


func _on_relic_picked(id: String) -> void:
	RunState.pick_relic(id)
	get_tree().change_scene_to_file("res://scenes/map.tscn")


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
	AudioManager.play("defeat")
	AudioManager.stop_music()
	AudioManager.vibrate(120)
	var kept := RunState.fail_run()
	_show_overlay("Defeated...",
			"You fell in battle %d of %d.\nEnemies defeated: %d\nCrystals kept: %d\nTotal crystals: %d"
			% [RunState.battle_index + 1, RunState.battles().size(),
				RunState.battle_index, kept, SaveSystem.crystals()],
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
		var button := UiKit.ornate_button(entry[0], Vector2(220, 64))
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
