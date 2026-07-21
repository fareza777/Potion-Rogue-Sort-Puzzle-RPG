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
var enemy_hp_bar: OrnateResourceBar
var armor_label: Label
var poison_label: Label
var countdown_label: Label
var warning_plaque: PanelContainer
var player_hp_bar: OrnateResourceBar
var player_status_label: Label
var message_label: Label
var undo_button: Button
var undo_count_label: Label
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_choices: VBoxContainer
var overlay_buttons: VBoxContainer
var battle_fx: BattleFx
var _layout_profile: Dictionary
var objective_controller: ObjectiveController
var intent_controller: EnemyIntentController
var signature_controller: EnemySignatureController
var modifier_controller: ModifierController
var combo_resolver: ComboResolver
var reaction_effects := ReactionEffectExecutor.new()
var reaction_pipeline: ReactionModifierPipeline
var reaction_counterplay: ReactionCounterplayController
var skill_controller: SkillController
var objective_label: Label
var intent_label: Label
var tactical_readout: TacticalReadout
var mana_bar: ProgressBar
var mana_label: Label
var reaction_chamber: ReactionChamber
var skill_button: Button
var ultimate_button: Button
var boss_phase_controller: BossPhaseController
var encounter_format := EncounterFormatController.new()
var presentation_director := BattlePresentationDirector.new()
var tutorial_director: TutorialDirector
var tutorial_overlay: Tutorial
var encounter_coordinator := EncounterCoordinator.new()
var hud_presenter := BattleHudPresenter.new()
var overlay_controller := BattleOverlayController.new()
var battle_navigation := BattleNavigation.new()
var remix_jobs := RemixJobController.new()
var remix_economy := RemixEconomy.new()
var _pending_remix_generation := -1
var _pending_remix_snapshot: Dictionary = {}
var _pending_remix_seed := 0
var _pending_remix_quote: Dictionary = {}


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay != null and overlay.visible:
			_hide_overlay()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _pending_remix_generation < 0:
		return
	var payload := remix_jobs.poll()
	if payload.is_empty() or int(payload.get("generation_id", -1)) != _pending_remix_generation:
		return
	_pending_remix_generation = -1
	var applied := not payload.has("error") \
			and board.apply_remix_result(payload.get("result", {}))
	if not applied:
		board.restore_snapshot(_pending_remix_snapshot)
		_set_message("MIX FAILED — TRY AGAIN")
	else:
		var mana_cost := int(_pending_remix_quote.get("mana_cost", 0))
		if mana_cost > 0 and not skill_controller.spend_mana(mana_cost):
			board.restore_snapshot(_pending_remix_snapshot)
			board.enabled = true
			_set_message("NOT ENOUGH MANA — MIX CANCELLED")
			_pending_remix_snapshot = {}
			_pending_remix_quote = {}
			return
		remix_economy.commit(_pending_remix_quote)
		battle.on_move()
		RunState.record_replay("remix", {"seed":_pending_remix_seed,
				"generation_id":int(payload.get("generation_id", -1)),
				"board":board.export_state()})
		_set_message("Emergency recovery — 1 move spent" if bool(
				_pending_remix_quote.get("emergency", false)) else
				"Potions remixed — 1 move spent")
		_checkpoint_encounter()
	_pending_remix_snapshot = {}
	_pending_remix_quote = {}
	if not battle.battle_over:
		board.enabled = true
	_refresh()


func _exit_tree() -> void:
	remix_jobs.cancel()


func _ready() -> void:
	# Allow running this scene directly (F6 / screenshot tool) without a run.
	if not RunState.active:
		RunState.start_new_run()

	_build_ui()
	enemy_display.set_reduced_effects(bool(SaveSystem.setting("reduced_effects")))
	battle_navigation.configure(get_tree())
	hud_presenter.build(self, _layout_profile)
	hud_presenter.bind({"stage": battle_kind_label, "enemy_name": enemy_name_label,
		"countdown": countdown_label, "undo_count": undo_count_label})
	overlay_controller.configure(overlay, overlay_title, overlay_body,
			overlay_choices, overlay_buttons)

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
	encounter_coordinator.configure(battle, board, entry)
	_setup_tactical_controllers(str(entry.get("enemy", "slime")))
	var encounter: Dictionary = RunState.phase_payload.get("encounter", {})
	var resumed := not encounter.is_empty() and _restore_encounter(encounter)
	enemy_display.configure_enemy(str(entry.get("enemy", "slime")),
			battle.enemy_shape, battle.enemy_color)
	enemy_display.play_intro()
	undo_left = int(encounter.get("undo_left", battle.undos_allowed())) if resumed else battle.undos_allowed()
	_set_message("Battle resumed exactly where you left it." if resumed \
			else "Sort potions of one color to unleash them!")

	var combat_kind := str(entry.get("kind", "battle"))
	AudioManager.set_area(str(RunState.current_area().get("music", "dungeon")))
	AudioManager.set_combat_layer("boss_phase_1" if combat_kind == "boss" else "elite" if combat_kind == "elite" else "battle")
	if not resumed and not SaveSystem.is_tutorial_done() and RunState.battle_index == 0:
		board.generate_tutorial_board()
		tutorial_director = TutorialDirector.new(); tutorial_director.configure()
		tutorial_overlay = Tutorial.new(); add_child(tutorial_overlay)
		tutorial_overlay.setup(self, tutorial_director, _tutorial_target)
	board.move_made.connect(_checkpoint_encounter_deferred)
	# Replay stores the pour delta, not the whole board: full states balloon
	# every checkpoint write, and remix/undo events already anchor full boards.
	board.move_made.connect(func() -> void:
		RunState.record_replay("move", board.last_pour))
	board.tube_completed.connect(func(_color: String) -> void: _checkpoint_encounter_deferred())
	_checkpoint_encounter()
	_refresh()


