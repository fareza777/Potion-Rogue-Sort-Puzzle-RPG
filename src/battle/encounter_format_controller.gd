class_name EncounterFormatController
extends RefCounted
## Small state machine for battle formats. Combat remains owned by BattleManager.

var format := "duel"
var wave := 1
var waves := 1
var progress := 0
var target := 1
var cauldron_hp := 100


func configure(profile: Dictionary) -> void:
	format = str(profile.get("format", "duel"))
	if format not in EncounterDirector.ADVANCED_FORMATS: format = "duel"
	wave = 1
	waves = maxi(int(profile.get("waves", 2 if format == "multi_wave" else 1)), 1)
	progress = 0
	target = 3 if format in ["survival", "protect_cauldron"] else waves
	cauldron_hp = 100


func title() -> String:
	match format:
		"multi_wave": return "TWIN ASSAULT"
		"survival": return "HOLD THE LINE"
		"protect_cauldron": return "WARD THE CAULDRON"
		"elite_contract": return "ELITE CONTRACT"
		_: return "DUEL"


func status_text() -> String:
	match format:
		"multi_wave": return "Wave %d / %d" % [wave, waves]
		"survival": return "Survive attacks  %d / %d" % [progress, target]
		"protect_cauldron": return "Brew wards %d / %d  •  Cauldron %d%%" % [progress, target, cauldron_hp]
		"elite_contract": return "Defeat the empowered guardian"
		_: return "Defeat the enemy"


func on_enemy_defeated() -> String:
	if format == "multi_wave" and wave < waves:
		wave += 1
		return "next_wave"
	return "victory"


func on_enemy_action() -> String:
	if format == "survival":
		progress += 1
		return "victory" if progress >= target else "continue"
	if format == "protect_cauldron":
		cauldron_hp = maxi(cauldron_hp - 25, 0)
		return "defeat" if cauldron_hp <= 0 else "continue"
	return "continue"


func on_potion_completed() -> String:
	if format != "protect_cauldron": return "continue"
	progress += 1
	return "victory" if progress >= target else "continue"


func snapshot() -> Dictionary:
	return {"format":format, "wave":wave, "waves":waves, "progress":progress,
			"target":target, "cauldron_hp":cauldron_hp}


func restore(data: Dictionary) -> void:
	format = str(data.get("format", format)); wave = maxi(int(data.get("wave", wave)), 1)
	waves = maxi(int(data.get("waves", waves)), 1); progress = maxi(int(data.get("progress", 0)), 0)
	target = maxi(int(data.get("target", target)), 1); cauldron_hp = clampi(int(data.get("cauldron_hp", 100)), 0, 100)
