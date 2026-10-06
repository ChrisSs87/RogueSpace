extends Node3D

## Diagnostic-only harness. It never changes Fortress6A's saved scene or its
## active manual navigation; legacy regions are disabled only in this runtime
## instance while the isolated B+C bake is inspected.
const SOURCE_GROUP := &"x41_bake_proxy_source"
const PROXY_LAYER := 32
const TEST_START := Vector3(38.5, 1.0, 0.55)
const TEST_TARGET := Vector3(44.5, 1.0, 0.55)
const CAPSULE_RADIUS := 0.40
const CAPSULE_HEIGHT := 1.80
const SPEED := 2.0
const ARRIVAL := 0.35

func _ready() -> void:
	var fortress: Node3D = $MainFortress6A/Fortress6A
	for region_name in ["NavigationRegion3D", "NavigationEntryBridge"]:
		var legacy := fortress.get_node_or_null(region_name) as NavigationRegion3D
		if legacy != null:
			legacy.enabled = false
		# Removing the resource in this transient instance makes the test map
		# unambiguously B+C-only even if region disabling is applied next tick.
		legacy.navigation_mesh = null
	for _frame in 5:
		await get_tree().physics_frame
	var proxies := _create_proxies(fortress)
	await get_tree().physics_frame
	_audit_proxy_match(fortress, proxies)
	var radius := _arg_float("--radius=", 0.55)
	var cell := _arg_float("--cell=", 0.05)
	var result := await _run_bake_case(fortress, proxies, radius, cell)
	print("X41 DIAG RESULT radius=%.3f cell=%.3f nav_vertices=%d nav_polygons=%d edge_clearance=%.3f raw_clearance=%.3f requested_physical=%.3f projected_physical=%.3f projection_gap=%.3f raw_safe=%s projected_physical_safe=%s" % [radius, cell, result.vertices, result.polygons, result.edge_clearance, result.raw_clearance, result.physical_clearance, result.projected_physical_clearance, result.projection_gap, result.raw_clearance >= 0.45, result.projected_physical_clearance >= 0.45])
	get_tree().quit()

func _create_proxies(fortress: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "X41NavigationBakeProxies"
	fortress.add_child(root)
	var proxies := {}
	for source in _all_csg(fortress):
		var body := StaticBody3D.new()
		body.name = "%s_X41Proxy" % source.name
		body.global_transform = source.global_transform
		body.collision_layer = PROXY_LAYER
		body.collision_mask = 0
		body.add_to_group(SOURCE_GROUP)
		var shape := BoxShape3D.new()
		shape.size = source.size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.add_to_group(SOURCE_GROUP)
		body.add_child(collision)
		root.add_child(body)
		proxies[source.get_path()] = body
	return proxies

func _audit_proxy_match(fortress: Node3D, proxies: Dictionary) -> void:
	var walls := fortress.get_node("Walls")
	var source_names := []
	for source in _all_csg(fortress):
		source_names.append(source.name)
	print("X41 BAKE SOURCES | proxies=%d grouped=%d CSG_in_group=false names=%s" % [proxies.size(), get_tree().get_nodes_in_group(SOURCE_GROUP).size(), ",".join(source_names)])
	for name in ["W15", "W16", "W17", "W18", "W19", "W20"]:
		var csg := walls.get_node(name) as CSGBox3D
		var proxy := proxies[csg.get_path()] as StaticBody3D
		var shape := proxy.get_child(0).shape as BoxShape3D
		var csg_bounds := _world_bounds(csg.global_transform, csg.size)
		var proxy_bounds := _world_bounds(proxy.global_transform, shape.size)
		var match := csg.global_transform.is_equal_approx(proxy.global_transform) and csg.size.is_equal_approx(shape.size) and csg_bounds.position.is_equal_approx(proxy_bounds.position) and csg_bounds.size.is_equal_approx(proxy_bounds.size)
		print("X41 PROXY %s | CSG transform=%s size=%s bounds=%s | PROXY transform=%s shape=%s bounds=%s | %s" % [name, csg.global_transform, csg.size, csg_bounds, proxy.global_transform, shape.size, proxy_bounds, "PROXY MATCH" if match else "PROXY MISMATCH"])

func _run_bake_case(fortress: Node3D, proxies: Dictionary, radius: float, cell: float) -> Dictionary:
	# A private NavigationServer map/region removes all Node-side registration
	# timing from this isolated diagnosis. No saved Fortress region can enter it.
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map, true)
	NavigationServer3D.map_set_cell_size(map, cell)
	NavigationServer3D.map_set_cell_height(map, 0.10)
	var mesh := NavigationMesh.new()
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = SOURCE_GROUP
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = radius
	mesh.agent_height = CAPSULE_HEIGHT
	mesh.agent_max_climb = 0.20
	mesh.agent_max_slope = 1.0
	mesh.cell_size = cell
	mesh.cell_height = 0.10
	mesh.filter_walkable_low_height_spans = true
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(mesh, data, fortress, Callable())
	print("X41 PARSED proxies_only vertices=%d indices=%d radius=%.3f cell=%.3f" % [data.get_vertices().size(), data.get_indices().size(), radius, cell])
	NavigationMeshGenerator.bake_from_source_geometry_data(mesh, data, Callable())
	var bake_region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(bake_region, map)
	NavigationServer3D.region_set_navigation_mesh(bake_region, mesh)
	NavigationServer3D.region_set_enabled(bake_region, true)
	for _frame in 3:
		await get_tree().physics_frame
	NavigationServer3D.map_force_update(map)
	var projected_start := NavigationServer3D.map_get_closest_point(map, TEST_START)
	var projected_target := NavigationServer3D.map_get_closest_point(map, TEST_TARGET)
	var path := NavigationServer3D.map_get_path(map, projected_start, projected_target, true)
	var w16 := fortress.get_node("Walls/W16") as CSGBox3D
	var edge_clearance := _mesh_edge_clearance(mesh, w16)
	print("X41 CLOSEST start=%s target=%s W16_edge_clearance=%.3f" % [projected_start, projected_target, edge_clearance])
	for index in path.size():
		print("X41 RAW P%d %s" % [index, path[index]])
	var raw_analysis := _path_clearance(path, w16)
	print("X41 RAW MIN segment=%d point=%s clearance=%.3f" % [raw_analysis.segment, raw_analysis.point, raw_analysis.clearance])
	var requested_start_clearance := _point_clearance(TEST_START, w16)
	var projection_gap := _flat_distance(TEST_START, projected_start)
	print("X41 START requested=%s clearance=%.3f projected=%s gap=%.3f floor_requested=%s floor_projected=%s" % [TEST_START, requested_start_clearance, projected_start, projection_gap, _floor_hit_name(TEST_START), _floor_hit_name(projected_start)])
	var physical_from_requested := await _run_physical_path(fortress, path, projected_target, w16, TEST_START, "REQUESTED")
	var physical_from_projected := await _run_physical_path(fortress, path, projected_target, w16, projected_start, "PROJECTED")
	NavigationServer3D.free_rid(bake_region)
	NavigationServer3D.free_rid(map)
	return {"vertices":mesh.vertices.size(), "polygons":mesh.get_polygon_count(), "edge_clearance":edge_clearance, "raw_clearance":raw_analysis.clearance, "physical_clearance":physical_from_requested, "projected_physical_clearance":physical_from_projected, "projection_gap":projection_gap}