func _capture_encounter() -> Dictionary:
	var result := encounter_coordinator.snapshot()
	result.merge({
		"undo_left": undo_left,
		"skill": skill_controller.snapshot(),
		"objective": objective_controller.snapshot(),
		"intent": intent_controller.snapshot(),
		"signature": signature_controller.snapshot(),
		"modifier": modifier_controller.snapshot(),
		"combo": combo_resolver.snapshot(),
		"reaction_pipeline": reaction_pipeline.snapshot(),
		"reaction_counterplay": reaction_counterplay.snapshot(),
		"remix_economy": remix_economy.snapshot(),
		"boss_phase": boss_phase_controller.snapshot() if boss_phase_controller != null else {},
		"encounter_format": encounter_format.snapshot(),
	}, true)
	return result


func _restore_encounter(snapshot: Dictionary) -> bool:
	if int(snapshot.get("version", 0)) != 1:
		return false
	var restored := encounter_coordinator.restore(snapshot)
	if not restored:
		return false
	skill_controller.restore(snapshot.get("skill", {}))
	objective_controller.restore(snapshot.get("objective", {}))
	intent_controller.restore(snapshot.get("intent", {}))
	signature_controller.restore(snapshot.get("signature", {}))
	modifier_controller.restore(snapshot.get("modifier", {}), board)
	combo_resolver.restore(snapshot.get("combo", {}))
	if not reaction_pipeline.restore(snapshot.get("reaction_pipeline", {})):
		reaction_pipeline.configure(RunState.kit_id, RunState.relic_ids,
				RunState.catalyst_ids, RunState.mutation_ids)
	remix_economy.restore(snapshot.get("remix_economy", {}))
	encounter_format.restore(snapshot.get("encounter_format", {}))
	if boss_phase_controller != null:
		var boss_data: Dictionary = snapshot.get("boss_phase", {})
		if not boss_phase_controller.restore(boss_data):
			boss_phase_controller.configure(battle.enemy_id, battle.enemy_max_hp,
					int(boss_data.get("phase_index", -1)),
					boss_data.get("applied_phase_actions", []))
	if not reaction_counterplay.restore(snapshot.get("reaction_counterplay", {})):
		_refresh_reaction_counterplay()
	return true


func _checkpoint_encounter_deferred() -> void:
	call_deferred("_checkpoint_encounter")


func _checkpoint_encounter() -> void:
	if battle != null and board != null and not battle.battle_over and RunState.active:
		RunState.request_checkpoint(RunState.PHASE_BATTLE, {"encounter": _capture_encounter()})


func _tutorial_target(target_name: String) -> Control:
	match target_name:
		"TutorialSource": return board.tubes[0] if board.tubes.size() > 0 else board
		"TutorialTarget": return board.tubes[1] if board.tubes.size() > 1 else board
		_: return find_child(target_name, true, false) as Control


func tutorial_fill_mana() -> void:
	if skill_controller != null: skill_controller.gain_mana(100)


func _tutorial_action(action: String) -> void:
	if tutorial_director != null and tutorial_director.active:
		tutorial_director.accept_action(action)


func _setup_tactical_controllers(enemy_id: String) -> void:
	var contract: Dictionary = RunState.current_contract()
	encounter_format.configure(contract.get("profile", {}))
	objective_controller = ObjectiveController.new()
	var objective_id := str(contract.get("objective_id", "defeat"))
	objective_controller.configure(objective_id, GameState.objectives.get(objective_id, {}))
	objective_controller.progress_changed.connect(_on_objective_progress)
	_on_objective_progress(objective_controller.current, objective_controller.target)
	objective_controller.completed.connect(func():
		_set_message("OPTIONAL OBJECTIVE COMPLETE  +15 mana")
		skill_controller.gain_mana(15))
	intent_controller = EnemyIntentController.new()
	intent_controller.configure(enemy_id, GameState.enemies.get(enemy_id, {}), RunState.run_seed + RunState.battle_index)
	intent_controller.set_battle_values(battle.enemy_attack, 0.0, battle.attack_every)
	battle.intent_controller = intent_controller
	battle.intent_board = board
	signature_controller = EnemySignatureController.new()
	signature_controller.configure(enemy_id, GameState.enemies.get(enemy_id, {}),
			RunState.run_seed + RunState.battle_index * 37 + 11)
	board.move_made.connect(_on_signature_move)
	if RunState.is_boss_battle():
		boss_phase_controller = BossPhaseController.new()
		boss_phase_controller.phase_changed.connect(_on_boss_phase_changed)
		boss_phase_controller.configure(enemy_id, battle.enemy_max_hp)
	reaction_counterplay = ReactionCounterplayController.new()
	_refresh_reaction_counterplay()
	modifier_controller = ModifierController.new()
	var modifier_ids: Array[String] = []
	for id in contract.get("modifier_ids", []): modifier_ids.append(str(id))
	modifier_controller.configure(modifier_ids, RunState.run_seed + 71, board)
	modifier_controller.curse_cleansed.connect(objective_controller.on_curse_cleansed)
	board.invalid_move.connect(func() -> void:
		var pressure := modifier_controller.on_invalid_pour()
		if pressure > 0:
			battle.moves_until_attack = maxi(battle.moves_until_attack - pressure, 1)
			_set_message("BRITTLE GLASS  •  ENEMY PRESSURE +1")
			_refresh())
	board.guidance_changed.connect(func(reason: String) -> void:
		AudioManager.haptic("invalid")
		_set_message(reason.to_upper()))
	combo_resolver = ComboResolver.new()
	combo_resolver.combo_resolved.connect(_on_depth_combo)
	reaction_pipeline = ReactionModifierPipeline.new()
	reaction_pipeline.configure(RunState.kit_id, RunState.relic_ids,
			RunState.catalyst_ids, RunState.mutation_ids)
	skill_controller = SkillController.new()
	skill_controller.configure(RunState.kit_id, board)
	skill_controller.mana_changed.connect(_on_mana_changed)
	board.move_made.connect(_on_tactical_move)
	board.tube_selected.connect(func(): _tutorial_action("select_source"))
	board.move_made.connect(func(): _tutorial_action("select_target"))
	board.tube_completed.connect(_on_depth_potion_completed)
	battle.enemy_action_resolved.connect(_on_intent_resolved)
	battle.enemy_action_resolved.connect(_on_format_enemy_action)
	battle.armor_changed.connect(func(delta: int) -> void:
		if delta < 0: objective_controller.on_armor_damaged(-delta))
	board.tube_completed.connect(_on_format_potion_completed)


