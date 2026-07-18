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
		"motion_profile": "elastic",
	},
	"skeleton": {
		"sprite": "res://assets/art/enemies/skeleton/skeleton.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 0.92,
		"motion_profile": "brittle",
	},
	"poison_beast": {
		"sprite": "res://assets/art/enemies/poison_beast/poison_beast.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 0.96,
		"motion_profile": "pounce",
	},
	"stone_golem": {
		"sprite": "res://assets/art/enemies/stone_golem/stone_golem.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 1.02,
		"motion_profile": "heavy",
	},
	"dark_mage": {
		"sprite": "res://assets/art/enemies/dark_mage/dark_mage.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 0.94,
		"motion_profile": "caster",
	},
	"blood_slime": {
		"sprite": "res://assets/art/enemies/blood_slime/blood_slime.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 1.04,
		"motion_profile": "elastic",
	},
	"fire_golem": {
		"sprite": "res://assets/art/enemies/fire_golem/fire_golem.png",
		"shadow": "res://assets/art/enemies/slime/cave_slime_shadow.png",
		"scale": 1.1,
		"motion_profile": "inferno",
	},
}

const POTIONS := {
	"red": {"color": Color("ed4b36"), "glow": Color("ff8a3d")},
	"green": {"color": Color("73cf43"), "glow": Color("b7f36b")},
	"blue": {"color": Color("3699ec"), "glow": Color("62c7ff")},
	"purple": {"color": Color("a448e0"), "glow": Color("d879ff")},
}

const UI_ICONS := {
	"hero": "res://assets/art/ui/nav/hero.png",
	"upgrades": "res://assets/art/ui/nav/upgrades.png",
	"home": "res://assets/art/ui/nav/home.png",
	"map": "res://assets/art/ui/nav/map.png",
	"settings": "res://assets/art/ui/nav/settings.png",
	"undo": "res://assets/art/ui/nav/undo.png",
	"mix": "res://assets/art/ui/nav/mix.png",
	"pause": "res://assets/art/ui/nav/pause.png",
	"music": "res://assets/art/ui/controls/icon_music.png",
	"sound": "res://assets/art/ui/controls/icon_sound.png",
	"vibration": "res://assets/art/ui/controls/icon_vibration.png",
}

const BACKGROUNDS := {
	"main_hall": "res://assets/art/backgrounds/main_hall_v2.png",
	"battle": "res://assets/art/backgrounds/shadow_crypt_battle.png",
}


static func enemy(enemy_id: String) -> Dictionary:
	var result := ENEMY_DEFAULT.duplicate(true)
	var override: Dictionary = ENEMIES.get(enemy_id, {})
	result.merge(override, true)
	var data: Dictionary = GameState.enemies.get(enemy_id, {})
	result["motion_profile"] = str(data.get("motion_profile",
			result.get("motion_profile", "elastic")))
	if data.has("sprite"):
		result["sprite"] = str(data.sprite)
		result.erase("atlas")
		result.erase("atlas_cell")
	elif data.has("atlas"):
		result["atlas"] = str(data.atlas)
		result["atlas_cell"] = data.get("atlas_cell", [0, 0])
	if data.has("sprite") or data.has("atlas"):
		var profile := str(data.get("motion_profile", "elastic"))
		var generated_scale := 1.12
		if profile == "caster": generated_scale = 1.18
		elif profile == "heavy": generated_scale = 1.08
		result["scale"] = float(data.get("sprite_scale", generated_scale))
	return result


static func enemy_texture(enemy_id: String) -> Texture2D:
	var config := enemy(enemy_id)
	var atlas_path := str(config.get("atlas", ""))
	if not atlas_path.is_empty() and ResourceLoader.exists(atlas_path):
		var source := load(atlas_path) as Texture2D
		if source == null: return null
		var cell: Array = config.get("atlas_cell", [0, 0])
		var region_width := float(source.get_width()) / 5.0
		var texture := AtlasTexture.new()
		texture.atlas = source
		texture.region = Rect2(float(cell[0]) * region_width,
				float(cell[1]) * float(source.get_height()), region_width,
				float(source.get_height()))
		texture.filter_clip = true
		return texture
	return texture_or_null(str(config.get("sprite", "")))


static func potion(color: String) -> Dictionary:
	return POTIONS.get(color, {
		"color": Color.WHITE,
		"glow": Color.WHITE,
	}).duplicate(true)


static func ui_icon(icon_id: String) -> String:
	return str(UI_ICONS.get(icon_id, ""))


static func background(background_id: String) -> String:
	return str(BACKGROUNDS.get(background_id, ""))


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
	for enemy_id in GameState.enemies:
		for key in ["sprite", "atlas"]:
			var enemy_path := str(GameState.enemies[enemy_id].get(key, ""))
			if not enemy_path.is_empty() and not ResourceLoader.exists(enemy_path):
				result.append(enemy_path)
	for background_id in BACKGROUNDS:
		var path := background(str(background_id))
		if not path.is_empty() and not ResourceLoader.exists(path):
			result.append(path)
	return result
