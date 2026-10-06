extends Node3D

## Diagnostic-only B+C map. It never assigns a mesh to Fortress6A's saved
## regions and frees all temporary server RIDs before exit.
const SOURCE_GROUP := &"end_to_end_diag_proxy_source"
const PROXY_LAYER := 32
const RADIUS := 0.55
const HEIGHT := 1.80
const CELL := 0.05
const SPEED := 2.0
const ARRIVAL := 0.35
const START_WELL := Vector3(70, 1, 0)
const END_SPAWN := Vector3(2, 1, 0)

func _ready() -> void:
	var fortress := $MainFortress6A/Fortress6A as Node3D
	for legacy_name in [NodePath("NavigationRegion3D"), NodePath("NavigationEntryBridge")]:
		var legacy := fortress.get_node_or_null(legacy_name) as NavigationRegion3D
		if legacy != null:
			legacy.enabled = false
			legacy.navigation_mesh = null
	for _frame in 5:
		await get_tree().physics_frame
	var proxies := _create_proxies(fortress)
	await get_tree().physics_frame
	var bake := await _bake_private_map(fortress)
	var enemy := fortress.get_node("InitialMelee") as Enemy
	enemy.set_physics_process(false)
	print("END DIAG SETUP | proxies=%d layer=%d mask=0 enemy_layer=%d enemy_mask=%d nav_vertices=%d nav_polygons=%d" % [proxies.size(), PROXY_LAYER, enemy.collision_layer, enemy.collision_mask, bake.mesh.vertices.size(), bake.mesh.get_polygon_count()])
	var forward := NavigationServer3D.map_get_path(bake.map, START_WELL, END_SPAWN, true)
	var reverse := NavigationServer3D.map_get_path(bake.map, END_SPAWN, START_WELL, true)
	print("END DIAG RAW | WELL_TO_SPAWN points=%d | SPAWN_TO_WELL points=%d" % [forward.size(), reverse.size()])
	_print_path("WELL_TO_SPAWN", forward)
	var raw_clearance := _raw_path_clearance(fortress, forward)
	print("END DIAG RAW CLEARANCE | min=%.3f segment=P%d->P%d point=%s" % [raw_clearance.clearance, raw_clearance.segment, raw_clearance.segment + 1, raw_clearance.point])
	if "--raw-only" in OS.get_cmdline_user_args():
		NavigationServer3D.free_rid(bake.region)
		NavigationServer3D.free_rid(bake.map)
		get_tree().quit()
		return
	var forward_result := await _run_path(fortress, enemy, forward, START_WELL, END_SPAWN, "WELL_TO_SPAWN_PROXY_PRESENT")
	for proxy in proxies.values():
		(proxy as StaticBody3D).collision_layer = 0
	await get_tree().physics_frame
	var excluded_result := await _run_path(fortress, enemy, forward, START_WELL, END_SPAWN, "WELL_TO_SPAWN_PROXY_EXCLUDED")
	var player := $MainFortress6A/Player as CharacterBody3D
	var player_layer := player.collision_layer
	player.collision_layer = 0
	await get_tree().physics_frame
	var player_excluded_result := await _run_path(fortress, enemy, forward, START_WELL, END_SPAWN, "WELL_TO_SPAWN_PLAYER_EXCLUDED")
	player.collision_layer = player_layer
	var reverse_result := await _run_path(fortress, enemy, reverse, END_SPAWN, START_WELL, "SPAWN_TO_WELL")
	_print_segments(forward, forward_result)
	print("END DIAG RESULT | forward_reached=%s forward_collisions=%d first_block=%s proxy_excluded_reached=%s proxy_excluded_collisions=%d player_excluded_reached=%s player_excluded_collisions=%d reverse_reached=%s" % [forward_result.reached, forward_result.collisions, forward_result.first_block, excluded_result.reached, excluded_result.collisions, player_excluded_result.reached, player_excluded_result.collisions, reverse_result.reached])
	NavigationServer3D.free_rid(bake.region)
	NavigationServer3D.free_rid(bake.map)
	get_tree().quit()

func _create_proxies(fortress: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "EndToEndDiagnosticProxies"
	fortress.add_child(root)
	var result := {}
	for source in _all_csg(fortress):
		var body := StaticBody3D.new()
		body.name = "%s_EndProxy" % source.name
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
		result[source.get_path()] = body
	return result

func _bake_private_map(fortress: Node3D) -> Dictionary:
	var mesh := NavigationMesh.new()
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = SOURCE_GROUP
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = RADIUS
	mesh.agent_height = HEIGHT
	mesh.agent_max_climb = 0.20
	mesh.agent_max_slope = 1.0
	mesh.cell_size = CELL
	mesh.cell_height = 0.10
	mesh.filter_walkable_low_height_spans = true
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(mesh, data, fortress, Callable())
	NavigationMeshGenerator.bake_from_source_geometry_data(mesh, data, Callable())
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map, true)
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, 0.10)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, mesh)
	NavigationServer3D.region_set_enabled(region, true)
	for _frame in 3:
		await get_tree().physics_frame
	NavigationServer3D.map_force_update(map)
	return {"map":map, "region":region, "mesh":mesh}

