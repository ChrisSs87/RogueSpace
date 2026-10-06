extends Node

const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const ARCHETYPE_DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := int(args[0]) if args.size() > 0 else 67001
	var count := int(args[1]) if args.size() > 1 else 2
	var dungeon: Node3D = STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 0
	dungeon.initial_seed = first_seed
	add_child(dungeon)
	await _await_result(dungeon)
	var valid := true
	var director: DungeonArchetypeDirector = ARCHETYPE_DIRECTOR.new()
	for seed in range(first_seed, first_seed + count):
		if seed != first_seed:
			await dungeon.regenerate(seed)
			await _await_result(dungeon)
		var run := director.create_sector_run(SHIP, seed)
		var report := await _validate_run(dungeon, run)
		valid = valid and bool(report.valid)
		print("6K.4A FINAL seed=%d %s" % [seed, report])
	if valid:
		print("Stage6K.4A Ship physical batch %d-%d: PASS" % [first_seed, first_seed + count - 1])
		get_tree().quit(0)
	else:
		push_error("Stage6K.4A Ship physical batch %d-%d: FAIL" % [first_seed, first_seed + count - 1])
		get_tree().quit(1)


func _await_result(dungeon: Node3D) -> void:
	for _frame in 600:
		if dungeon.nav_ready or not dungeon.assembly_error.is_empty(): return
		await get_tree().physics_frame


