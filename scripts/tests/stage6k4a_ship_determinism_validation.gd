extends Node

const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")

func _ready() -> void:
	var seeds := [67003, 67001, 67007] # SMALL, MEDIUM, LARGE con SHORT
	var dungeon: Node3D = STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 0
	dungeon.initial_seed = seeds[0]
	add_child(dungeon)
	var valid := true
	for seed in seeds:
		await dungeon.regenerate(seed)
		await _await_result(dungeon)
		var first := _snapshot(dungeon)
		await dungeon.regenerate(seed)
		await _await_result(dungeon)
		var second := _snapshot(dungeon)
		var matches: bool = first == second and dungeon.assembly_valid and dungeon.nav_ready
		print("6K.4A DETERMINISM seed=%d match=%s snapshot=%s" % [seed, matches, first])
		valid = valid and matches
	if valid:
		print("Stage6K.4A Ship determinism: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4A Ship determinism: FAIL")
		get_tree().quit(1)


func _await_result(dungeon: Node3D) -> void:
	for _frame in 600:
		if dungeon.nav_ready or not dungeon.assembly_error.is_empty(): return
		await get_tree().physics_frame


func _snapshot(dungeon: Node3D) -> Dictionary:
	var plan: DungeonPlan = dungeon.current_plan
	var links: Array[String] = []
	for source in plan.links:
		var targets: Array[String] = []
		for target in plan.links[source]: targets.append(String(target))
		targets.sort()
		links.append("%s>%s" % [source, ",".join(targets)])
	links.sort()
	var reconnects: Array[String] = []
	for reconnect in plan.reconnections:
		reconnects.append("%s:%s>%s" % [reconnect.id, reconnect.source, reconnect.target])
	reconnects.sort()
	return {"topology": plan.get_topology_signature(), "links": links, "reconnections": reconnects, "assembly": dungeon._assembly_signature}