func _on_format_enemy_action(_intent_id: String) -> void:
	var outcome := encounter_format.on_enemy_action()
	_set_message(encounter_format.title() + "  •  " + encounter_format.status_text())
	if outcome == "victory": battle.complete_by_objective()
	elif outcome == "defeat": battle.fail_by_objective()


func _on_format_potion_completed(_color: String) -> void:
	var outcome := encounter_format.on_potion_completed()
	if encounter_format.format == "protect_cauldron":
		_set_message(encounter_format.title() + "  •  " + encounter_format.status_text())
	if outcome == "victory": battle.complete_by_objective()


func _on_objective_progress(current: int, target: int) -> void:
	if objective_label != null:
		var payload := objective_controller.display_payload()
		var order: Array = payload.get("sequence", [])
		var order_text := ""
		if not order.is_empty():
			var steps: Array[String] = []
			for index in order.size():
				steps.append(("✓ " if index < current else "→ " if index == current else "· ")
						+ str(order[index]).to_upper())
			order_text = "  |  " + "  ".join(steps)
		objective_label.text = "OBJECTIVE  %s  %d/%d%s" % [objective_controller.label,
				current, target, order_text]
		if tactical_readout != null:
			tactical_readout.set_objective(objective_label.text)


func _on_tactical_move() -> void:
	modifier_controller.after_move()
	_refresh_tactical_hud()


func _on_signature_move() -> void:
	var payload := signature_controller.on_player_move(board)
	if not bool(payload.get("triggered", false)):
		return
	match str(payload.get("id", "")):
		"hunt":
			battle.moves_until_attack = maxi(battle.moves_until_attack
					- int(payload.get("pressure", 1)), 1)
		"siphon":
			skill_controller.mana = maxi(skill_controller.mana
					- int(payload.get("mana_loss", 0)), 0)
			skill_controller.mana_changed.emit(skill_controller.mana, 100)
		"corrupt":
			_mark_signature_layer(int(payload.get("target_tube", -1)), "cursed")
		"split":
			_mark_signature_layer(int(payload.get("target_tube", -1)), "volatile")
		"ward":
			battle.add_enemy_armor(2)
	_set_message(str(payload.get("warning", payload.get("label", "Enemy trick!"))))
	AudioManager.play("lock")
	_checkpoint_encounter_deferred()
	_refresh()


func _mark_signature_layer(tube_index: int, effect: String) -> void:
	if tube_index < 0 or tube_index >= board.tubes.size():
		return
	var tube := board.tubes[tube_index]
	if not tube.contents.is_empty():
		tube.add_layer_effect(tube.contents.size() - 1, effect)


func _on_depth_potion_completed(color: String) -> void:
	_tutorial_action("complete_potion")
	objective_controller.on_potion_completed(color)
	modifier_controller.on_potion_completed(color)
	skill_controller.gain_mana(18 if color == "wild" else 25)
	_tutorial_action("gain_mana")
	skill_controller.tick_cooldowns()
	var essence := reaction_pipeline.transform_essence(color)
	var result := combo_resolver.push_essence(essence, {"kit_id":RunState.kit_id})
	if not result.is_empty() and not battle.battle_over:
		result = reaction_pipeline.modify_result(result)
		_refresh_reaction_counterplay()
		result = reaction_counterplay.modify_reaction(result)
		var paid_hp := battle.spend_reaction_hp(int(result.get("hp_cost", 0)))
		var applied := reaction_effects.apply(result, battle)
		if bool(applied.get("ok", false)):
			var extra_heal := battle.restore_player_hp(int(result.get("bonus_heal", 0)))
			var extra_shield := battle.grant_player_shield(int(result.get("bonus_shield", 0)))
			battle.delay_enemy_attack(int(result.get("enemy_delay", 0)))
			skill_controller.gain_ultimate(int(result.get("charge", 0)))
			RunState.record_replay("reaction", {"id":result.id,
					"history":combo_resolver.history(), "result":applied})
			var first_discovery := SaveSystem.discover_formula(str(result.id))
			_set_message(str(result.get("name", result.id)) + " — "
					+ str(applied.get("summary", "Reaction resolved"))
					+ (" • +%d HP" % extra_heal if extra_heal > 0 else "")
					+ (" • +%d shield" % extra_shield if extra_shield > 0 else "")
					+ (" • %d HP cost" % paid_hp if paid_hp > 0 else ""))
			if first_discovery:
				overlay_controller.show_notice("NEW FORMULA DISCOVERED",
						str(result.get("name", result.id)),
						str(result.get("description", applied.get("summary", ""))))
	_refresh_tactical_hud()