func _validate_run(dungeon: Node3D, run: DungeonSectorRun) -> Dictionary:
	var plan: DungeonPlan = dungeon.current_plan
	var result := {"valid": false, "size": run.sector_size_profiles[0].size_id, "tree_modules": 0, "logical_reconnections": 0, "physical_reconnections": 0, "aux_segments": 0, "turn_left": 0, "turn_right": 0, "route_standard": 0, "route_short": 0, "route_turn_left": 0, "route_turn_right": 0, "candidates": int(dungeon.placement_stats.get("candidate_checks", 0)), "backtracks": int(dungeon.placement_stats.get("backtracks", 0)), "assembly_ms": dungeon.assembly_elapsed_ms, "proxies": dungeon.proxies, "nav": dungeon.nav_ready, "cargo_forward": false, "cargo_reverse": false, "main_route": true, "reconnect_route": true, "integrity": false}
	if plan == null or not plan.is_valid() or not dungeon.assembly_valid or not dungeon.nav_ready or dungeon.nav_region == null:
		result.error = dungeon.assembly_error
		return result
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	if root == null: return result
	result.tree_modules = plan.module_ids.size() - plan.reconnection_nodes.size()
	result.logical_reconnections = plan.reconnections.size()
	var route_nodes: Dictionary = {}
	var route_definitions: Dictionary = {}
	for entry in dungeon.assembly_trace:
		if entry.get("status", "") == "RECONNECT_ROUTE_PLACED":
			route_definitions[StringName(entry.get("id", &""))] = String(entry.get("definition", ""))
	for child in root.get_children():
		var kind: StringName = child.get_meta("module_kind", &"")
		if kind == &"TURN_LEFT": result.turn_left += 1
		if kind == &"TURN_RIGHT": result.turn_right += 1
		var name_text := String(child.name)
		for reconnect in plan.reconnections:
			if name_text.begins_with("%s_ROUTE_" % reconnect.id):
				if not route_nodes.has(reconnect.id): route_nodes[reconnect.id] = []
				route_nodes[reconnect.id].append(child as Node3D)
				result.aux_segments += 1
				var definition_id := String(route_definitions.get(StringName(child.name), ""))
				if definition_id == "ship_corridor": result.route_standard += 1
				elif definition_id == "ship_corridor_short": result.route_short += 1
				elif kind == &"TURN_LEFT": result.route_turn_left += 1
				elif kind == &"TURN_RIGHT": result.route_turn_right += 1
	for reconnect in plan.reconnections:
		if route_nodes.has(reconnect.id) and not (route_nodes[reconnect.id] as Array).is_empty(): result.physical_reconnections += 1
	var map: RID = dungeon.nav_region.get_navigation_map()
	var cargo := _semantic_node(plan, &"CARGO_HOLD")
	var cargo_node := root.get_node_or_null(NodePath(String(cargo))) as Node3D
	if cargo_node != null:
		var start := _nav_point(map, dungeon.start_point)
		var cargo_point := _nav_point(map, cargo_node.global_position + Vector3(0, 0.9, 0))
		result.cargo_forward = await _walk(map, start, cargo_point)
		result.cargo_reverse = await _walk(map, cargo_point, start)
	for reconnect in plan.reconnections:
		var source := root.get_node_or_null(NodePath(String(reconnect.source))) as Node3D
		var target := root.get_node_or_null(NodePath(String(reconnect.target))) as Node3D
		var main_id: StringName = &""
		for child in plan.links.get(reconnect.source, []):
			if not plan.reconnection_nodes.has(child): main_id = child; break
		var main_node := root.get_node_or_null(NodePath(String(main_id))) as Node3D
		var segments: Array = route_nodes.get(reconnect.id, [])
		segments.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
		if source == null or target == null or main_node == null or segments.is_empty():
			result.main_route = false; result.reconnect_route = false; continue
		var a := _nav_point(map, source.global_position + Vector3(0, 0.9, 0))
		var b := _nav_point(map, target.global_position + Vector3(0, 0.9, 0))
		result.main_route = bool(result.main_route) and await _walk_chain(map, [a, _nav_point(map, main_node.global_position + Vector3(0, 0.9, 0)), b])
		result.reconnect_route = bool(result.reconnect_route) and await _walk_chain(map, [a, _nav_point(map, (segments[segments.size() / 2] as Node3D).global_position + Vector3(0, 0.9, 0)), b])
	var semantic_ids: Dictionary = {}
	for location in plan.semantic_locations:
		if semantic_ids.has(location.node_id): result.duplicate_semantic = true
		semantic_ids[location.node_id] = true
	var clean_roots := 0
	for child in dungeon.get_children():
		if child.name == "AssembledModules": clean_roots += 1
	var seams_clean: bool = dungeon._seam_results.size() > 0 and not dungeon.assembly_trace.any(func(entry): return entry.get("status", "") in ["PLACED", "RECONNECT_ROUTE_PLACED"] and not (entry.get("conflicts", []) as Array).is_empty())
	result.integrity = clean_roots == 1 and not bool(result.get("duplicate_semantic", false)) and int(result.physical_reconnections) == int(result.logical_reconnections) and seams_clean
	result.valid = bool(result.cargo_forward) and bool(result.cargo_reverse) and bool(result.main_route) and bool(result.reconnect_route) and bool(result.integrity)
	return result


func _semantic_node(plan: DungeonPlan, semantic_id: StringName) -> StringName:
	for location in plan.semantic_locations:
		if location.definition.semantic_id == semantic_id: return location.node_id
	return &""

func _nav_point(map: RID, point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map, point)

func _walk_chain(map: RID, points: Array) -> bool:
	for index in range(points.size() - 1):
		if not await _walk(map, points[index], points[index + 1]): return false
	return true


func _walk(map: RID, start: Vector3, target: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(map, start, target, true)
	if path.size() < 2: return false
	var body := CharacterBody3D.new(); var collision := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4; capsule.height = 1.8; collision.shape = capsule; body.add_child(collision); add_child(body)
	body.global_position = Vector3(start.x, 0.9, start.z)
	var path_index := 1
	for _tick in 900:
		while path_index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[path_index].x, path[path_index].z)) < 0.7: path_index += 1
		var goal: Vector3 = target if path_index >= path.size() else path[path_index]
		var direction := goal - body.global_position; direction.y = 0.0
		body.velocity = direction.normalized() * 25.0 if direction.length() > 0.01 else Vector3.ZERO
		body.move_and_slide()
		if Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) < 0.35:
			body.queue_free(); return true
		await get_tree().physics_frame
	body.queue_free(); return false
