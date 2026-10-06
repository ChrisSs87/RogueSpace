extends Node3D

## Experimental navigation-bake architecture only. It never instantiates
## Fortress6A and it never modifies Enemy.gd or production navigation data.
const SOURCE_GROUP := &"navmesh_source"
const CSG_MESH_SOURCE_GROUP := &"navmesh_csg_mesh_source"
const AGENT_RADIUS := 0.60 # Fortress x=41 audit requires the same added voxel margin.
const AGENT_HEIGHT := 1.80
const CELL_SIZE := 0.05
const CELL_HEIGHT := 0.10
const SPEED_MPS := 2.0
const ARRIVAL_M := 0.35
const MAX_TICKS := 1100
const MIN_CLEARANCE_M := 0.45
const NAV_PROXY_COLLISION_LAYER := 32

@onready var _region: NavigationRegion3D = $NavigationRegion3D
@onready var _enemy: Enemy = $Enemy


func _ready() -> void:
	# Option E: wait long enough for visual CSG construction, then explicitly
	# test only mesh parsing. CSG visual meshes remain unsupported by the
	# NavigationMesh parser in 4.7.2 if this yields zero polygons.
	for _frame in 5:
		await get_tree().process_frame
	var direct_mesh_result := _bake_from_csg_meshes_directly(NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES)
	var direct_both_result := _bake_from_csg_meshes_directly(NavigationMesh.PARSED_GEOMETRY_BOTH)
	print("6A BAKE OPTION E | csg_mesh_entries=%d MESH vertices=%d polygons=%d BOTH vertices=%d polygons=%d result=%s" % [direct_mesh_result.mesh_entries, direct_mesh_result.vertices, direct_mesh_result.polygons, direct_both_result.vertices, direct_both_result.polygons, "PASS" if direct_mesh_result.polygons > 0 and direct_both_result.polygons > 0 else "FAIL"])

	# Option B+C: each source proxy is derived from the original CSG transform
	# and Box size at runtime; it is not duplicate hand-authored geometry.
	_build_static_collider_proxies_from_csg()
	await get_tree().physics_frame
	var proxies_isolated := _proxies_are_isolated_from_gameplay()
	print("6A BAKE PROXY ISOLATION | proxies=%d collision_layer=%d collision_mask=0 isolated=%s" % [_proxy_count(), NAV_PROXY_COLLISION_LAYER, proxies_isolated])
	if not proxies_isolated:
		push_error("6A BAKE PROTOTYPE: a navigation proxy participates in gameplay physics")
		get_tree().quit(1)
		return
	var baked := _bake_from_static_proxies()
	if baked.get_polygon_count() <= 0 or baked.vertices.is_empty():
		push_error("6A BAKE PROTOTYPE: proxy bake produced no navigation surface")
		get_tree().quit(1)
		return
	var map_rid := _region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map_rid, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map_rid, CELL_HEIGHT)
	_region.navigation_mesh = baked
	for _frame in 5:
		await get_tree().physics_frame
	var room_a := Vector3(0, 1, 0)
	var room_b := Vector3(16, 1, 0)
	var path := NavigationServer3D.map_get_path(map_rid, room_a, room_b, true)
	print("6A BAKE OPTION B+C | proxies=%d vertices=%d polygons=%d path_points=%d connected=%s corridor_width=2.70" % [_proxy_count(), baked.vertices.size(), baked.get_polygon_count(), path.size(), path.size() >= 2])
	if path.size() < 2:
		push_error("6A BAKE PROTOTYPE: Room A and Room B are not connected")
		get_tree().quit(1)
		return

	_enemy.set_physics_process(false) # no Enemy AI / no stuck recovery in audit
	var passed := true
	var route_filter := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bake-route-filter="):
			route_filter = argument.trim_prefix("--bake-route-filter=")
	for route in _physical_routes():
		if not route_filter.is_empty() and not String(route.name).contains(route_filter):
			continue
		passed = await _run_physical_route(route) and passed
	if passed:
		print("Stage6A navigation bake prototype: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A navigation bake prototype: FAIL")
		get_tree().quit(1)