func _on_depth_combo(combo_id: String, payload: Dictionary) -> void:
	battle_fx.play_combo(combo_resolver.history().size(), Color("c871ff"))
	if reaction_chamber != null:
		reaction_chamber.set_history(combo_resolver.history())
		reaction_chamber.play_activation(payload)
	_set_message(str(GameState.combos.get(combo_id, {}).get("name", combo_id.capitalize())))


func _on_intent_resolved(_id: String) -> void:
	objective_controller.on_enemy_attacked()
	modifier_controller.after_enemy_action()
	_refresh_tactical_hud()


func _on_mana_changed(_current: int, _maximum: int) -> void:
	_refresh_tactical_hud()


func _refresh_tactical_hud() -> void:
	if intent_controller == null or skill_controller == null or intent_label == null: return
	intent_controller.set_battle_values(battle.enemy_attack, 0.0, battle.moves_until_attack)
	var preview := intent_controller.preview()
	preview.moves = battle.moves_until_attack
	_refresh_reaction_counterplay()
	var counter := reaction_counterplay.preview()
	if not str(counter.get("counter_tag", "")).is_empty():
		preview.label = "%s  [COUNTER: %s]" % [str(preview.label),
				str(counter.counter_tag).to_upper()]
	var trick := signature_controller.preview() if signature_controller != null else {}
	if tactical_readout != null:
		tactical_readout.update_payload(objective_label.text, preview, trick)
	mana_bar.value = skill_controller.mana
	mana_label.text = "MANA  %d/100" % skill_controller.mana
	if reaction_chamber != null:
		reaction_chamber.set_history(combo_resolver.history())
	var kit: Dictionary = GameState.kits.get(RunState.kit_id, {})
	skill_button.text = str(kit.get("active", "skill")).replace("_", " ").to_upper()
	skill_button.disabled = not skill_controller.can_cast(str(kit.get("active", "")))
	ultimate_button.text = "ULT %d%%" % skill_controller.ultimate_charge()
	ultimate_button.disabled = not skill_controller.ultimate_ready()


func _refresh_reaction_counterplay() -> void:
	if reaction_counterplay == null or intent_controller == null: return
	var phase := boss_phase_controller.current_phase() if boss_phase_controller != null else {}
	reaction_counterplay.configure(intent_controller.preview(), phase)


func _on_skill_pressed() -> void:
	var kit: Dictionary = GameState.kits.get(RunState.kit_id, {})
	var skill_id := str(kit.get("active", "")); var target := {}
	if skill_id == "transmute":
		for index in board.tubes.size():
			if not board.tubes[index].contents.is_empty(): target = {"tube": index}; break
	var result := skill_controller.cast(skill_id, target)
	if not bool(result.get("ok", false)): return
	_tutorial_action("cast_skill")
	match skill_id:
		"flash_boil": battle.deal_skill_damage(16)
		"purify":
			battle.shield = mini(battle.max_shield, battle.shield + 12)
			RunState.cleanse_curse(1)
		"foresight":
			battle.shield = mini(battle.max_shield, battle.shield + 8)
		"blood_price":
			# Sacrifice fuel: the alchemist trades HP for burst damage.
			battle.player_hp = maxi(battle.player_hp - 4, 1)
			battle.deal_skill_damage(15)
	battle_fx.play_combo(2, Color("6edcff")); _set_message("ACTIVE SKILL — " + skill_id.replace("_", " ").to_upper())
	_checkpoint_encounter()
	_refresh()


