extends Node
## Autoload: RunState
## State of the current roguelike run: battle progress, HP carry-over, picked
## upgrades/relics and crystals earned. All modifiers are pure data — upgrades,
## relics and permanent upgrades add to named stats that BattleManager queries
## via stat(name, base).

const DEFAULT_RUN := {
	"area_name": "Shadow Crypt",
	"battles": [{"enemy": "slime", "kind": "battle"}],
}

const PHASE_MAP := "MAP"
const PHASE_BATTLE := "BATTLE"
const PHASE_EVENT := "EVENT"
const PHASE_REWARD := "REWARD"
const PHASE_COMPLETE := "COMPLETE"
const VALID_PHASES := [PHASE_MAP, PHASE_BATTLE, PHASE_EVENT, PHASE_REWARD, PHASE_COMPLETE]
const CHECKPOINT_SCHEDULER := preload("res://src/autoload/checkpoint_scheduler.gd")

var battle_index := 0
var player_hp := -1  # HP carried between battles; -1 = start at full
var upgrade_ids: Array = []
var relic_ids: Array = []
var run_crystals := 0
var run_config: Dictionary = {}
var upgrade_pool: Dictionary = {}
var relic_pool: Dictionary = {}
var perma_pool: Dictionary = {}
var active := false
var kit_id := "ember_adept"
var mutation_ids: Array = []
var catalyst_ids: Array = []
var mutation_pool: Dictionary = {}
var catalyst_pool: Dictionary = {}
var run_graph: Dictionary = {}
var current_node_id := ""
var run_seed := 0
var resolved_event_ids: Array = []
var active_curses := 0
var area_id := "shadow_crypt"
var pending_area_id := "shadow_crypt"
var phase := PHASE_MAP
var phase_payload: Dictionary = {}
var run_mode := "normal"
var pending_run_mode := "normal"
var pending_run_seed := 0
var run_ascension := 0
var pending_ascension := 0
var _checkpoint_scheduler = CHECKPOINT_SCHEDULER.new()
var _run_rng := RunRng.new()
var _replay_journal := ReplayJournal.new()


func _ready() -> void:
	_checkpoint_scheduler.configure(_write_checkpoint_boundary)
	run_config = GameState.load_data_file("run.json", DEFAULT_RUN)
	upgrade_pool = GameState.load_data_file("upgrades.json", {})
	relic_pool = GameState.load_data_file("relics.json", {})
	mutation_pool = GameState.load_data_file("mutations.json", {})
	catalyst_pool = GameState.load_data_file("catalysts.json", {})
	perma_pool = GameState.load_data_file("perma_upgrades.json", {})
	pending_area_id = SaveSystem.selected_area()
	pending_ascension = SaveSystem.selected_ascension()
	var saved_run: Dictionary = SaveSystem.data.get("active_run", {})
	if not saved_run.is_empty():
		resume_from_save(saved_run)
	set_process(true)


func _process(_delta: float) -> void:
	if _checkpoint_scheduler.is_due():
		_checkpoint_scheduler.flush("quiet_window")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		flush_checkpoint("application_boundary")


