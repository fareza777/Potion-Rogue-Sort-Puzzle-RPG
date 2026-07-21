class_name MetaProgression
extends RefCounted

const HISTORY_LIMIT := 20


func daily_seed(date_text: String) -> int:
	return absi(("POTION_ROGUE_DAILY:" + date_text).hash()) + 1


func weekly_seed(week_key: String) -> int:
	return absi(("POTION_ROGUE_WEEKLY:" + week_key).hash()) + 1


func current_week_key() -> String:
	return "W%d" % int(floor(Time.get_unix_time_from_system() / 604800.0))


## Twists a battle contract can carry. Kept to board-modifier ids that exist
## in data/modifiers.json so the package is honest and testable.
const DAILY_TWISTS := ["cursed_layer", "volatile_liquid", "wild_essence",
		"chain_lock", "hidden_layer", "unstable_flask", "corruption",
		"frozen_tube"]


## The authored identity of a calendar day: same date, same package, for
## everyone. Locked realms fall back to the player's furthest unlocked realm
## so the challenge is always playable; the UI labels the realm truthfully.
func daily_spec(date_text: String) -> Dictionary:
	var seed := daily_seed(date_text)
	var areas := GameState.area_ids()
	var target_area := str(areas[posmod(seed, areas.size())]) \
			if not areas.is_empty() else "shadow_crypt"
	if not SaveSystem.is_area_unlocked(target_area):
		for candidate in areas:
			if SaveSystem.is_area_unlocked(str(candidate)):
				target_area = str(candidate)
	var twist := str(DAILY_TWISTS[posmod(seed / 7, DAILY_TWISTS.size())])
	return {"seed": seed, "area_id": target_area, "twist": twist,
			"twist_name": str(GameState.modifiers.get(twist, {}).get("name", twist))}


## Weekly expedition: fixed realm AND fixed kit, so scores within a week are
## comparable across attempts.
func weekly_spec(week_key: String) -> Dictionary:
	var seed := weekly_seed(week_key)
	var areas := GameState.area_ids()
	var target_area := str(areas[posmod(seed, areas.size())]) \
			if not areas.is_empty() else "shadow_crypt"
	if not SaveSystem.is_area_unlocked(target_area):
		for candidate in areas:
			if SaveSystem.is_area_unlocked(str(candidate)):
				target_area = str(candidate)
	var kit_ids := GameState.kits.keys()
	kit_ids.sort()
	var kit := str(kit_ids[posmod(seed / 11, kit_ids.size())]) \
			if not kit_ids.is_empty() else "ember_adept"
	return {"seed": seed, "area_id": target_area, "kit_id": kit}


func record_run(summary: Dictionary) -> void:
	var record := summary.duplicate(true)
	record["recorded_at"] = int(Time.get_unix_time_from_system())
	var history: Array = SaveSystem.data.get("run_history", [])
	history.push_front(record)
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)
	SaveSystem.data["run_history"] = history
	SaveSystem.save()


func history() -> Array:
	return (SaveSystem.data.get("run_history", []) as Array).duplicate(true)


func complete_mastery(area_id: String, objective_id: String) -> int:
	var mastery: Dictionary = SaveSystem.data.get("mastery", {})
	var key := area_id + ":" + objective_id
	if bool(mastery.get(key, false)):
		return 0
	mastery[key] = true
	SaveSystem.data["mastery"] = mastery
	SaveSystem.add_crystals(10)
	return 10


func add_area_mastery(area_id: String, xp: int) -> int:
	var records: Dictionary = SaveSystem.data.get("area_mastery", {}).duplicate(true)
	var entry: Dictionary = records.get(area_id, {"xp":0, "clears":0}).duplicate(true)
	var awarded := maxi(xp, 0)
	entry["xp"] = int(entry.get("xp", 0)) + awarded
	entry["clears"] = int(entry.get("clears", 0)) + 1
	records[area_id] = entry
	SaveSystem.data["area_mastery"] = records
	SaveSystem.save()
	return awarded


