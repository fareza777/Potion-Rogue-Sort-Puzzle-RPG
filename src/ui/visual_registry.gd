class_name VisualRegistry
extends RefCounted
## Data-driven presentation registry. Gameplay systems consume IDs; UI systems
## ask this registry for optional art and presentation metadata.

const ENEMY_DEFAULT := {
	"sprite": "",
	"shadow": "",
	"scale": 1.0,
	"hit_anchor": Vector2(0.68, 0.42),
	"projectile_anchor": Vector2(0.5, 0.46),
}

const ENEMIES := {
	"slime": {
		"sprite": "res://assets/art/enemies/slime/cave_slime.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 1.0,
		"hit_anchor": Vector2(0.72, 0.42),
		"projectile_anchor": Vector2(0.5, 0.5),
	},
	"skeleton": {"scale": 0.92},
	"poison_beast": {"scale": 0.96},
	"stone_golem": {"scale": 1.02},
	"dark_mage": {"scale": 0.94},
	"blood_slime": {"scale": 1.04},
	"fire_golem": {"scale": 1.1},
}

const POTIONS := {
	"red": {"color": Color("ed4b36"), "glow": Color("ff8a3d")},
	"green": {"color": Color("73cf43"), "glow": Color("b7f36b")},
	"blue": {"color": Color("3699ec"), "glow": Color("62c7ff")},
	"purple": {"color": Color("a448e0"), "glow": Color("d879ff")},
}


static func enemy(enemy_id: String) -> Dictionary:
	var result := ENEMY_DEFAULT.duplicate(true)
	var override: Dictionary = ENEMIES.get(enemy_id, {})
	result.merge(override, true)
	return result


static func potion(color: String) -> Dictionary:
	return POTIONS.get(color, {
		"color": Color.WHITE,
		"glow": Color.WHITE,
	}).duplicate(true)


static func texture_or_null(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func missing_runtime_assets() -> PackedStringArray:
	var result := PackedStringArray()
	for enemy_id in ENEMIES:
		var config := enemy(str(enemy_id))
		for key in ["sprite", "shadow"]:
			var path := str(config.get(key, ""))
			if not path.is_empty() and not ResourceLoader.exists(path):
				result.append(path)
	return result