func start_new_run(selected_kit := "ember_adept", selected_area_id := "",
		selected_mode := "", forced_seed := 0) -> void:
	battle_index = 0
	player_hp = -1
	upgrade_ids = []
	relic_ids = []
	run_crystals = 0
	kit_id = selected_kit if GameState.kits.has(selected_kit) else "ember_adept"
	mutation_ids = []
	catalyst_ids = []
	resolved_event_ids = []
	active_curses = 0
	phase = PHASE_MAP
	phase_payload = {}
	run_mode = selected_mode if not selected_mode.is_empty() else pending_run_mode
	if run_mode not in ["normal", "daily", "weekly", "rematch"]: run_mode = "normal"
	run_ascension = clampi(pending_ascension, 0, SaveSystem.max_ascension()) \
			if run_mode == "normal" else 0
	var requested_area := selected_area_id if not selected_area_id.is_empty() else pending_area_id
	area_id = requested_area if SaveSystem.is_area_unlocked(requested_area) else "shadow_crypt"
	pending_area_id = area_id
	SaveSystem.set_selected_area(area_id)
	var requested_seed := forced_seed if forced_seed != 0 else pending_run_seed
	run_seed = requested_seed if requested_seed != 0 else \
			int(Time.get_unix_time_from_system() * 1000000.0) ^ Time.get_ticks_usec()
	# Daily and Weekly runs are authored packages, not just a shared seed:
	# dailies inject one deterministic board twist into every battle, weeklies
	# fix the kit so scores within a week stay comparable.
	var daily_twist := ""
	if run_mode == "daily":
		daily_twist = str(MetaProgression.new().daily_spec(
				Time.get_date_string_from_system(true)).get("twist", ""))
	elif run_mode == "weekly":
		var weekly := MetaProgression.new().weekly_spec(
				MetaProgression.new().current_week_key())
		if GameState.kits.has(str(weekly.get("kit_id", ""))):
			kit_id = str(weekly.kit_id)
	_run_rng.configure(run_seed ^ 0x51ed270b)
	_replay_journal.clear()
	_replay_journal.record("run_started", {"seed":run_seed, "area":area_id,
			"mode":run_mode, "ascension":run_ascension, "kit":kit_id,
			"twist":daily_twist})
	run_graph = RunGenerator.new().generate(run_seed, area_id, run_ascension,
			daily_twist)
	current_node_id = str(run_graph.get("start", "f0_l1"))
	if run_mode == "rematch":
		for node in run_graph.get("nodes", []):
			if str(node.get("kind", "")) == "boss":
				current_node_id = str(node.get("id", current_node_id)); phase = PHASE_BATTLE; break
	# Mastery perks reward long-term play in normal runs; challenge modes stay
	# on a level field.
	if run_mode in ["normal", "rematch"]:
		run_crystals += int(MetaProgression.new().mastery_perks(area_id).get(
				"start_crystals", 0))
	active = true
	SaveSystem.bump_stat("runs_started")
	SaveSystem.record_area_depth(area_id, 0)
	pending_run_mode = "normal"; pending_run_seed = 0
	checkpoint(phase)


func current_area() -> Dictionary:
	return GameState.area(area_id)


func battles() -> Array:
	return run_config.get("battles", DEFAULT_RUN["battles"])


func current_battle() -> Dictionary:
	var node := current_node()
	if not node.is_empty():
		return {"enemy": node.get("enemy", "slime"), "kind": node.get("kind", "battle")}
	var list := battles()
	return list[clampi(battle_index, 0, list.size() - 1)]


func is_boss_battle() -> bool:
	return str(current_battle().get("kind", "battle")) == "boss"


func is_last_battle() -> bool:
	if not run_graph.is_empty():
		return str(current_node().get("kind", "")) == "boss"
	return battle_index >= battles().size() - 1


func current_node() -> Dictionary:
	for node in run_graph.get("nodes", []):
		if str(node.get("id", "")) == current_node_id:
			return node
	return {}


func current_contract() -> Dictionary:
	return current_node().get("contract", {})


func ensure_current_encounter_profile() -> Dictionary:
	var node := current_node()
	if node.is_empty() or str(node.get("kind", "")) not in ["battle", "elite", "boss"]:
		return {}
	var contract: Dictionary = node.get("contract", {})
	if not (contract.get("profile", {}) as Dictionary).is_empty():
		return contract.profile
	var ratio := float(current_hp()) / float(maxi(max_hp(), 1))
	contract["profile"] = EncounterDirector.new().build_profile({
		"floor": int(node.get("floor", 0)), "kind": str(node.get("kind", "battle")),
		"hp_ratio": ratio, "ascension": run_ascension,
		"early_defeat_streak": int(SaveSystem.data.get("early_defeat_streak", 0)),
	}, run_seed ^ str(node.get("id", "")).hash())
	node["contract"] = contract
	return contract.profile


