extends Node
## Guards the crash that shipped in 1.7.9: FxPool retires the oldest effect once
## 48 are live, and a victory burst alone spawns ~39 nodes. Anything still in
## flight was freed underneath its animation. The tween kept running because it
## was bound to BattleFx rather than to the node it animated, so the next frame
## drove a lambda whose captured Line2D had been freed — logcat showed
## "Lambda capture at index 0 was freed. Passed null instead." and then a
## SIGSEGV on the GL thread inside GodotLib_step.
##
## The rule these checks hold: an effect's tween must die with the effect.

var checks := 0
var failures := 0


func _ready() -> void:
	var fx := BattleFx.new()
	add_child(fx)
	await get_tree().process_frame

	fx.projectile(Vector2(20.0, 20.0), Vector2(300.0, 400.0))
	await get_tree().process_frame

	var animated: Array[Node] = []
	for child in fx.get_children():
		if child is Line2D or child is Polygon2D:
			animated.append(child)
	check(animated.size() >= 2, "a projectile spawns both an orb and a trail")

	var live_before := get_tree().get_processed_tweens().size()
	check(live_before > 0, "the projectile animates through a live tween")

	# Exactly what the pool does when a victory burst overflows the budget.
	for node in animated:
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	for node in animated:
		check(not is_instance_valid(node), "the retired effect is really gone")
	check(get_tree().get_processed_tweens().size() < live_before,
			"retiring the animated nodes kills their tween instead of leaving "
			+ "one that drives a freed capture")

	# The same property has to hold for the pooled helpers, which spawn the bulk
	# of the nodes that push the pool over its budget in the first place.
	for helper in ["_ring", "_burst"]:
		var baseline := get_tree().get_processed_tweens().size()
		if helper == "_ring":
			fx.call(helper, Vector2(10.0, 10.0), Color.WHITE, 24.0)
		else:
			fx.call(helper, Vector2(10.0, 10.0), Color.WHITE, 4, 30.0)
		await get_tree().process_frame
		var spawned: Array[Node] = []
		for child in fx.get_children():
			if (child is Line2D or child is Polygon2D) and not child.is_queued_for_deletion():
				spawned.append(child)
		check(get_tree().get_processed_tweens().size() > baseline,
				"%s() animates its effect" % helper)
		for node in spawned:
			node.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		check(get_tree().get_processed_tweens().size() <= baseline,
				"%s() leaves no tween behind once its effect is retired" % helper)

	# The pool's budget is what forces the retirement, so it must stay bounded.
	check(FxPool.MAX_ACTIVE > 0, "the effect pool keeps a hard budget")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