func _on_ultimate_pressed() -> void:
	var result := skill_controller.cast_ultimate({"enemy_armor": battle.enemy_armor})
	if not bool(result.get("ok", false)): return
	battle_fx.play_ultimate(RunState.kit_id)
	battle_fx.impact_freeze(70)
	AudioManager.duck_music(0.42, 8.0)
	if int(result.get("break_armor", 0)) > 0:
		battle.break_enemy_armor(int(result.break_armor))
	if int(result.get("damage", 0)) > 0:
		battle.deal_skill_damage(int(result.damage))
	if int(result.get("heal", 0)) > 0:
		battle.player_hp = mini(battle.player_hp + int(result.heal), battle.player_max_hp)
	if int(result.get("shield", 0)) > 0:
		battle.shield = mini(battle.shield + int(result.shield), battle.max_shield)
	if int(result.get("cleanse", 0)) > 0:
		RunState.cleanse_curse(int(result.cleanse))
	if int(result.get("poison", 0)) > 0:
		battle.poison_damage = int(result.poison)
		battle.poison_turns = int(result.get("poison_turns", 3))
	if int(result.get("delay", 0)) > 0:
		battle.moves_until_attack += int(result.delay)
	if bool(result.get("wild_layer", false)):
		for index in board.tubes.size():
			if board.tubes[index].free_space() > 0:
				board.apply_board_command({"type":"append_layer", "tube":index, "color":"wild"})
				break
	_set_message(str(result.effect_id).replace("_", " ").to_upper() + " UNLEASHED!")
	_checkpoint_encounter()
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
			str(RunState.current_area().get("background",
			"res://assets/art/backgrounds/shadow_crypt_battle.png")))
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
	root.add_child(_build_tactical_hud())
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
	root.add_child(_build_power_strip())

	var controls := _build_button_row()
	controls.name = "ControlsBand"
	root.add_child(controls)
	battle_fx = BattleFx.new()
	add_child(battle_fx)
	battle_fx.set_reduced_effects(bool(SaveSystem.setting("reduced_effects")))
	_build_overlay()


func _build_top_strip() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "EncounterHeader"
	panel.custom_minimum_size = Vector2(0, 58)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.05, 0.94)
	style.border_color = Color("8e6c34")
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	style.content_margin_left = 16
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 7
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var stage_box := VBoxContainer.new()
	stage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_box.add_theme_constant_override("separation", -3)
	row.add_child(stage_box)
	var kicker := UiKit.label("DUNGEON EXPEDITION", 10, Color("a992c1"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_box.add_child(kicker)
	battle_kind_label = UiKit.label("", 15, UiKit.COLOR_TEXT)
	battle_kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_box.add_child(battle_kind_label)
	var currency := UiKit.label("◆  %d" % SaveSystem.crystals(), 19, Color("72cfff"))
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	currency.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	currency.custom_minimum_size = Vector2(78, 0)
	row.add_child(currency)
	return panel


func _build_enemy_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	enemy_name_label = UiKit.title_label("", 34)
	enemy_name_label.custom_minimum_size = Vector2(0, 42)
	box.add_child(enemy_name_label)

	enemy_hp_bar = OrnateResourceBar.new()
	enemy_hp_bar.name = "EnemyVitalBar"
	enemy_hp_bar.configure("enemy", "Enemy Vitality")
	box.add_child(enemy_hp_bar)

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

	warning_plaque = PanelContainer.new()
	warning_plaque.name = "WarningPlaque"
	warning_plaque.custom_minimum_size = Vector2(0, 38)
	var warning_style := StyleBoxFlat.new()
	warning_style.bg_color = Color(0.12, 0.035, 0.025, 0.76)
	warning_style.border_color = Color("87502d")
	warning_style.border_width_top = 1
	warning_style.border_width_bottom = 1
	warning_style.set_corner_radius_all(10)
	warning_plaque.add_theme_stylebox_override("panel", warning_style)
	countdown_label = UiKit.label("", 19, UiKit.COLOR_FIRE)
	countdown_label.add_theme_constant_override("outline_size", 5)
	countdown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	warning_plaque.add_child(countdown_label)
	box.add_child(warning_plaque)
	return box


func _build_player_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 66)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	player_hp_bar = OrnateResourceBar.new()
	player_hp_bar.name = "PlayerVitalBar"
	player_hp_bar.configure("player", "Adventurer Vitality")
	box.add_child(player_hp_bar)
	player_status_label = UiKit.label("", 13, UiKit.COLOR_POISON)
	player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(player_status_label)
	return panel


func _build_tactical_hud() -> PanelContainer:
	tactical_readout = TacticalReadout.new()
	tactical_readout.name = "TacticalReadout"
	tactical_readout.set_meta("legacy_name", "ObjectivePanel")
	tactical_readout._ready()
	objective_label = tactical_readout.objective_label
	intent_label = tactical_readout.intent_label
	return tactical_readout


func _build_power_strip() -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(0, 66)
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.025, 0.012, 0.045, 0.94)
	style.border_color = Color("795c31"); style.set_border_width_all(1); style.set_corner_radius_all(12)
	style.content_margin_left = 10; style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8); panel.add_child(row)
	var mana_stack := VBoxContainer.new(); mana_stack.custom_minimum_size = Vector2(145, 54)
	mana_label = UiKit.label("MANA 0/100", 13, Color("73d9ff")); mana_stack.add_child(mana_label)
	mana_bar = UiKit.bar(Color("368ed8"), 18); mana_bar.name = "ManaMeter"; mana_bar.max_value = 100
	mana_stack.add_child(mana_bar); row.add_child(mana_stack)
	reaction_chamber = ReactionChamber.new(); reaction_chamber.name = "ComboSlots"
	reaction_chamber.codex_requested.connect(_on_reaction_codex_requested)
	row.add_child(reaction_chamber)
	skill_button = UiKit.button("SKILL", Vector2(112, 50), Color("70d9ff")); skill_button.name = "SkillButton"
	skill_button.add_theme_font_size_override("font_size", 14); skill_button.pressed.connect(_on_skill_pressed); row.add_child(skill_button)
	ultimate_button = UiKit.button("ULT", Vector2(88, 50), Color("ffb84d")); ultimate_button.name = "UltimateButton"
	ultimate_button.add_theme_font_size_override("font_size", 14); ultimate_button.pressed.connect(_on_ultimate_pressed); row.add_child(ultimate_button)
	return panel