func _run_physical_path(fortress: Node3D, path: PackedVector3Array, target: Vector3, wall: CSGBox3D, start: Vector3, label: String) -> float:
	var enemy := fortress.get_node("InitialMelee") as Enemy
	enemy.set_physics_process(false)
	enemy.global_position = start
	enemy.velocity = Vector3.ZERO
	var index := 0
	while index < path.size() and _flat_distance(enemy.global_position, path[index]) < 0.1:
		index += 1
	var minimum := _point_clearance(enemy.global_position, wall)
	for _tick in 900:
		while index < path.size() and _flat_distance(enemy.global_position, path[index]) < 0.12:
			index += 1
		var goal := target if index >= path.size() else path[index]
		var heading := goal - enemy.global_position
		heading.y = 0
		enemy.velocity = heading.normalized() * SPEED if heading.length() > 0.001 else Vector3.ZERO
		enemy.move_and_slide()
		minimum = minf(minimum, _point_clearance(enemy.global_position, wall))
		if _flat_distance(enemy.global_position, target) <= ARRIVAL:
			break
		await get_tree().physics_frame
	print("X41 PHYSICAL %s min_clearance=%.3f final=%s" % [label, minimum, enemy.global_position])
	return minimum

func _mesh_edge_clearance(mesh: NavigationMesh, wall: CSGBox3D) -> float:
	var closest := INF
	for vertex in mesh.vertices:
		if vertex.x >= 33.0 and vertex.x <= 44.0 and vertex.z >= -0.5 and vertex.z <= 3.0:
			var clearance := _point_clearance(vertex, wall)
			closest = minf(closest, clearance)
			print("X41 NAV VERTEX %s clearance_to_W16=%.3f" % [vertex, clearance])
	return closest

func _path_clearance(path: PackedVector3Array, wall: CSGBox3D) -> Dictionary:
	var best := {"clearance":INF, "segment":-1, "point":Vector3.INF}
	for index in range(maxi(path.size() - 1, 0)):
		for sample in range(101):
			var point := path[index].lerp(path[index + 1], float(sample) / 100.0)
			var clearance := _point_clearance(point, wall)
			if clearance < best.clearance:
				best = {"clearance":clearance, "segment":index, "point":point}
	return best

func _point_clearance(point: Vector3, wall: CSGBox3D) -> float:
	var half := wall.size * 0.5
	var local := wall.to_local(point)
	var dx := maxf(absf(local.x) - half.x, 0.0)
	var dz := maxf(absf(local.z) - half.z, 0.0)
	return Vector2(dx, dz).length()

func _floor_hit_name(position: Vector3) -> String:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2.0, position - Vector3.UP * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "NONE"
	return String((hit.collider as Node).get_path())

func _world_bounds(transform: Transform3D, size: Vector3) -> AABB:
	var bounds := AABB(transform * (-size * 0.5), Vector3.ZERO)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				bounds = bounds.expand(transform * (size * 0.5 * Vector3(x, y, z)))
	return bounds

func _all_csg(root: Node) -> Array[CSGBox3D]:
	var result: Array[CSGBox3D] = []
	_collect_csg(root, result)
	return result

func _collect_csg(node: Node, result: Array[CSGBox3D]) -> void:
	if node is CSGBox3D:
		result.append(node)
	for child in node.get_children():
		_collect_csg(child, result)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	delta.y = 0
	return delta.length()

func _arg_float(prefix: String, fallback: float) -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).to_float()
	return fallback