func reachable_node_ids() -> Array[String]:
	var result: Array[String] = []
	for id in current_node().get("links", []): result.append(str(id))
	return result


func select_node(id: String) -> bool:
	if id not in reachable_node_ids(): return false
	var current := current_node()
	current["visited"] = true
	current_node_id = id
	ensure_current_encounter_profile()
	_adapt_route_to_condition()
	record_replay("route_selected", {"node_id":id})
	var kind := str(current_node().get("kind", "battle"))
	checkpoint(PHASE_BATTLE if kind in ["battle", "elite", "boss"] else PHASE_EVENT)
	return true


## Adaptive pacing: a struggling player finds a rest site ahead. Deterministic
## (first eligible node), additive-only (never removes content), and marked so
## the map can show it honestly.
func _adapt_route_to_condition() -> void:
	var ratio := float(current_hp()) / float(maxi(max_hp(), 1))
	if ratio > 0.35:
		return
	var next_floor := int(current_node().get("floor", 0)) + 1
	for node in run_graph.get("nodes", []):
		if int(node.get("floor", -1)) != next_floor:
			continue
		if str(node.get("kind", "")) != "event" or bool(node.get("visited", false)) \
				or bool(node.get("adapted", false)):
			continue
		node["kind"] = "campfire"
		node["reveal_kind"] = "REST"
		node["event_id"] = "ember_camp"
		node["adapted"] = true
		record_replay("route_adapted", {"node_id": str(node.get("id", "")),
				"hp_ratio": ratio})
		return


func checkpoint(next_phase: String, payload := {}) -> void:
	if next_phase not in VALID_PHASES:
		return
	request_checkpoint(next_phase, payload)
	flush_checkpoint("hard_boundary")


func request_checkpoint(next_phase: String, payload := {}) -> void:
	if next_phase not in VALID_PHASES:
		return
	phase = next_phase
	phase_payload = (payload as Dictionary).duplicate(true)
	if active:
		_checkpoint_scheduler.request(next_phase, phase_payload)


func flush_checkpoint(reason := "manual") -> bool:
	return _checkpoint_scheduler.flush(reason)


func _write_checkpoint_boundary(next_phase: String, payload: Dictionary) -> bool:
	phase = next_phase
	phase_payload = payload.duplicate(true)
	return SaveSystem.save_run_boundary(serialize_boundary())


func resume_scene() -> String:
	match phase:
		PHASE_BATTLE, PHASE_REWARD: return "res://scenes/battle.tscn"
		PHASE_EVENT: return "res://scenes/event.tscn"
		_: return "res://scenes/map.tscn"


func serialize_boundary() -> Dictionary:
	return {"version": 7, "active": active, "seed": run_seed, "area_id": area_id,
		"graph": run_graph.duplicate(true), "current_node_id": current_node_id,
		"phase": phase, "phase_payload": phase_payload.duplicate(true),
		"run_mode": run_mode, "ascension": run_ascension,
		"kit_id": kit_id, "player_hp": player_hp, "run_crystals": run_crystals,
		"mutations": mutation_ids.duplicate(), "relics": relic_ids.duplicate(),
		"catalysts": catalyst_ids.duplicate(), "upgrades": upgrade_ids.duplicate(),
		"resolved_events": resolved_event_ids.duplicate(), "active_curses": active_curses,
		"rng_state": int(_run_rng.snapshot().state),
		"replay":_replay_journal.snapshot()}