func _on_reaction_codex_requested() -> void:
	_checkpoint_encounter()
	get_tree().change_scene_to_file("res://scenes/reaction_codex.tscn")


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

	undo_button = ActionIconButton.new().configure("undo", "Undo", "Undo the last pour")
	undo_button.name = "UndoAction"
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

	var restart := ActionIconButton.new().configure("mix", "New Mix",
			"Brew a new potion mix — costs 1 move")
	restart.pressed.connect(_on_restart_pressed)
	row.add_child(_action_stack(restart, "New Mix\n1 Move"))

	var pause := ActionIconButton.new().configure("pause", "Pause", "Pause the battle")
	pause.pressed.connect(_show_pause)
	row.add_child(_action_stack(pause, "Pause"))
	return row


func _action_stack(button: Button, caption: String) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -4)
	var pedestal := PanelContainer.new()
	pedestal.name = "ActionPedestal"
	pedestal.custom_minimum_size = Vector2(96, 96)
	var pedestal_style := StyleBoxFlat.new()
	pedestal_style.bg_color = Color(0.01, 0.008, 0.02, 0.24)
	pedestal_style.set_corner_radius_all(48)
	pedestal_style.shadow_color = Color(0.23, 0.07, 0.32, 0.28)
	pedestal_style.shadow_size = 4
	pedestal.add_theme_stylebox_override("panel", pedestal_style)
	pedestal.add_child(button)
	stack.add_child(pedestal)
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
	var viewport_width := get_viewport_rect().size.x
	panel.custom_minimum_size = Vector2(minf(560.0, maxf(320.0, viewport_width - 32.0)), 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	overlay_title = UiKit.title_label("", 46)
	overlay_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_title)

	overlay_body = UiKit.label("", 23)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_body)

	overlay_choices = VBoxContainer.new()
	overlay_choices.add_theme_constant_override("separation", 12)
	box.add_child(overlay_choices)

	overlay_buttons = VBoxContainer.new()
	overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_buttons.add_theme_constant_override("separation", 10)
	box.add_child(overlay_buttons)


# --- Rendering --------------------------------------------------------------

func _refresh() -> void:
	var entry := RunState.current_battle()
	var kind := str(entry.get("kind", "battle"))
	var stage := "%s — Battle %d / %d" % [
		str(RunState.current_area().get("name", "Dungeon")),
		RunState.battle_index + 1, RunState.battles().size()]
	match kind:
		"elite": stage += "  [ELITE]"
		"boss": stage += "  [BOSS]"
	battle_kind_label.text = stage

	enemy_name_label.text = battle.enemy_name \
			+ ("  (Enraged!)" if battle.enraged else "")
	enemy_hp_bar.set_values(battle.enemy_hp, battle.enemy_max_hp)
	enemy_display.enraged = battle.enraged

	armor_label.text = "Armor %d" % battle.enemy_armor if battle.enemy_armor > 0 else ""
	poison_label.text = ("Poison %d dmg / %d turns"
			% [battle.poison_damage, battle.poison_turns]) \
			if battle.poison_turns > 0 else ""

	var moves := battle.moves_until_attack
	AudioManager.set_combat_intensity(float(battle.player_hp) / float(maxi(battle.player_max_hp, 1)), moves)
	if moves == 1 and _last_moves_until_attack != 1:
		enemy_display.play_anticipate()
		battle_fx.warning_pulse(warning_plaque)
	_last_moves_until_attack = moves
	countdown_label.text = "Enemy attacks in %d move%s!" \
			% [moves, "" if moves == 1 else "s"]
	countdown_label.add_theme_color_override("font_color",
			Color("ff5a3a") if moves <= 1 else UiKit.COLOR_FIRE)

	player_hp_bar.set_values(battle.player_hp, battle.player_max_hp)
	player_hp_bar.set_badge("SHIELD %d" % battle.shield if battle.shield > 0 else "NO SHIELD")
	player_status_label.text = ("Poisoned! %d dmg / %d turns"
			% [battle.player_poison_damage, battle.player_poison_turns]) \
			if battle.player_poison_turns > 0 else ""

	undo_count_label.text = str(undo_left)
	undo_button.disabled = undo_left <= 0 or not board.can_undo() or battle.battle_over
	_refresh_tactical_hud()
	hud_presenter.refresh({"stage": stage,
		"enemy_name": battle.enemy_name + ("  (Enraged!)" if battle.enraged else ""),
		"countdown": "Enemy attacks in %d move%s!" % [moves, "" if moves == 1 else "s"],
		"undo_count": undo_left})


