# Engine Task 1 Report — Board Analysis and Verified Factory

## Implementation summary

- Added `BoardSolver.analyze(state, max_states)` with solvability, BFS-estimated moves, and visited-state counts; retained `has_solution` as the legacy compatibility wrapper.
- Added `BoardDifficulty` (`easy` through 5 moves, `standard` through 12, otherwise `hard`).
- Added deterministic `BoardFactory.generate` and `BoardFactory.remix`. Both analyze every returned candidate; generation retries within a deterministic budget and selects the verified candidate closest to the requested band. No unverified shuffle is returned.
- Routed `PuzzleBoard.generate_board()` through `BoardFactory` without changing its UI/signal lifecycle. Authored tutorial generation is unchanged.
- Added focused headless coverage for zero-move solved boards, impossible boards, repeatable seeds, 500 verified generated boards, and remix color-multiset preservation.

## RED

Command (the required command, run through a bounded PowerShell capture because Godot does not exit after a scene parse error):

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/board_factory_test.tscn 2>&1
```

Output before implementation (captured after 10 seconds):

```text
SCRIPT ERROR: Parse Error: Static function "analyze()" not found in base "BoardSolver".
SCRIPT ERROR: Parse Error: Identifier "BoardFactory" not declared in the current scope.
ERROR: Failed to load script "res://tests/board_factory_test.gd" with error "Parse error".
```

## GREEN

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/board_factory_test.tscn 2>&1
```

```text
PASS  a solved board reports zero estimated moves
PASS  a full mismatched board reports unsolvable
PASS  identical seeds produce identical verified boards
PASS  five hundred generated boards are solvable and not already complete
PASS  remix preserves the color multiset on a verified board
---
5 checks, 0 failures
```

Regression commands and outputs:

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/logic_test.tscn 2>&1
# 33 checks, 0 failures

& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/board_transform_test.tscn 2>&1
# 4 checks, 0 failures

& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/gameplay_integration_test.tscn 2>&1
# 4 checks, 0 failures

& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/mobile_feedback_regression_test.tscn 2>&1
# 9 checks, 0 failures
```

## Files changed

- `src/puzzle/board_difficulty.gd` (+ Godot `.uid`)
- `src/puzzle/board_factory.gd` (+ Godot `.uid`)
- `src/puzzle/board_solver.gd`
- `src/puzzle/puzzle_board.gd`
- `tests/board_factory_test.gd` (+ Godot `.uid`)
- `tests/board_factory_test.tscn`

## Self-review

- Confirmed `has_solution(raw_state, capacity, max_states)` retains its original API and delegates to the shared analysis path.
- Confirmed the analysis result uses the required keys and returns move depth zero for an already solved state.
- Confirmed normal generation consumes only a factory result and tutorial content remains authored.
- Confirmed `git diff --check` has no whitespace errors and the focused plus required regression suites are clean.

## Concerns

None. Godot must refresh its global script-class cache once after adding the new `class_name` files; this was performed before GREEN testing and does not alter tracked project files.

## Fix Wave — Review Findings

### Changes

- Routed production New Mix through `PuzzleBoard.remix_board()` and `BoardFactory.remix()` while retaining `battle.on_move()`, the player message, encounter checkpoint, and refresh behavior.
- Made `max_states` a hard visited-state bound by checking capacity before admitting each new BFS state.
- Stopped inferring puzzle capacity from current fill height. `BoardSolver.analyze` defaults to the production capacity of 4 and accepts an optional explicit capacity; factory callers pass their configured capacity.
- Made exhausted remix return the unchanged input plus its real analysis and `attempt=-1`, preserving a deterministic, safe result contract instead of `{}`.
- Strengthened the 500-seed property test with an independent `BoardSolver.analyze` call for every returned board and added live `PuzzleBoard`/production-handler routing coverage.

### RED

Command:

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/board_factory_test.tscn 2>&1
```

Expected pre-fix output:

```text
PASS  a solved board reports zero estimated moves
PASS  a full mismatched board reports unsolvable
FAIL  analysis never visits more states than max_states
FAIL  analysis keeps capacity four when no current tube is full
PASS  identical seeds produce identical verified boards
PASS  five hundred generated boards are solvable and not already complete
FAIL  exhausted remix returns a deterministic safe result contract
FAIL  PuzzleBoard New Mix preserves and independently verifies live colors
FAIL  production New Mix routes through remix and retains its move/checkpoint
---
9 checks, 5 failures
SCRIPT ERROR: Invalid access to property or key 'state' on a base object of type 'Dictionary'.
```

The independent 500-board verification passed during RED because it closes a test-trust gap rather than reproducing a separate production failure. Its requested live routing coverage failed as shown above.

### GREEN and required regressions

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/board_factory_test.tscn 2>&1
```

```text
PASS  a solved board reports zero estimated moves
PASS  a full mismatched board reports unsolvable
PASS  analysis never visits more states than max_states
PASS  analysis keeps capacity four when no current tube is full
PASS  identical seeds produce identical verified boards
PASS  five hundred generated boards are solvable and not already complete
PASS  remix preserves the color multiset on a verified board
PASS  exhausted remix returns a deterministic safe result contract
PASS  PuzzleBoard New Mix preserves and independently verifies live colors
PASS  production New Mix routes through remix and retains its move/checkpoint
---
10 checks, 0 failures
```

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/logic_test.tscn 2>&1
# 33 checks, 0 failures; exit 0

& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/board_transform_test.tscn 2>&1
# 4 checks, 0 failures; exit 0

& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/gameplay_integration_test.tscn 2>&1
# 4 checks, 0 failures; exit 0

& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . tests/mobile_feedback_regression_test.tscn 2>&1
# 9 checks, 0 failures; exit 0 on final run
```

### Shutdown diagnostic

Two mobile-feedback runs completed all 9 assertions with zero failures but exited 1 with `WARNING: 6 ObjectDB instances were leaked at exit` and `ERROR: 1 resources still in use at exit`. Read-only process inspection found two stale `board_factory_test.tscn` process pairs created by this fix wave. After stopping only those exact task-owned processes (leaving an unrelated visual-test process untouched), the same mobile command exited 0 with 9 checks and 0 failures.

### Fix-wave self-review

- Every behavior-changing fix had a focused failing test before implementation; the independent-verification addition passed immediately as expected for a coverage-only finding.
- The legacy explicit-capacity `has_solution(state, capacity, max_states)` API is unchanged.
- New Mix preserves the live color multiset and still consumes exactly one battle move and checkpoints the encounter.
- Exhausted remix never exposes an unchecked shuffle and always returns `state`, `analysis`, and `attempt`.
- `git diff --check` reports no whitespace errors. No unrelated files or user changes were modified.

### Fix-wave concerns

None. The transient shutdown diagnostic is recorded above and the final required matrix exited cleanly.
