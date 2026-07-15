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


func _ready() -> void:
	run_config = GameState.load_data_file("run.json", DEFAULT_RUN)
	upgrade_pool = GameState.load_data_file("upgrades.json", {})
	relic_pool = GameState.load_data_file("relics.json", {})
	perma_pool = GameState.load_data_file("perma_upgrades.json", {})


func start_new_run() -> void:
	battle_index = 0
	player_hp = -1
	upgrade_ids = []
	relic_ids = []
	run_crystals = 0
	active = true
	SaveSystem.bump_stat("runs_started")


func battles() -> Array:
	return run_config.get("battles", DEFAULT_RUN["battles"])


func current_battle() -> Dictionary:
	var list := battles()
	return list[clampi(battle_index, 0, list.size() - 1)]


func is_boss_battle() -> bool:
	return str(current_battle().get("kind", "battle")) == "boss"


func is_last_battle() -> bool:
	return battle_index >= battles().size() - 1


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
	return value


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
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))


## Relic choices after an elite battle (each relic can be owned once).
func roll_relic_choices(count := 3) -> Array:
	var candidates: Array = []
	for id in relic_pool:
		if not id in relic_ids:
			candidates.append(id)
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))


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
func complete_battle(hp_left: int, crystals_reward: int) -> void:
	var max_hp := int(stat("max_hp", float(GameState.player.get("max_hp", 50))))
	player_hp = mini(hp_left + int(stat("post_battle_heal", 0.0)), max_hp)
	run_crystals += crystals_reward + int(stat("crystal_bonus", 0.0))
	SaveSystem.bump_stat("battles_won")
	if is_last_battle():
		active = false
		SaveSystem.add_crystals(run_crystals)
		SaveSystem.bump_stat("runs_won")
	else:
		battle_index += 1


## Called on defeat: half the crystals are kept. Returns the amount kept.
func fail_run() -> int:
	active = false
	var kept := run_crystals / 2
	if kept > 0:
		SaveSystem.add_crystals(kept)
	return kept