func _bake_from_csg_meshes_directly(parsed_geometry_type: NavigationMesh.ParsedGeometryType) -> Dictionary:
	var mesh_entries := 0
	for csg in _all_csg_boxes():
		if csg.has_method("get_meshes"):
			var entries: Variant = csg.call("get_meshes")
			if entries is Array:
				mesh_entries += (entries as Array).size()
			csg.add_to_group(CSG_MESH_SOURCE_GROUP)
	var navmesh := _configured_navmesh(parsed_geometry_type, CSG_MESH_SOURCE_GROUP)
	var source_data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(navmesh, source_data, self, Callable())
	NavigationMeshGenerator.bake_from_source_geometry_data(navmesh, source_data, Callable())
	return {"mesh_entries": mesh_entries, "vertices": navmesh.vertices.size(), "polygons": navmesh.get_polygon_count()}


func _build_static_collider_proxies_from_csg() -> void:
	var root := Node3D.new()
	root.name = "NavigationBakeProxies"
	add_child(root)
	for source in _all_csg_boxes():
		var body := StaticBody3D.new()
		body.name = "%s_Proxy" % source.name
		body.global_transform = source.global_transform
		body.collision_layer = NAV_PROXY_COLLISION_LAYER
		body.collision_mask = 0
		body.add_to_group(SOURCE_GROUP)
		var shape := BoxShape3D.new()
		shape.size = source.size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		# GROUPS_EXPLICIT parses only nodes that belong to the source group;
		# include the shape explicitly rather than relying on child traversal.
		collision.add_to_group(SOURCE_GROUP)
		body.add_child(collision)
		root.add_child(body)


func _bake_from_static_proxies() -> NavigationMesh:
	var navmesh := _configured_navmesh(NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS)
	var source_data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(navmesh, source_data, self, Callable())
	print("6A BAKE PROXY SOURCE vertices=%d indices=%d" % [source_data.get_vertices().size(), source_data.get_indices().size()])
	NavigationMeshGenerator.bake_from_source_geometry_data(navmesh, source_data, Callable())
	return navmesh


func _configured_navmesh(parsed_geometry_type: NavigationMesh.ParsedGeometryType, source_group: StringName = SOURCE_GROUP) -> NavigationMesh:
	var navmesh := NavigationMesh.new()
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	navmesh.geometry_source_group_name = source_group
	navmesh.geometry_parsed_geometry_type = parsed_geometry_type
	navmesh.agent_radius = AGENT_RADIUS
	navmesh.agent_height = AGENT_HEIGHT
	navmesh.agent_max_climb = 0.20
	navmesh.agent_max_slope = 1.0 # flat test floor; Godot requires a positive angle.
	navmesh.cell_size = CELL_SIZE
	navmesh.cell_height = CELL_HEIGHT
	navmesh.filter_walkable_low_height_spans = true
	return navmesh


func _physical_routes() -> Array[Dictionary]:
	return [
		# Room A -> Room B: center, moderate/aggressive diagonals from both sides.
		{"name": "A_TO_B_CENTER", "start": Vector3(0, 1, 0), "target": Vector3(16, 1, 0)},
		{"name": "A_TO_B_LEFT_MOD", "start": Vector3(1, 1, 2.1), "target": Vector3(15, 1, 1.5)},
		{"name": "A_TO_B_LEFT_AGG", "start": Vector3(2.8, 1, 3.1), "target": Vector3(15.5, 1, 2.4)},
		{"name": "A_TO_B_RIGHT_MOD", "start": Vector3(1, 1, -2.1), "target": Vector3(15, 1, -1.5)},
		{"name": "A_TO_B_RIGHT_AGG", "start": Vector3(2.8, 1, -3.1), "target": Vector3(15.5, 1, -2.4)},
		# Mirror all five inputs through both mouths in the reverse direction.
		{"name": "B_TO_A_CENTER", "start": Vector3(16, 1, 0), "target": Vector3(0, 1, 0)},
		{"name": "B_TO_A_LEFT_MOD", "start": Vector3(15, 1, 2.1), "target": Vector3(1, 1, 1.5)},
		{"name": "B_TO_A_LEFT_AGG", "start": Vector3(13.2, 1, 3.1), "target": Vector3(0.5, 1, 2.4)},
		{"name": "B_TO_A_RIGHT_MOD", "start": Vector3(15, 1, -2.1), "target": Vector3(1, 1, -1.5)},
		{"name": "B_TO_A_RIGHT_AGG", "start": Vector3(13.2, 1, -3.1), "target": Vector3(0.5, 1, -2.4)},
	]