func _set_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 0.45
	message_label.scale = Vector2(0.975, 0.975)
	message_label.pivot_offset = message_label.size * 0.5
	var tween := create_tween().set_parallel(true)
	var duration := presentation_director.duration("hit", bool(SaveSystem.setting("reduced_effects")))
	tween.tween_property(message_label, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(message_label, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _enemy_center() -> Vector2:
	return enemy_display.global_position + enemy_display.size / 2.0


func _player_bar_center() -> Vector2:
	return player_hp_bar.center_global()


# --- Game events ------------------------------------------------------------

func _on_potion_activated(color: String, text: String) -> void:
	_set_message(text)
	AudioManager.haptic("complete")
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
	AudioManager.haptic("pour")


func _on_enemy_damaged(amount: int) -> void:
	enemy_display.play_hit()
	battle_fx.hit(enemy_display, 1.0)
	AudioManager.play("enemy_hit")
	UiKit.float_text(self, _enemy_center() + Vector2(randf_range(-40, 40), -20),
			"-%d" % amount, UiKit.COLOR_FIRE, 40)
	if boss_phase_controller != null:
		boss_phase_controller.update_hp(battle.enemy_hp)


func _on_boss_phase_changed(index: int, config: Dictionary) -> void:
	board.enabled = false
	battle_fx.play_phase_transition(str(config.get("id", "phase")))
	battle_fx.impact_freeze(85)
	AudioManager.duck_music(0.65, 10.0)
	AudioManager.set_combat_layer("boss_phase_%d" % (index + 1))
	_set_message("PHASE %d — %s" % [index + 1, str(config.get("title", "INFERNO"))])
	if int(config.get("armor", 0)) > 0: battle.add_enemy_armor(int(config.armor))
	if int(config.get("attack_interval_delta", 0)) != 0:
		battle.attack_every = maxi(2, battle.attack_every + int(config.attack_interval_delta))
	if str(config.get("modifier", "")) != "":
		var ids: Array[String] = modifier_controller.active_ids.duplicate()
		ids.append(str(config.modifier)); modifier_controller.configure(ids, RunState.run_seed + index, board)
	if bool(config.get("release_chilled", false)):
		modifier_controller.release_permafrost()
	var board_action := boss_phase_controller.pending_board_action()
	if not board_action.is_empty():
		if not _apply_boss_board_action(board_action):
			_set_message("%s FIZZLES  •  BOARD REMAINS SOLVABLE" % board_action.to_upper())
	var delay := 0.35 if bool(SaveSystem.setting("reduced_effects")) else 1.2
	get_tree().create_timer(delay).timeout.connect(func():
		if not battle.battle_over: board.enabled = true)


func _apply_boss_board_action(action: String) -> bool:
	var result := BoardActionResolver.new().apply({"id": action,
			"seed": RunState.run_seed + RunState.battle_index * 101}, board)
	return bool(result.get("applied", false))


func _on_combo_triggered(text: String) -> void:
	_set_message(text)
	UiKit.float_text(self, _enemy_center() + Vector2(-80, 60), text,
			UiKit.COLOR_GOLD, 28)


func _on_enemy_attacked(damage: int, blocked: int, crit: bool) -> void:
	enemy_display.play_attack()
	battle_fx.impact_freeze(75 if crit else 45)
	AudioManager.duck_music(0.28, 7.0 if crit else 4.0)
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
		AudioManager.haptic("critical" if crit else "hit")
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
	if encounter_format.on_enemy_defeated() == "next_wave":
		board.enabled = false
		_set_message("WAVE CLEARED  •  " + encounter_format.status_text())
		battle.setup_next_wave(encounter_format.wave)
		enemy_display.configure_enemy(battle.enemy_id, battle.enemy_shape, battle.enemy_color)
		enemy_display.play_intro()
		board.enabled = true
		_refresh()
		_checkpoint_encounter()
		return
	AudioManager.set_scene_state("victory")
	objective_controller.on_enemy_defeated()
	SaveSystem.record_early_defeat(false)
	board.enabled = false
	enemy_display.play_defeat()
	AudioManager.play("victory")
	AudioManager.stop_music()
	var was_last := RunState.is_last_battle()
	var was_elite := str(RunState.current_battle().get("kind", "battle")) == "elite"
	var campaign_result := RunState.complete_battle(battle.player_hp, battle.crystals_reward)
	if not was_last:
		RunState.checkpoint(RunState.PHASE_REWARD, {"encounter": _capture_encounter(),
				"elite": was_elite})
	if was_last:
		var area_name := str(RunState.current_area().get("name", "expedition"))
		var first_reward := int(campaign_result.get("reward", 0))
		var unlocked_id := str(campaign_result.get("unlocked_area", ""))
		var unlocked_copy := ""
		if not unlocked_id.is_empty():
			unlocked_copy = "\nNEW EXPEDITION UNLOCKED: %s" % str(
					GameState.area(unlocked_id).get("name", unlocked_id)).to_upper()
		var reward_copy := "\nFirst-clear bonus: +%d crystals" % first_reward if first_reward > 0 else ""
		var title := "Campaign Conquered!" if bool(campaign_result.get("campaign_complete", false)) \
				else ("Area Conquered!" if bool(campaign_result.get("first_clear", false)) else "Boss Defeated!")
		var actions: Array = []
		if not unlocked_id.is_empty():
			actions.append(["Next Expedition", _go_to_area_select])
		actions.append(["Replay Area", _replay_area])
		actions.append(["Main Menu", _go_to_menu])
		_show_overlay(title,
				"You conquered %s!\nRun crystals: %d%s%s\nTotal crystals: %d"
				% [area_name, RunState.run_crystals, reward_copy, unlocked_copy,
					SaveSystem.crystals()], actions)
	elif was_elite:
		_show_relic_choice()
	else:
		_show_upgrade_choice()


func _show_upgrade_choice() -> void:
	var choices := RunState.roll_upgrade_choices()
	var body := "+%d crystals\nChoose an upgrade:" % battle.crystals_reward
	_show_overlay("Victory!", body, [])
	for id in choices:
		var card := _reward_choice_button(RunState.upgrade_name(id),
				RunState.upgrade_description(id))
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
		var card := _reward_choice_button(RunState.relic_name(id),
				RunState.relic_description(id), Color("c07ce8"))
		card.pressed.connect(_on_relic_picked.bind(str(id)))
		overlay_choices.add_child(card)


func _reward_choice_button(title: String, description: String,
		accent := UiKit.COLOR_GOLD) -> Button:
	var card := UiKit.ornate_button("%s\n%s" % [title, description],
			Vector2(0, 108), accent)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_theme_font_size_override("font_size", 18)
	return card


func _on_relic_picked(id: String) -> void:
	RunState.pick_relic(id)
	RunState.checkpoint(RunState.PHASE_MAP)
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _on_upgrade_picked(id: String) -> void:
	var first_reward := RunState.upgrade_ids.is_empty()
	RunState.pick_upgrade(id)
	# "Cursed Draft": at high Ascension the first claimed reward binds a curse.
	if first_reward and AscensionRules.new().addition(RunState.run_ascension,
			"reward_curse") > 0:
		RunState.active_curses += 1
		_set_message("The cursed draft clings to your first prize.")
	# Instant-effect extras carried by some upgrades (e.g. Vital Tonic).
	var heal_now := int(RunState.upgrade_pool.get(id, {}).get("heal_now", 0))
	if heal_now > 0:
		RunState.player_hp = mini(RunState.player_hp + heal_now,
				int(RunState.stat("max_hp", float(GameState.player.get("max_hp", 50)))))
	RunState.checkpoint(RunState.PHASE_MAP)
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _on_battle_lost() -> void:
	AudioManager.set_scene_state("defeat")
	board.enabled = false
	AudioManager.play("defeat")
	AudioManager.stop_music()
	AudioManager.vibrate(120)
	var kept := RunState.fail_run()
	var floor := int(RunState.current_node().get("floor", RunState.battle_index))
	var streak := SaveSystem.record_early_defeat(floor <= 2)
	var actions: Array = [["New Run", _start_new_run], ["Main Menu", _go_to_menu]]
	if streak >= 2 and floor <= 2 and not bool(SaveSystem.setting("assist_mode")):
		actions.push_front(["Enable Assist", _enable_assist])
	_show_overlay("Defeated...",
			"You fell in battle %d of %d.\nEnemies defeated: %d\nCrystals kept: %d\nTotal crystals: %d"
			% [RunState.battle_index + 1, RunState.battles().size(),
				RunState.battle_index, kept, SaveSystem.crystals()],
			actions)


func _enable_assist() -> void:
	SaveSystem.set_setting("assist_mode", true)
	_start_new_run()


func _show_pause() -> void:
	if battle.battle_over:
		return
	board.enabled = false
	_checkpoint_encounter()
	RunState.flush_checkpoint("pause")
	overlay_controller.show_pause([
		["Resume", _hide_overlay],
		["Save & Exit", _save_and_exit],
		["Abandon Run", _confirm_abandon],
	])


func _save_and_exit() -> void:
	_checkpoint_encounter()
	RunState.flush_checkpoint("save_and_exit")
	_go_to_menu()


func _confirm_abandon() -> void:
	_show_overlay("Abandon this run?",
			"You keep half of this run's crystals. The current expedition and battle cannot be recovered.", [
		["Keep Fighting", _show_pause],
		["Confirm Abandon", _abandon_run],
	])


func _abandon_run() -> void:
	RunState.abandon_run()
	_go_to_menu()


## buttons: Array of [text, Callable] pairs.
func _show_overlay(title: String, body: String, buttons: Array) -> void:
	overlay_controller.show(title, body, buttons)


func _hide_overlay() -> void:
	overlay_controller.hide()
	if not battle.battle_over:
		board.enabled = true


# --- Button handlers --------------------------------------------------------

func _on_undo_pressed() -> void:
	if undo_left <= 0:
		return
	if board.undo():
		undo_left -= 1
		battle.on_undo()
		RunState.record_replay("undo", {"remaining":undo_left,
				"board":board.export_state()})
		_set_message("Move undone.")
		_tutorial_action("undo")
		_checkpoint_encounter()
		_refresh()


func _on_restart_pressed() -> void:
	if battle.battle_over or remix_jobs.is_busy():
		return
	var integrity := board.integrity_report()
	_pending_remix_quote = remix_economy.quote(str(integrity.get("status", "invalid")),
			remix_economy.mix_count, skill_controller.mana)
	if not bool(_pending_remix_quote.get("allowed", false)):
		_set_message("NEW MIX NEEDS %d MANA" % int(_pending_remix_quote.get("mana_cost", 20)))
		return
	_pending_remix_snapshot = board.export_snapshot()
	_pending_remix_seed = int(randi())
	_pending_remix_generation = remix_jobs.request(board.export_state(), _pending_remix_seed,
			"standard", PotionTube.CAPACITY)
	board.enabled = false
	_set_message("BREWING...")


func _start_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/area_select.tscn")


func _replay_area() -> void:
	RunState.pending_area_id = RunState.area_id
	get_tree().change_scene_to_file("res://scenes/kit_select.tscn")


func _go_to_area_select() -> void:
	battle_navigation.go_to_area_select()


func _go_to_menu() -> void:
	battle_navigation.go_to_menu()