func resume_from_save(saved: Dictionary) -> bool:
	var boundary_version := int(saved.get("version", 0))
	if boundary_version not in [2, 3, 4, 5, 6, 7] or not bool(saved.get("active", false)): return false
	if typeof(saved.get("graph", null)) != TYPE_DICTIONARY: return false
	var loaded_area := str(saved.get("area_id", "shadow_crypt"))
	area_id = loaded_area if not GameState.area(loaded_area).is_empty() else "shadow_crypt"
	pending_area_id = area_id
	var loaded_kit := str(saved.get("kit_id", "ember_adept"))
	kit_id = loaded_kit if GameState.kits.has(loaded_kit) else "ember_adept"
	run_seed = int(saved.get("seed", 0)); run_graph = saved.graph.duplicate(true)
	current_node_id = str(saved.get("current_node_id", ""))
	_repair_graph_enemy_themes()
	_run_rng.configure(run_seed ^ 0x51ed270b, int(saved.get("rng_state", 0)))
	run_mode = str(saved.get("run_mode", "normal"))
	run_ascension = clampi(int(saved.get("ascension", 0)), 0, 10)
	pending_ascension = run_ascension
	if current_node().is_empty(): return false
	var loaded_phase := str(saved.get("phase", PHASE_MAP)) if boundary_version >= 4 else PHASE_MAP
	phase = loaded_phase if loaded_phase in VALID_PHASES else PHASE_MAP
	phase_payload = (saved.get("phase_payload", {}) as Dictionary).duplicate(true)
	player_hp = int(saved.get("player_hp", -1)); run_crystals = maxi(int(saved.get("run_crystals", 0)), 0)
	mutation_ids = _valid_ids(saved.get("mutations", []), mutation_pool)
	relic_ids = _valid_ids(saved.get("relics", []), relic_pool)
	catalyst_ids = _valid_ids(saved.get("catalysts", []), catalyst_pool)
	upgrade_ids = _valid_ids(saved.get("upgrades", []), upgrade_pool)
	resolved_event_ids = saved.get("resolved_events", []).duplicate()
	active_curses = maxi(int(saved.get("active_curses", 0)), 0); active = true
	_replay_journal.clear()
	if boundary_version >= 7:
		_replay_journal.restore(saved.get("replay", {}))
	return true


func _repair_graph_enemy_themes() -> void:
	var area := GameState.area(area_id)
	var allowed: Array = area.get("enemy_families", [])
	var pools: Dictionary = area.get("enemy_pools", {})
	if allowed.is_empty() or pools.is_empty():
		return
	for node in run_graph.get("nodes", []):
		var kind := str(node.get("kind", ""))
		if kind not in ["battle", "elite"]:
			continue
		# Never swap an encounter already selected/in progress; repair only the
		# remaining route so battle snapshots and portraits cannot diverge.
		if str(node.get("id", "")) == current_node_id:
			continue
		var enemy_id := str(node.get("enemy", ""))
		if str(GameState.enemies.get(enemy_id, {}).get("family", "")) in allowed:
			continue
		var floor := int(node.get("floor", 0))
		var pool_name := "elite" if kind == "elite" else (
				"intro" if floor <= 1 else "tier_1" if floor == 2 else
				"tier_2" if floor in [3, 4] else "tier_3")
		var candidates: Array = []
		for candidate in pools.get(pool_name, pools.get("intro", [])):
			if str(GameState.enemies.get(str(candidate), {}).get("family", "")) in allowed:
				candidates.append(str(candidate))
		if candidates.is_empty():
			continue
		var replacement := str(candidates[posmod(hash(str(node.get("id", ""))
				+ ":" + str(run_seed)), candidates.size())])
		node["enemy"] = replacement
		var contract: Dictionary = node.get("contract", {})
		contract["enemy_id"] = replacement
		node["contract"] = contract


func record_replay(kind: String, payload := {}) -> void:
	_replay_journal.record(kind, payload)


func replay_snapshot() -> Dictionary:
	return _replay_journal.snapshot()


func abandon_run() -> int:
	if active:
		MetaProgression.new().record_run({"seed":run_seed, "area":area_id,
				"mode":run_mode, "ascension":run_ascension,
				"result":"abandoned", "depth":battle_index,
				"crystals":run_crystals, "relics":relic_ids.duplicate(),
				"mutations":mutation_ids.duplicate(), "catalysts":catalyst_ids.duplicate(),
				"upgrades":upgrade_ids.duplicate(), "kit":kit_id})
	var kept := run_crystals / 2
	if kept > 0:
		SaveSystem.add_crystals(kept)
	active = false
	phase = PHASE_COMPLETE
	phase_payload = {}
	SaveSystem.clear_active_run()
	return kept


