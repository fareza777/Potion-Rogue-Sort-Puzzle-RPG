# Engine Task 2 — Deterministic balance laboratory

## Scope

- Added `BalanceSimulator` with deterministic board, encounter, and matrix APIs.
- Added a headless balance scene with explicit balance thresholds.
- Added opt-in `-RunBalance` release validation; it runs automatically when `CI` is `true` or `1`.

## RED → GREEN evidence

### RED

Command run before `BalanceSimulator` existed:

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --scene 'res://tests/balance_simulation_test.tscn'
```

Result: the scene could not load its missing `BalanceSimulator` dependency and never reached its test-owned `get_tree().quit`; the process was stopped after the 60-second runner timeout. The console only flushed the Godot banner before termination. This is the expected missing-class RED state; the test did not falsely pass.

### GREEN

Focused smoke command:

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Potion Rogue Sort Puzzle RPG\.worktrees\five-realm-redesign' --scene 'res://tests/balance_simulation_test.tscn' -- --balance-smoke
```

Result: exit 0 in 28.8s; 4 checks, 0 failures.

Normal balance command:

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Potion Rogue Sort Puzzle RPG\.worktrees\five-realm-redesign' --scene 'res://tests/balance_simulation_test.tscn'
```

Result: exit 0 in 50.0s; 4 checks, 0 failures.

## Long local matrix

Command:

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Potion Rogue Sort Puzzle RPG\.worktrees\five-realm-redesign' --scene 'res://tests/balance_simulation_test.tscn' -- --balance-long
```

Result: exit 0 in **359.9s**.

- 5,000 standard-band board samples; `dead_board_rate <= 0.00` passed (0 dead boards).
- 64 encounter seeds for the slime threshold sample.
- Deterministic boss matrix over every authored area × Ascension 0, 5, and 10; 8 seeds per row, evaluated twice for equality.
- Thresholds in `tests/balance_simulation_test.gd`:
  - `MAX_DEAD_BOARD_RATE = 0.0`
  - `MAX_EARLY_DEFEAT_RATE = 0.75`
  - `MIN_MEAN_MOVES = 1.0`
  - `MAX_MEAN_MOVES = 64.0`
  - all reported rates must remain in `[0.0, 1.0]`.
- Validator ceiling: `MaxBalanceSeconds = 900`; the measured long run is below it.

The simulator invokes `BoardFactory.generate(seed, band)` for every requested seed. It memoizes only the deterministic legal-pour/solver playthrough by generated layout, which reduces repeated solver work without bypassing production board generation.

## Regression commands

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Potion Rogue Sort Puzzle RPG\.worktrees\five-realm-redesign' --scene 'res://tests/board_factory_test.tscn'
```

Result: exit 0 in 79.0s; 10 checks, 0 failures.

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Potion Rogue Sort Puzzle RPG\.worktrees\five-realm-redesign' --scene 'res://tests/encounter_test.tscn'
```

Result: exit 0 in 2.6s; 83 checks, 0 failures.

```powershell
& 'C:\Potion Rogue Sort Puzzle RPG\.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'C:\Potion Rogue Sort Puzzle RPG\.worktrees\five-realm-redesign' --scene 'res://tests/seed_simulation_test.tscn'
```

Result: exit 0 in 3.6s; 2,011 checks, 0 failures.

```powershell
& '.\tools\validate_release.ps1' -ProjectRoot '.'
```

Result: exit 0 in 2.1s; release budgets passed. (The long balance path was exercised directly above.)

## Files

- `src/testing/balance_simulator.gd`
- `src/testing/balance_simulator.gd.uid`
- `tests/balance_simulation_test.gd`
- `tests/balance_simulation_test.gd.uid`
- `tests/balance_simulation_test.tscn`
- `tools/validate_release.ps1`

## Self-review

- The board heuristic selects only legal pours and accepts only moves that reduce the production solver distance.
- All simulation RNG is local and explicitly seeded; no global `randf`, `RunState`, or `SaveSystem` mutation is used.
- Encounter metrics use authored enemy intents, threat budgets, potion effects, armor, poison, shields, crits, and Ascension scaling in local dictionaries.
- The validator stays fast locally unless `-RunBalance` is supplied; CI forces the same long path.
- `git diff --check` passed.

## Concerns

- The encounter laboratory intentionally models combat state locally to guarantee save isolation. Board hazards that require a live `PuzzleBoard` UI object (locks/corruption) are represented by the legal-pour core rather than replayed as UI mutations, so this is a deterministic balance regression lab, not a full battle-screen automation test.
- The initial missing-class RED run did not flush a parser diagnostic before its timeout; its failure was established by the scene not loading/reaching the test quit path. Subsequent GREEN runs use the same scene and pass.