func _run_path(fortress: Node3D, enemy: Enemy, path: PackedVector3Array, start: Vector3, target: Vector3, label: String) -> Dictionary:
	enemy.global_position = start
	enemy.velocity = Vector3.ZERO
	var index := 0
	while index < path.size() and _flat_distance(enemy.global_position, path[index]) < 0.12:
		index += 1
	var total_length := _path_length(path)
	var tick_budget := ceili((total_length / SPEED + 3.0) * 60.0)
	var collisions := 0
	var first_block := "NONE"
	var first_block_logged := false
	var stationary := 0.0
	var max_stationary := 0.0
	var reached := false
	var previous_distance := _flat_distance(enemy.global_position, target)
	for tick in tick_budget:
		while index < path.size() and _flat_distance(enemy.global_position, path[index]) < 0.12:
			index += 1
		var waypoint := target if index >= path.size() else path[index]
		var heading := waypoint - enemy.global_position
		heading.y = 0.0
		enemy.velocity = heading.normalized() * SPEED if heading.length() > 0.001 else Vector3.ZERO
		var before := enemy.global_position
		enemy.move_and_slide()
		var moved := _flat_distance(enemy.global_position, before)
		var actual_speed := moved * 60.0
		var destination_distance := _flat_distance(enemy.global_position, target)
		if enemy.velocity.length() > 0.05 and moved < 0.002:
			stationary += 1.0 / 60.0
		else:
			stationary = 0.0
		max_stationary = maxf(max_stationary, stationary)
		for collision_index in enemy.get_slide_collision_count():
			collisions += 1
			if not first_block_logged:
				var hit := enemy.get_slide_collision(collision_index)
				var collider := hit.get_collider() as Node
				first_block = "%s (%s)" % [collider.get_path() if collider != null else "NULL", collider.get_class() if collider != null else "Unknown"]
				print("END DIAG FIRST COLLISION %s | tick=%d pos=%s path_index=%d waypoint=%s next=%s req_speed=%.3f actual_speed=%.3f waypoint_dist=%.3f target_dist=%.3f normal=%s contact=%s collider=%s layer=%d mask=%d" % [label, tick, enemy.global_position, index, waypoint, path[min(index + 1, path.size() - 1)] if not path.is_empty() else Vector3.ZERO, enemy.velocity.length(), actual_speed, _flat_distance(enemy.global_position, waypoint), destination_distance, hit.get_normal(), hit.get_position(), first_block, collider.collision_layer if collider is CollisionObject3D else -1, collider.collision_mask if collider is CollisionObject3D else -1])
				_print_local_path(path, index)
				first_block_logged = true
		if tick % 60 == 0:
			print("END DIAG TICK %s | t=%.1f pos=%s idx=%d waypoint=%s req=%.2f actual=%.2f target_dist=%.3f progress=%.3f slides=%d" % [label, float(tick) / 60.0, enemy.global_position, index, waypoint, enemy.velocity.length(), actual_speed, destination_distance, previous_distance - destination_distance, enemy.get_slide_collision_count()])
		previous_distance = destination_distance
		if destination_distance <= ARRIVAL:
			reached = true
			break
		await get_tree().physics_frame
	print("END DIAG PATH %s | reached=%s final=%s target_dist=%.3f collisions=%d max_stationary=%.3f first_block=%s" % [label, reached, enemy.global_position, _flat_distance(enemy.global_position, target), collisions, max_stationary, first_block])
	return {"reached":reached, "collisions":collisions, "first_block":first_block, "max_stationary":max_stationary}

func _print_path(label: String, path: PackedVector3Array) -> void:
	for i in path.size():
		print("END DIAG RAW %s P%d=%s" % [label, i, path[i]])

func _print_local_path(path: PackedVector3Array, index: int) -> void:
	for i in range(maxi(0, index - 2), mini(path.size(), index + 3)):
		print("END DIAG LOCAL P%d=%s%s" % [i, path[i], " ACTIVE" if i == index else ""])

func _print_segments(path: PackedVector3Array, result: Dictionary) -> void:
	# The detailed path trace reveals the first failing interval; this heading
	# preserves the required segmentation output without inventing room points.
	print("END DIAG SEGMENTS WELL>x66>x58>x49>x41>x17>x9>SPAWN | overall_reached=%s first_block=%s" % [result.reached, result.first_block])

func _path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += _flat_distance(path[i - 1], path[i])
	return length

func _raw_path_clearance(fortress: Node3D, path: PackedVector3Array) -> Dictionary:
	var best := {"clearance":INF, "segment":-1, "point":Vector3.INF}
	for segment in range(maxi(path.size() - 1, 0)):
		for sample in range(101):
			var point := path[segment].lerp(path[segment + 1], float(sample) / 100.0)
			var clearance := INF
			for wall in fortress.get_node("Walls").get_children():
				if wall is CSGBox3D:
					var box := wall as CSGBox3D
					var local := box.to_local(point)
					var half := box.size * 0.5
					var dx := maxf(absf(local.x) - half.x, 0.0)
					var dz := maxf(absf(local.z) - half.z, 0.0)
					clearance = minf(clearance, Vector2(dx, dz).length())
			if clearance < best.clearance:
				best = {"clearance":clearance, "segment":segment, "point":point}
	return best

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
	delta.y = 0.0
	return delta.length()
