extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var economy := RemixEconomy.new()
	var free := economy.quote("valid", 0, 0)
	check(bool(free.allowed) and int(free.move_cost) == 1 and int(free.mana_cost) == 0,
			"first standard remix costs one move and no mana")
	var denied := economy.quote("valid", 1, 10)
	check(not bool(denied.allowed) and int(denied.mana_cost) == 20,
			"repeat remix requires mana")
	var emergency := economy.quote("recoverable", 9, 0)
	check(bool(emergency.allowed) and bool(emergency.emergency)
			and int(emergency.mana_cost) == 0, "stuck board recovery is always available")
	economy.commit(emergency)
	check(economy.mix_count == 1, "committed remixes are tracked")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
