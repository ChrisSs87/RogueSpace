extends Node3D

func _ready() -> void:
	var dungeon: Node3D = $Stage6GProceduralPrototype
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	var first_seed: int = dungeon.seed
	var first_signature: String = dungeon.get_assembly_signature()
	var first_topology: String = dungeon.get_topology_signature()
	var signatures: Dictionary = {first_topology: true}
	var physically_validated: Dictionary = {}
	physically_validated[first_topology] = await _walk_required(dungeon)
	var reports: Array[String] = []
	reports.append(_layout_report(dungeon))
	var counts_ok := true
	var nav_ok := true
	var syncing_lifecycle_ok := true
	for offset in range(1, 20):
		await dungeon.regenerate(first_seed + offset)
		var counts: Dictionary = dungeon.get_runtime_counts()
		counts_ok = counts_ok and counts.modules == dungeon.module_count and counts.proxies == dungeon.proxies and counts.regions == 1 and dungeon.get_node_or_null("AssembledModules") != null and dungeon.get_node_or_null("NavigationBakeProxies") != null
		syncing_lifecycle_ok = syncing_lifecycle_ok and counts.sync_state == "OK" and int(counts.sync_cycles) == offset + 1 and int(counts.sync_attempts) > 0
		nav_ok = nav_ok and dungeon.nav_ready
		var signature: String = dungeon.get_topology_signature()
		signatures[signature] = true
		reports.append(_layout_report(dungeon))
		if physically_validated.size() < 5 and not physically_validated.has(signature):
			physically_validated[signature] = await _walk_required(dungeon)
	await dungeon.regenerate(first_seed)
	var reproducible: bool = dungeon.get_assembly_signature() == first_signature and dungeon.get_topology_signature() == first_topology and dungeon.nav_ready
	var physical := physically_validated.size() >= 5
	for result in physically_validated.values():
		physical = physical and bool(result)
	var passed: bool = signatures.size() >= 5 and counts_ok and nav_ok and syncing_lifecycle_ok and reproducible and physical
	print("6G.2 topology seeds=20 unique_topologies=%d physical_layouts=%d counts=%s nav=%s syncing=%s reproducible=%s physical=%s" % [signatures.size(), physically_validated.size(), counts_ok, nav_ok, syncing_lifecycle_ok, reproducible, physical])
	for report in reports:
		print(report)
	if passed:
		print("Stage6G regeneration: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6G regeneration: FAIL")
		get_tree().quit(1)


func _layout_report(dungeon: Node3D) -> String:
	var metrics: Dictionary = dungeon.get_topology_metrics()
	var counts: Dictionary = dungeon.get_runtime_counts()
	return "6G.2 layout seed=%d topology=%s modules=%d turns=%d rooms=%d corridors=%d branches=%d definitions=%s placement(candidates=%d alternates=%d retry=%d)" % [dungeon.seed, dungeon.get_topology_signature(), dungeon.module_count, int(metrics.turns), int(metrics.rooms), int(metrics.corridors), int(metrics.branches), dungeon.get_selected_module_definitions(), int(counts.placement_candidates), int(counts.placement_alternates), int(counts.placement_attempt)]


func _walk_required(dungeon: Node3D) -> bool:
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var finish := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	var forward := await _walk(NavigationServer3D.map_get_path(map, start, finish, true), start, finish)
	var reverse := await _walk(NavigationServer3D.map_get_path(map, finish, start, true), finish, start)
	var branches_ok := true
	for branch in dungeon.get_branch_points():
		var branch_nav := NavigationServer3D.map_get_closest_point(map, branch)
		branches_ok = branches_ok and await _walk(NavigationServer3D.map_get_path(map, start, branch_nav, true), start, branch_nav)
	return forward and reverse and branches_ok


func _walk(path: PackedVector3Array, start: Vector3, target: Vector3) -> bool:
	if path.size() < 2:
		return false
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .4
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	add_child(body)
	body.global_position = Vector3(start.x, .9, start.z)
	var index := 1
	for tick in 1000:
		# El bake de 5 cm entrega puntos densos (~0.4 m); con el paso acelerado
		# del harness, el umbral debe consumir el siguiente punto antes de que
		# quede detrás del cuerpo. No altera la física ni usa recovery.
		while index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[index].x, path[index].z)) < .8:
			index += 1
		var goal: Vector3 = target if index >= path.size() else path[index]
		var flat := goal - body.global_position
		flat.y = 0
		# Harness físico, no balance de gameplay: acelera sólo para mantener los
		# tres recorridos dentro del límite de ejecución headless.
		body.velocity = flat.normalized() * 30.0 if flat.length() > .01 else Vector3.ZERO
		body.move_and_slide()
		if Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) < .35:
			body.queue_free()
			return true
		await get_tree().physics_frame
	body.queue_free()
	return false