func _run_physical_route(route: Dictionary) -> bool:
	_enemy.global_position = route.start
	_enemy.velocity = Vector3.ZERO
	_enemy._navigation_target = Vector3.INF
	_enemy._semantic_navigation_target = Vector3.INF
	_enemy._fallback_next_path_position = Vector3.INF
	await get_tree().physics_frame
	var map_rid := _region.get_navigation_map()
	var projected_start := NavigationServer3D.map_get_closest_point(map_rid, _enemy.global_position)
	var projected_target := NavigationServer3D.map_get_closest_point(map_rid, route.target)
	var path := NavigationServer3D.map_get_path(map_rid, projected_start, projected_target, true)
	_enemy.navigation_agent.target_position = projected_target
	await get_tree().physics_frame
	if path.size() < 2:
		print("6A BAKE ROUTE %s | FAIL path_points=%d" % [route.name, path.size()])
		return false
	var path_index := 0
	while path_index < path.size() and _flat_distance(_enemy.global_position, path[path_index]) <= 0.10:
		path_index += 1
	var min_clearance := _clearance_to_real_walls(_enemy.global_position)
	var min_at := _enemy.global_position
	var max_stationary := 0.0
	var stationary := 0.0
	var recovery_before := _enemy.get_debug_stuck_recovery_count()
	var reached := false
	for _tick in MAX_TICKS:
		var before := _enemy.global_position
		while path_index < path.size() and _flat_distance(_enemy.global_position, path[path_index]) <= 0.12:
			path_index += 1
		var navigation_goal: Vector3 = projected_target if path_index >= path.size() else path[path_index]
		var heading := navigation_goal - _enemy.global_position
		heading.y = 0.0
		if heading.length() > 0.001:
			_enemy.velocity = heading.normalized() * SPEED_MPS
		else:
			_enemy.velocity = Vector3.ZERO
		_enemy.move_and_slide()
		var moved := _enemy.global_position.distance_to(before)
		var clearance := _clearance_to_real_walls(_enemy.global_position)
		if clearance < min_clearance:
			min_clearance = clearance
			min_at = _enemy.global_position
		if _enemy.velocity.length() > 0.05 and moved < 0.002:
			stationary += 1.0 / 60.0
		else:
			stationary = 0.0
		max_stationary = maxf(max_stationary, stationary)
		if _flat_distance(_enemy.global_position, projected_target) <= ARRIVAL_M:
			reached = true
			break
		await get_tree().physics_frame
	var recovery_delta := _enemy.get_debug_stuck_recovery_count() - recovery_before
	var clean := reached and min_clearance >= MIN_CLEARANCE_M and max_stationary < 0.5 and recovery_delta == 0
	var classification := "NAVIGATION CLEAN PASS" if clean else ("RECOVERED PASS" if reached else "FAIL")
	print("6A BAKE ROUTE %s | %s path_points=%d agent_reachable=%s min_clearance=%.3f at=(%.2f,%.2f) max_stationary=%.2f recoveries=%d final_dist=%.2f" % [route.name, classification, path.size(), _enemy.navigation_agent.is_target_reachable(), min_clearance, min_at.x, min_at.z, max_stationary, recovery_delta, _flat_distance(_enemy.global_position, projected_target)])
	return clean


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	delta.y = 0.0
	return delta.length()


func _clearance_to_real_walls(position: Vector3) -> float:
	var closest := INF
	for wall in _all_csg_boxes():
		if not String(wall.get_path()).contains("ArchitectureWalls"):
			continue
		var half := wall.size * 0.5
		var local := wall.to_local(position)
		var dx := maxf(absf(local.x) - half.x, 0.0)
		var dz := maxf(absf(local.z) - half.z, 0.0)
		closest = minf(closest, Vector2(dx, dz).length())
	return closest


func _all_csg_boxes() -> Array[CSGBox3D]:
	var result: Array[CSGBox3D] = []
	_collect_csg(self, result)
	return result


func _collect_csg(node: Node, result: Array[CSGBox3D]) -> void:
	if node is CSGBox3D:
		result.append(node)
	for child in node.get_children():
		_collect_csg(child, result)


func _proxy_count() -> int:
	return get_tree().get_nodes_in_group(SOURCE_GROUP).filter(func(node: Node) -> bool: return node is StaticBody3D).size()


func _proxies_are_isolated_from_gameplay() -> bool:
	for node in get_tree().get_nodes_in_group(SOURCE_GROUP):
		if node is StaticBody3D:
			var body := node as StaticBody3D
			if body.collision_layer != NAV_PROXY_COLLISION_LAYER or body.collision_mask != 0:
				return false
	return true