func area_mastery_rank(area_id: String) -> int:
	var xp := int((SaveSystem.data.get("area_mastery", {}) as Dictionary).get(
			area_id, {}).get("xp", 0))
	return mini(xp / 30, 10)


## Mastery rank thresholds and what each one unlocks, per realm. Perks apply
## to normal runs and rematches only; Daily/Weekly stay comparable for everyone.
const MASTERY_UNLOCKS := [
	{"rank": 2, "label": "+10 starting run crystals"},
	{"rank": 4, "label": "+1 undo per battle"},
	{"rank": 6, "label": "+15 more starting run crystals"},
	{"rank": 9, "label": "+1 more undo per battle"},
]


func mastery_perks(area_id: String) -> Dictionary:
	var rank := area_mastery_rank(area_id)
	return {
		"start_crystals": (10 if rank >= 2 else 0) + (15 if rank >= 6 else 0),
		"extra_undos": (1 if rank >= 4 else 0) + (1 if rank >= 9 else 0),
	}


func next_mastery_unlock(area_id: String) -> String:
	var rank := area_mastery_rank(area_id)
	for unlock in MASTERY_UNLOCKS:
		if rank < int(unlock.rank):
			return "RANK %d UNLOCKS %s" % [int(unlock.rank),
					str(unlock.label).to_upper()]
	return "ALL MASTERY PERKS UNLOCKED"


func complete_weekly(week_key: String, score: int) -> int:
	var records: Dictionary = SaveSystem.data.get("weekly_records", {}).duplicate(true)
	if records.has(week_key): return 0
	var reward := 25
	records[week_key] = {"score":maxi(score, 0), "reward":reward,
			"completed_at":int(Time.get_unix_time_from_system())}
	SaveSystem.data["weekly_records"] = records
	SaveSystem.add_crystals(reward)
	return reward


func can_rematch(area_id: String) -> bool:
	return area_id in SaveSystem.completed_areas()


func ascension_unlocked() -> bool:
	# Preview/prototype players who already earned Ascension keep it when the
	# campaign grows from three realms to five.
	if SaveSystem.max_ascension() > 0:
		return true
	for area_id in GameState.area_ids():
		if area_id not in SaveSystem.completed_areas():
			return false
	return not GameState.area_ids().is_empty()


func max_ascension() -> int:
	return SaveSystem.max_ascension()


func record_ascension_clear(level: int) -> int:
	if not ascension_unlocked():
		return 0
	var unlocked := clampi(maxi(SaveSystem.max_ascension(), level + 1), 1, 10)
	SaveSystem.data["max_ascension"] = unlocked
	SaveSystem.data["selected_ascension"] = clampi(
			int(SaveSystem.data.get("selected_ascension", 0)), 0, unlocked)
	SaveSystem.save()
	return unlocked


func daily_claimed(date_text: String) -> bool:
	return str((SaveSystem.data.get("daily", {}) as Dictionary).get("last_claim", "")) == date_text


## Records a REAL daily result: the depth actually reached and a score built
## from run performance, not hardcoded placeholders.
func complete_daily(date_text: String, depth := 7, run_crystals := 0) -> int:
	if daily_claimed(date_text):
		return 0
	var daily: Dictionary = SaveSystem.data.get("daily", {}).duplicate(true)
	var previous := str(daily.get("last_played", ""))
	daily["streak"] = int(daily.get("streak", 0)) + 1 if previous != date_text else int(daily.get("streak", 0))
	daily["last_claim"] = date_text
	daily["last_played"] = date_text
	daily["best_depth"] = maxi(int(daily.get("best_depth", 0)), maxi(depth, 0))
	daily["score"] = maxi(int(daily.get("score", 0)),
			depth * 100 + run_crystals * 10 + int(daily.streak) * 50)
	SaveSystem.data["daily"] = daily
	SaveSystem.add_crystals(15)
	return 15
