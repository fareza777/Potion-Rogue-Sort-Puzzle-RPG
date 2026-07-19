class_name BattlePresentationDirector
extends RefCounted
## Shared cinematic timing language; only transform/opacity animations consume it.


func sequence(event_name: String, reduced_effects: bool) -> Array[String]:
	if reduced_effects: return ["impact", "settle"]
	if event_name in ["potion_complete", "critical", "boss_phase"]:
		return ["anticipation", "impact", "reaction", "settle"]
	return ["impact", "reaction", "settle"]


func duration(event_name: String, reduced_effects: bool) -> float:
	var value := 0.22
	match event_name:
		"critical": value = 0.48
		"potion_complete": value = 0.36
		"boss_phase": value = 0.62
		"hit": value = 0.28
	return value * (0.55 if reduced_effects else 1.0)
