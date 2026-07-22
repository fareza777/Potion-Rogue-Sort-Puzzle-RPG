class_name GuideContent
extends RefCounted
## Authoritative, presentation-ready guide copy. Dynamic values are read from
## the same JSON-backed GameState dictionaries used by combat.

const POTION_COLORS := {
	"red": "ff5548", "green": "55df72", "blue": "4ba8ff", "purple": "b85cff",
}


static func sections() -> Array[Dictionary]:
	return [
		{"id":"basics", "title":"BASICS", "icon":"FLASK",
			"body":"Tap a source flask, then tap an empty flask or one whose top color matches. Only the connected top layers pour. Complete four matching layers to brew instantly. Red damages, Green heals, Blue grants Shield, and Purple applies Poison. Undo restores the previous pour and enemy countdown. New Mix costs one move; its first normal use is free, later uses cost Mana, and a truly stuck board can always recover.",
			"cards":_potion_cards()},
		{"id":"reactions", "title":"REACTIONS", "icon":"REACT",
			"body":"The three colored dots are the last three completed potion essences in your Reaction Chamber. They are history, not extra moves. Order matters: Red then Purple differs from Purple then Red. When the latest two or three essences match a formula, its Alchemy Reaction activates immediately and grants Ultimate charge.",
			"cards":_reaction_cards()},
		{"id":"skills", "title":"SKILLS", "icon":"RUNE",
			"body":"Every completed potion generates Mana. Mana pays for your hero's active skill; its exact cost and cooldown depend on the selected kit. Reactions separately build Ultimate charge. At 100%, the Ultimate button lights up and unleashes the kit's strongest effect.",
			"cards":kit_cards()},
		{"id":"battle", "title":"BATTLE", "icon":"SWORD",
			"body":"Every successful pour spends one move and advances the enemy intent countdown. Read NEXT before pouring. Shield absorbs incoming damage, Armor reduces direct damage, and Poison bypasses Armor. Objectives may reward a different plan than simply rushing damage.",
			"cards":[
				{"title":"ENEMY INTENT", "copy":"Shows the next action, exact power, and pours remaining. When it reaches zero, the enemy acts.", "accent":"ff9a68"},
				{"title":"DEFENSE", "copy":"Shield is temporary protection. Armor belongs to the target and reduces direct hits. Poison ignores Armor.", "accent":"69bfff"},
				{"title":"TURN TOOLS", "copy":"Undo reverses a pour. New Mix replaces the board and consumes one move. Pause saves the exact battle state.", "accent":"f2cc72"},
			]},
		{"id":"expedition", "title":"EXPEDITION", "icon":"MAP",
			"body":"Each run procedurally generates hidden routes, themed enemies, events, shops, campfires, treasure, and a boss. Only glowing connected nodes are reachable. Progress is checkpointed automatically; Continue returns to the exact unresolved map or battle.",
			"cards":[
				{"title":"HIDDEN ROUTES", "copy":"Future encounters remain concealed until reached, so choose by node type and risk rather than foreknowledge.", "accent":"ba8cff"},
				{"title":"BUILD A RUN", "copy":"Relics, upgrades, catalysts, and kit identity change which potion sequences are strongest.", "accent":"72df99"},
				{"title":"SAVE & EXIT", "copy":"Pause and Save & Exit preserves the battle. Abandon ends the run and banks only the documented portion of rewards.", "accent":"70d8ff"},
			]},
	]


static func section(id: String) -> Dictionary:
	for item in sections():
		if str(item.get("id", "")) == id:
			return item.duplicate(true)
	return sections()[0].duplicate(true)


static func kit_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var ids: Array[String] = []
	for id in GameState.kits: ids.append(str(id))
	ids.sort()
	for id in ids:
		var kit: Dictionary = GameState.kits.get(id, {})
		var active := str(kit.get("active", "active_skill"))
		var ultimate := str(kit.get("ultimate_name", kit.get("ultimate", "Ultimate")))
		cards.append({
			"id":id, "name":str(kit.get("name", id.replace("_", " ").capitalize())),
			"title":str(kit.get("name", id.replace("_", " ").capitalize())).to_upper(),
			"active":active, "cost":int(kit.get("cost", 0)),
			"cooldown":int(kit.get("cooldown", 0)), "ultimate":ultimate,
			"copy":"%s costs %d Mana and has a %d-potion cooldown. Ultimate: %s. %s" % [
				active.replace("_", " ").capitalize(), int(kit.get("cost", 0)),
				int(kit.get("cooldown", 0)), ultimate,
				_reaction_identity(kit)],
			"accent":"d99aff",
		})
	return cards


static func _potion_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for id in ["red", "green", "blue", "purple"]:
		var potion: Dictionary = GameState.potions.get(id, {})
		cards.append({"title":str(potion.get("name", id.capitalize())).to_upper(),
			"copy":str(potion.get("description", "Complete four matching layers.")),
			"accent":POTION_COLORS[id], "essences":[id]})
	return cards


static func _reaction_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var ids: Array[String] = []
	for id in GameState.combos: ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return (GameState.combos[a].get("pattern", []) as Array).size() < \
				(GameState.combos[b].get("pattern", []) as Array).size())
	for id in ids:
		var combo: Dictionary = GameState.combos[id]
		cards.append({"title":str(combo.get("name", id)).to_upper(),
			"copy":str(combo.get("description", "Complete the formula in order.")),
			"accent":"d99aff", "essences":combo.get("pattern", []).duplicate()})
	return cards


static func _reaction_identity(kit: Dictionary) -> String:
	var hooks: Array = kit.get("reaction_hooks", [])
	if hooks.is_empty(): return "No reaction modifier."
	return str((hooks[0] as Dictionary).get("copy", "Reactions support this kit."))
