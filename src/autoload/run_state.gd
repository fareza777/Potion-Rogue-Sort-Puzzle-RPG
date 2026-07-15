extends Node
## Autoload: RunState
## State of the current roguelike run: battle progress, HP carry-over,
## picked upgrades and crystals earned. Upgrades are pure data — they add
## to named stats that BattleManager queries via stat().

const DEFAULT_RUN := {
	"area_name": "Shadow Crypt",
	"battles": [{"enemy": "slime", "kind": "battle"}],
}

var battle_index := 0
var player_hp := -1  # HP carried between battles; -1 = start at full
var upgrade_ids: Array = []
var run_crystals := 0
var run_config: Dictionary = {}
var upgrade_pool: Dictionary = {}
var active := false


func _ready() -> void:
	run_config = GameState.load_data_file("run.json", DEFAULT_RUN)
	upgrade_pool = GameState.load_data_file("upgrades.json", {})


func start_new_run() -> void:
	battle_index = 0
	player_hp = -1
	upgrade_ids = []
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


## Sum of all "add" modifiers from picked upgrades for a named stat.
func stat(stat_name: String, base: float) -> float:
	var value := base
	for id in upgrade_ids:
		var up: Dictionary = upgrade_pool.get(id, {})
		if str(up.get("stat", "")) == stat_name:
			value += float(up.get("add", 0))
	return value


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


func pick_upgrade(id: String) -> void:
	if upgrade_pool.has(id):
		upgrade_ids.append(id)


func upgrade_name(id: String) -> String:
	return str(upgrade_pool.get(id, {}).get("name", id))


func upgrade_description(id: String) -> String:
	return str(upgrade_pool.get(id, {}).get("description", ""))


## Called by the battle screen after a victory.
func complete_battle(hp_left: int, crystals_reward: int) -> void:
	player_hp = hp_left
	run_crystals += crystals_reward
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
