class_name SkillController
extends RefCounted

signal mana_changed(current: int, maximum: int)
signal skill_cast(skill_id: String)
signal ultimate_became_ready

var mana := 0
var kit_id := "ember_adept"
var _ultimate := 0
var _board: PuzzleBoard
var _cooldowns: Dictionary = {}

func configure(id: String, board: PuzzleBoard = null) -> void:
	kit_id = id if GameState.kits.has(id) else "ember_adept"
	_board = board
	mana = 0
	_ultimate = 0
	_cooldowns.clear()

func gain_mana(amount: int) -> void:
	mana = clampi(mana + maxi(amount, 0), 0, 100)
	mana_changed.emit(mana, 100)

func can_cast(skill_id: String) -> bool:
	var kit: Dictionary = GameState.kits.get(kit_id, {})
	return str(kit.get("active", "")) == skill_id \
			and mana >= int(kit.get("cost", 0)) \
			and int(_cooldowns.get(skill_id, 0)) == 0

func cast(skill_id: String, target: Dictionary) -> Dictionary:
	if not can_cast(skill_id): return {"ok": false, "reason": "unavailable"}
	if skill_id == "transmute":
		if _board == null or not _board.apply_board_command({"type":"replace_top",
				"tube":int(target.get("tube", -1)), "color":"wild"}):
			return {"ok": false, "reason": "invalid_target"}
	var kit: Dictionary = GameState.kits[kit_id]
	mana -= int(kit.get("cost", 0))
	_cooldowns[skill_id] = int(kit.get("cooldown", 1))
	mana_changed.emit(mana, 100)
	skill_cast.emit(skill_id)
	return {"ok": true, "skill": skill_id}

func tick_cooldowns() -> void:
	for id in _cooldowns: _cooldowns[id] = maxi(int(_cooldowns[id]) - 1, 0)

func gain_ultimate(amount: int) -> void:
	var was_ready := ultimate_ready()
	_ultimate = clampi(_ultimate + maxi(amount, 0), 0, 100)
	if not was_ready and ultimate_ready(): ultimate_became_ready.emit()

func ultimate_ready() -> bool: return _ultimate >= 100
func ultimate_charge() -> int: return _ultimate
func consume_ultimate() -> bool:
	if not ultimate_ready(): return false
	_ultimate = 0
	return true


func cast_ultimate(_context: Dictionary) -> Dictionary:
	if not consume_ultimate():
		return {"ok": false, "reason": "not_ready"}
	match kit_id:
		"verdant_warden":
			return {"ok": true, "effect_id": "guardian_bloom", "heal": 22,
					"shield": 24, "cleanse": 1}
		"void_brewer":
			return {"ok": true, "effect_id": "void_distill", "poison": 9,
					"poison_turns": 4, "delay": 1, "wild_layer": true}
		_:
			return {"ok": true, "effect_id": "inferno_break", "damage": 42,
					"break_armor": 999}

func snapshot() -> Dictionary:
	return {"mana": mana, "ultimate": _ultimate, "cooldowns": _cooldowns.duplicate(true)}

func restore(snapshot_data: Dictionary) -> void:
	mana = clampi(int(snapshot_data.get("mana", 0)), 0, 100)
	_ultimate = clampi(int(snapshot_data.get("ultimate", 0)), 0, 100)
	_cooldowns = (snapshot_data.get("cooldowns", {}) as Dictionary).duplicate(true)
	mana_changed.emit(mana, 100)
