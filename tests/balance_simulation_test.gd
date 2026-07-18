extends Node
## Deterministic balance-laboratory contracts. The thresholds intentionally live
## beside the sampled production behavior so release validation cannot hide them.

const BalanceLab = preload("res://src/testing/balance_simulator.gd")

const BOARD_SAMPLES := 250
const ENCOUNTER_SAMPLES := 32
const LONG_BOARD_SAMPLES := 5000
const LONG_ENCOUNTER_SAMPLES := 64
const MAX_DEAD_BOARD_RATE := 0.0
const MAX_EARLY_DEFEAT_RATE := 0.75
const MIN_MEAN_MOVES := 1.0
const MAX_MEAN_MOVES := 64.0

var _checks := 0
var _failures := 0
var _board_samples := BOARD_SAMPLES
var _encounter_samples := ENCOUNTER_SAMPLES


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	if "--balance-smoke" in user_args:
		_board_samples = 1
		_encounter_samples = 1
	elif "--balance-long" in user_args:
		_board_samples = LONG_BOARD_SAMPLES
		_encounter_samples = LONG_ENCOUNTER_SAMPLES
		print("Balance long run: %d boards, %d encounter seeds per matrix row" % [
				_board_samples, _encounter_samples])
	_test_board_metrics_are_deterministic()
	_test_board_sweep_has_no_dead_boards()
	_test_encounter_metrics_are_bounded()
	_test_matrix_is_deterministic_and_complete()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_board_metrics_are_deterministic() -> void:
	var first := BalanceLab.simulate_board(1847, "standard")
	var second := BalanceLab.simulate_board(1847, "standard")
	check(first == second and bool(first.get("solved", false))
			and int(first.get("moves", 0)) > 0,
			"identical board seed produces deterministic solved metrics")


func _test_board_sweep_has_no_dead_boards() -> void:
	var dead := 0
	for seed in _board_samples:
		var result := BalanceLab.simulate_board(seed, "standard")
		if not bool(result.get("solved", false)):
			dead += 1
	var dead_rate := float(dead) / float(_board_samples)
	check(dead_rate <= MAX_DEAD_BOARD_RATE,
			"%d-board dead-board rate <= %.2f" % [_board_samples, MAX_DEAD_BOARD_RATE])


func _test_encounter_metrics_are_bounded() -> void:
	var result := BalanceLab.simulate_encounter("slime", "shadow_crypt", 0,
			_encounter_samples)
	check(int(result.get("samples", 0)) == _encounter_samples
			and _bounded_ratio(float(result.get("early_defeat_rate", -1.0)))
			and _bounded_ratio(float(result.get("dead_board_rate", -1.0)))
			and float(result.get("early_defeat_rate", 1.0)) <= MAX_EARLY_DEFEAT_RATE
			and float(result.get("mean_moves", 0.0)) >= MIN_MEAN_MOVES
			and float(result.get("mean_moves", 999.0)) <= MAX_MEAN_MOVES,
			"encounter rates and move mean remain inside recorded thresholds")


func _test_matrix_is_deterministic_and_complete() -> void:
	var areas := GameState.area_ids()
	var ascensions: Array[int] = [0, 5, 10]
	var matrix_seeds := 8 if _board_samples == LONG_BOARD_SAMPLES else (
			1 if _board_samples == 1 else 4)
	var first := BalanceLab.matrix(areas, ascensions, matrix_seeds)
	var second := BalanceLab.matrix(areas, ascensions, matrix_seeds)
	var expected := areas.size() * ascensions.size()
	check(first == second and int(first.get("samples", 0)) == expected
			and _matrix_has_bounded_rates(first),
			"area/ascension matrix is deterministic with bounded ratios")


func _matrix_has_bounded_rates(matrix: Dictionary) -> bool:
	for row in matrix.get("rows", []):
		if not _bounded_ratio(float(row.get("early_defeat_rate", -1.0))) \
				or not _bounded_ratio(float(row.get("dead_board_rate", -1.0))):
			return false
	return true


func _bounded_ratio(value: float) -> bool:
	return value >= 0.0 and value <= 1.0


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
