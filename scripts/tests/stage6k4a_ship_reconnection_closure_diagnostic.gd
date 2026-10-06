extends Node

## Diagnóstico físico dirigido 6K.4A: ejecuta sólo assembly, sin bake. Permite
## separar "DAG no soportado" de "el kit físico no alcanza ambos endpoints".
const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const ARCHETYPE_DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")

func _ready() -> void:
	var director: DungeonArchetypeDirector = ARCHETYPE_DIRECTOR.new()
	var seeds := [67003, 67001, 67002, 67006, 67008]
	var requested := OS.get_cmdline_user_args()
	if not requested.is_empty(): seeds = [int(requested[0])]
	var valid := true
	var probe: Node3D = STAGE.new()
	probe.archetype_mode = true
	probe.test_archetype_index = 0
	probe.initial_seed = seeds[0]
	add_child(probe)
	await _await_result(probe)
	if requested.size() > 1 and probe.active_template != null:
		# Sólo diagnóstico de capacidad; nunca persiste en el Resource productivo.
		probe.active_template.max_reconnection_route_segments = int(requested[1])
		await probe.regenerate(seeds[0])
		await _await_result(probe)
	for seed in seeds:
		var run := director.create_sector_run(SHIP, seed)
		if seed != seeds[0]:
			await probe.regenerate(seed)
			await _await_result(probe)
		var plan: DungeonPlan = probe.current_plan
		var size_id := run.sector_size_profiles[0].size_id
		var reconnect_trace: Array[Dictionary] = []
		for entry in probe.assembly_trace:
			if String(entry.get("status", "")).begins_with("RECONNECT"):
				reconnect_trace.append(entry)
		var navigation := await _validate_navigation(probe, plan)
		print("6K.4A closure seed=%d size=%s reconnect=%s assembly=%s nav=%s routes=%s checks=%d backtracks=%d error=%s trace=%s" % [seed, size_id, plan.reconnections, probe.assembly_valid, probe.nav_ready, navigation, int(probe.placement_stats.get("candidate_checks", 0)), int(probe.placement_stats.get("backtracks", 0)), probe.assembly_error, reconnect_trace])
		if not probe.assembly_valid:
			_dump_failed_reconnection_geometry(probe, plan)
		valid = valid and probe.assembly_valid and bool(navigation.cargo_forward) and bool(navigation.cargo_reverse)
		if size_id != &"SMALL": valid = valid and bool(navigation.main_route) and bool(navigation.reconnect_route)
	probe.queue_free()
	if valid:
		print("Stage6K.4A Ship reconnection closure: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4A Ship reconnection closure: FAIL")
		get_tree().quit(1)


func _dump_failed_reconnection_geometry(probe: Node3D, plan: DungeonPlan) -> void:
	# Repite sólo el assembly del árbol base: la clausura falla pero el root
	# devuelto conserva los endpoints fijos para diagnosticar el solver.
	var attempt: Dictionary = probe._assemble_plan_attempt(plan, 0)
	var root: Node3D = attempt.get("root", null)
	if root == null: return
	var placed_summary: Array[String] = []
	for child in root.get_children():
		if child is Node3D:
			var module := child as Node3D
			placed_summary.append("%s:%s@(%0.1f,%0.1f)" % [module.name, module.get_meta("module_kind", "?"), module.global_position.x, module.global_position.z])
	placed_summary.sort()
	print("6K.4A BASE TREE %s" % [placed_summary])
	for reconnect in plan.reconnections:
		var source := root.get_node_or_null(NodePath(String(reconnect.source))) as Node3D
		var target := root.get_node_or_null(NodePath(String(reconnect.target))) as Node3D
		if source == null or target == null: continue
		var source_connectors: Array[String] = []
		var target_connectors: Array[String] = []
		for marker in probe._available_connectors(source, "out", {}, 0):
			source_connectors.append("%s p=%s f=%s" % [marker.name, marker.global_position, -marker.global_transform.basis.z])
		for marker in probe._available_connectors(target, "out", {}, 0):
			target_connectors.append("%s p=%s f=%s" % [marker.name, marker.global_position, -marker.global_transform.basis.z])
		print("6K.4A RECONNECT DIAG id=%s source=%s pos=%s bounds=%s target=%s pos=%s bounds=%s delta_xz=%.3f source_free=%s target_free=%s patterns=%s" % [reconnect.id, reconnect.source, source.global_position, probe._world_bounds(source), reconnect.target, target.global_position, probe._world_bounds(target), Vector2(source.global_position.x, source.global_position.z).distance_to(Vector2(target.global_position.x, target.global_position.z)), source_connectors, target_connectors, probe._reconnection_route_patterns()])
		_offline_reconnection_search(probe, reconnect, root, source, target)
	root.queue_free()


