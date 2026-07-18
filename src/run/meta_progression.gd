class_name MetaProgression
extends RefCounted

const HISTORY_LIMIT := 20


func daily_seed(date_text: String) -> int:
	return absi(("POTION_ROGUE_DAILY:" + date_text).hash()) + 1


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


func complete_daily(date_text: String) -> int:
	if daily_claimed(date_text):
		return 0
	SaveSystem.data["daily"] = {"last_claim": date_text, "best_depth": 7}
	SaveSystem.add_crystals(15)
	return 15