func _valid_ids(raw_ids: Array, pool: Dictionary) -> Array:
	var result: Array = []
	for id in raw_ids:
		if pool.has(str(id)) and str(id) not in result: result.append(str(id))
	return result


## Effective value of a named stat: base + permanent upgrades (crystal shop)
## + this run's upgrades + this run's relics.
func stat(stat_name: String, base: float) -> float:
	var value := base + perma_bonus(stat_name)
	for id in upgrade_ids:
		var up: Dictionary = upgrade_pool.get(id, {})
		if str(up.get("stat", "")) == stat_name:
			value += float(up.get("add", 0))
	for id in relic_ids:
		var relic: Dictionary = relic_pool.get(id, {})
		if str(relic.get("stat", "")) == stat_name:
			value += float(relic.get("add", 0))
		for effect in relic.get("effects", []):
			if str(effect.get("stat", "")) != stat_name: continue
			match str(effect.get("op", "")):
				"add": value += float(effect.get("value", 0))
				"multiply": value *= float(effect.get("value", 1))
				"replace": value = float(effect.get("value", value))
	return value


## Applies build effects in the stable order mutation -> relic -> catalyst -> temporary.
func resolve_effect_value(stat_name: String, base: float,
		temporary_effects: Array = []) -> float:
	var value := base
	for group in [
			_effects_for(mutation_ids, mutation_pool),
			_effects_for(relic_ids, relic_pool),
			_effects_for(catalyst_ids, catalyst_pool),
			temporary_effects,
	]:
		for effect in group:
			if str(effect.get("stat", "")) != stat_name:
				continue
			match str(effect.get("op", "")):
				"add": value += float(effect.get("value", 0.0))
				"multiply": value *= float(effect.get("value", 1.0))
				"replace": value = float(effect.get("value", value))
	return value


func _effects_for(ids: Array, pool: Dictionary) -> Array:
	var effects: Array = []
	for id in ids:
		for effect in pool.get(id, {}).get("effects", []):
			if str(effect.get("op", "")) in ["add", "multiply", "replace",
					"on_complete", "on_absorb", "on_kill"]:
				effects.append(effect)
	return effects


func reward_build() -> Dictionary:
	var tags: Array = GameState.kits.get(kit_id, {}).get("tags", []).duplicate()
	return {"tags": tags, "owned": mutation_ids + relic_ids + catalyst_ids}


func max_hp() -> int:
	return int(stat("max_hp", float(GameState.player.get("max_hp", 50))))


func current_hp() -> int:
	return max_hp() if player_hp < 0 else player_hp


func heal(amount: int) -> void:
	player_hp = mini(max_hp(), current_hp() + maxi(0, amount))


func spend_run_crystals(amount: int) -> bool:
	if run_crystals < amount: return false
	run_crystals -= amount
	return true


func add_relic(id: String) -> bool:
	if id.is_empty() or not relic_pool.has(id) or id in relic_ids: return false
	relic_ids.append(id); return true


func add_mutation(id: String) -> bool:
	if id.is_empty() or not mutation_pool.has(id) or id in mutation_ids: return false
	mutation_ids.append(id); return true


func add_catalyst(id: String) -> bool:
	if id.is_empty() or not catalyst_pool.has(id) or id in catalyst_ids: return false
	catalyst_ids.append(id); return true


func cleanse_curse(count: int) -> int:
	var removed := mini(active_curses, maxi(0, count))
	active_curses -= removed
	return removed


## Total bonus for a stat from purchased permanent upgrade levels.
func perma_bonus(stat_name: String) -> float:
	var bonus := 0.0
	for id in perma_pool:
		var up: Dictionary = perma_pool[id]
		if str(up.get("stat", "")) == stat_name:
			bonus += float(up.get("add_per_level", 0)) * SaveSystem.perma_level(id)
	return bonus


## Cost of the next level of a permanent upgrade (scales with level).
func perma_cost(id: String) -> int:
	var up: Dictionary = perma_pool.get(id, {})
	return int(up.get("base_cost", 20)) * (SaveSystem.perma_level(id) + 1)


