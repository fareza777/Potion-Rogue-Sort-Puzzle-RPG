class_name BoardDifficulty
extends RefCounted
## Shared labels for solver-estimated board complexity.


static func band(estimated_moves: int) -> String:
	if estimated_moves < 0:
		return "unsolved"
	if estimated_moves <= 5:
		return "easy"
	if estimated_moves <= 12:
		return "standard"
	return "hard"