func _offline_reconnection_search(probe: Node3D, reconnect: Dictionary, root: Node3D, source: Node3D, target: Node3D) -> void:
	# Busca sólo para diagnóstico: no toca el template ni el solver productivo.
	var occupied: Dictionary = {}
	for child in root.get_children():
		if child is Node3D: occupied[StringName(child.name)] = child
	var source_markers: Array[Marker3D] = probe._available_connectors(source, "out", {}, 0)
	var target_markers: Array[Marker3D] = probe._available_connectors(target, "out", {}, 0)
	var patterns := _diagnostic_route_patterns(10, 4)
	for source_marker in source_markers:
		for target_marker in target_markers:
			var found: Dictionary = {}
			var checks := 0
			for pattern in patterns:
				var route: Array[Dictionary] = []
				var stats := {"candidate_checks": 0}
				if probe._place_reconnection_route_recursive(reconnect.id, reconnect.source, reconnect.target, root, pattern, 0, source_marker, target_marker, occupied, route, stats):
					checks += int(stats.candidate_checks)
					var positions: Array[String] = []
					for segment in route:
						var module := segment.module as Node3D
						positions.append("%s@(%0.1f,%0.1f)" % [segment.role, module.global_position.x, module.global_position.z])
					for segment in route:
						var placed := segment.module as Node3D
						root.remove_child(placed)
						placed.free()
					found = {"pattern": pattern, "segments": pattern.size(), "turns": _count_turns(pattern), "positions": positions, "checks": checks}
					break
				checks += int(stats.candidate_checks)
			print("6K.4A OFFLINE ROUTE %s->%s result=%s" % [source_marker.name, target_marker.name, found if not found.is_empty() else {"result": "none through 10 segments / 4 turns", "checks": checks}])


func _diagnostic_route_patterns(max_segments: int, max_turns: int) -> Array[Array]:
	var result: Array[Array] = []
	for length in range(1, max_segments + 1):
		_build_diagnostic_patterns([], length, max_turns, result)
	return result


func _build_diagnostic_patterns(prefix: Array[StringName], target_length: int, max_turns: int, output: Array[Array]) -> void:
	if prefix.size() == target_length:
		if prefix.back() == &"CORRIDOR": output.append(prefix.duplicate())
		return
	for role in [&"CORRIDOR", &"TURN_LEFT", &"TURN_RIGHT"]:
		if prefix.is_empty() and role != &"CORRIDOR": continue
		if not prefix.is_empty() and prefix.back() != &"CORRIDOR" and role != &"CORRIDOR": continue
		var next: Array[StringName] = prefix.duplicate()
		next.append(role)
		if _count_turns(next) > max_turns: continue
		_build_diagnostic_patterns(next, target_length, max_turns, output)


func _count_turns(pattern: Array) -> int:
	var count := 0
	for role in pattern:
		if role != &"CORRIDOR": count += 1
	return count


func _await_result(probe: Node3D) -> void:
	for _frame in 400:
		if probe.nav_ready or not probe.assembly_error.is_empty(): return
		await get_tree().physics_frame


func _validate_navigation(probe: Node3D, plan: DungeonPlan) -> Dictionary:
	var result := {"cargo_forward": false, "cargo_reverse": false, "main_route": true, "reconnect_route": true}
	if not probe.nav_ready or probe.nav_region == null or plan == null: return result
	var map: RID = probe.nav_region.get_navigation_map()
	var root := probe.get_node_or_null("AssembledModules") as Node3D
	var cargo := _semantic_node(plan, &"CARGO_HOLD")
	if root == null or cargo.is_empty(): return result
	var start := _nav_point(map, probe.start_point)
	var cargo_node := root.get_node_or_null(NodePath(String(cargo))) as Node3D
	if cargo_node == null: return result
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
		var route_nodes: Array[Node3D] = []
		for child in root.get_children():
			if String(child.name).begins_with("%s_ROUTE_" % reconnect.id): route_nodes.append(child as Node3D)
		route_nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
		if source == null or target == null or main_node == null or route_nodes.is_empty():
			result.main_route = false; result.reconnect_route = false; continue
		var source_point := _nav_point(map, source.global_position + Vector3(0, 0.9, 0))
		var target_point := _nav_point(map, target.global_position + Vector3(0, 0.9, 0))
		var main_point := _nav_point(map, main_node.global_position + Vector3(0, 0.9, 0))
		var route_point := _nav_point(map, route_nodes[route_nodes.size() / 2].global_position + Vector3(0, 0.9, 0))
		result.main_route = bool(result.main_route) and await _walk_chain(map, [source_point, main_point, target_point])
		result.reconnect_route = bool(result.reconnect_route) and await _walk_chain(map, [source_point, route_point, target_point])
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
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	add_child(body)
	body.global_position = Vector3(start.x, 0.9, start.z)
	var path_index := 1
	for _tick in 900:
		while path_index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[path_index].x, path[path_index].z)) < 0.7: path_index += 1
		var goal: Vector3 = target if path_index >= path.size() else path[path_index]
		var direction := goal - body.global_position
		direction.y = 0.0
		body.velocity = direction.normalized() * 25.0 if direction.length() > 0.01 else Vector3.ZERO
		body.move_and_slide()
		if Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) < 0.35:
			body.queue_free()
			return true
		await get_tree().physics_frame
	body.queue_free()
	return false