func buy_perma(id: String) -> bool:
	var up: Dictionary = perma_pool.get(id, {})
	if up.is_empty() or SaveSystem.perma_level(id) >= int(up.get("max_level", 1)):
		return false
	if not SaveSystem.spend_crystals(perma_cost(id)):
		return false
	SaveSystem.raise_perma_level(id)
	return true


## Three random upgrade choices; non-repeatable upgrades appear only once per run.
func roll_upgrade_choices(count := 3) -> Array:
	var candidates: Array = []
	for id in upgrade_pool:
		var up: Dictionary = upgrade_pool[id]
		if not bool(up.get("repeatable", false)) and id in upgrade_ids:
			continue
		candidates.append(id)
	var shuffled := _run_rng.permute_serialized(candidates)
	return shuffled.slice(0, mini(count, shuffled.size()))


## Relic choices after an elite battle (each relic can be owned once).
func roll_relic_choices(count := 3) -> Array:
	var candidates: Array = []
	for id in relic_pool:
		if not id in relic_ids:
			candidates.append(id)
	var shuffled := _run_rng.permute_serialized(candidates)
	return shuffled.slice(0, mini(count, shuffled.size()))


func pick_upgrade(id: String) -> void:
	if upgrade_pool.has(id):
		upgrade_ids.append(id)


func pick_relic(id: String) -> void:
	if relic_pool.has(id):
		relic_ids.append(id)


func upgrade_name(id: String) -> String:
	return str(upgrade_pool.get(id, {}).get("name", id))


func upgrade_description(id: String) -> String:
	return str(upgrade_pool.get(id, {}).get("description", ""))


func relic_name(id: String) -> String:
	return str(relic_pool.get(id, {}).get("name", id))


func relic_description(id: String) -> String:
	return str(relic_pool.get(id, {}).get("description", ""))


## Called by the battle screen after a victory.
func complete_battle(hp_left: int, crystals_reward: int) -> Dictionary:
	var max_hp := int(stat("max_hp", float(GameState.player.get("max_hp", 50))))
	player_hp = mini(hp_left + int(stat("post_battle_heal", 0.0)), max_hp)
	run_crystals += crystals_reward + int(stat("crystal_bonus", 0.0))
	SaveSystem.bump_stat("battles_won")
	if is_last_battle():
		active = false
		SaveSystem.add_crystals(run_crystals)
		SaveSystem.bump_stat("runs_won")
		MetaProgression.new().record_run({"seed":run_seed, "area":area_id,
				"mode":run_mode, "ascension":run_ascension,
				"result":"victory", "depth":int(current_area().get("run_length", 7)),
				"crystals":run_crystals, "relics":relic_ids.duplicate(),
				"mutations":mutation_ids.duplicate(), "catalysts":catalyst_ids.duplicate(),
				"upgrades":upgrade_ids.duplicate(), "kit":kit_id})
		MetaProgression.new().complete_mastery(area_id,
				str(current_contract().get("objective_id", "defeat")))
		MetaProgression.new().add_area_mastery(area_id, 30 + run_ascension * 5)
		if run_mode == "normal" and MetaProgression.new().ascension_unlocked():
			MetaProgression.new().record_ascension_clear(run_ascension)
		if run_mode == "daily": MetaProgression.new().complete_daily(
				Time.get_date_string_from_system(true),
				int(current_area().get("run_length", 7)), run_crystals)
		if run_mode == "weekly": MetaProgression.new().complete_weekly(
				MetaProgression.new().current_week_key(), 1000 + run_crystals * 10)
		var result := SaveSystem.complete_area(area_id)
		SaveSystem.clear_active_run()
		return result
	else:
		battle_index += 1
		SaveSystem.record_area_depth(area_id, int(current_node().get("floor", battle_index)))
	return {}


## Called on defeat: half the crystals are kept. Returns the amount kept.
func fail_run() -> int:
	return abandon_run()
