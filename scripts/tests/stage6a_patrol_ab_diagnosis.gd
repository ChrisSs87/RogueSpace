extends Node3D

const SOURCE_GROUP := &"patrol_ab_nav_source"
const PROXY_LAYER := 32
const DURATION_SECONDS := 10.0
const TELEMETRY_SECONDS := 5.0

func _ready() -> void:
	var mode := "manual"
	var enemy_name := "InitialMelee"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--patrol-ab="):
			mode = argument.trim_prefix("--patrol-ab=")
		elif argument.begins_with("--patrol-ab-enemy="):
			enemy_name = argument.trim_prefix("--patrol-ab-enemy=")
	var fortress := $MainFortress6A/Fortress6A as Node3D
	var player := $MainFortress6A/Player as CharacterBody3D
	var enemy := fortress.get_node(enemy_name) as Enemy
	# Keep the Player out of perception so both trials are pure patrol.
	player.global_position = Vector3(70, 1, 0)
	player.velocity = Vector3.ZERO
	if mode.begins_with("bc"):
		await _activate_bc_only(fortress)
		if mode.begins_with("bc-offset"):
			_align_agent_to_navigation_plane(enemy, fortress.get_world_3d().get_navigation_map())
	else:
		for _frame in 5:
			await get_tree().physics_frame
	var map := fortress.get_world_3d().get_navigation_map()
	var point_a := enemy.get_node(enemy.patrol_points[0]) as Node3D
	var point_b := enemy.get_node(enemy.patrol_points[1]) as Node3D
	var closest_a := NavigationServer3D.map_get_closest_point(map, point_a.global_position)
	var closest_b := NavigationServer3D.map_get_closest_point(map, point_b.global_position)
	var path := NavigationServer3D.map_get_path(map, closest_a, closest_b, true)
	if mode == "bc-offset-simple":
		# El estado sigue siendo PATROL: empezar en A hace que el pipeline real
		# avance a B sin escribir estados internos ni targets del agente.
		enemy.global_position = Vector3(point_a.global_position.x, enemy.global_position.y, point_a.global_position.z)
		enemy.velocity = Vector3.ZERO
		await get_tree().physics_frame
	print("PATROL_AB %s PATH | A=%s closest=%s gap=%.3f B=%s closest=%s gap=%.3f points=%d length=%.3f" % [mode, point_a.global_position, closest_a, _flat_distance(point_a.global_position, closest_a), point_b.global_position, closest_b, _flat_distance(point_b.global_position, closest_b), path.size(), _path_length(path)])
	for i in path.size():
		print("PATROL_AB %s RAW P%d=%s" % [mode, i, path[i]])
	print("PATROL_AB %s HEIGHT | enemy_y=%.3f target_y=%.3f agent_target=%s" % [mode, enemy.global_position.y, point_a.global_position.y, enemy.navigation_agent.target_position])
	print("PATROL_AB %s AGENT | path_desired=%.3f target_desired=%.3f map=%s" % [mode, enemy.navigation_agent.path_desired_distance, enemy.navigation_agent.target_desired_distance, map])
	print("PATROL_AB %s COLLISION | enemy_layer=%d enemy_mask=%d proxy_layer=%d proxy_mask=0" % [mode, enemy.collision_layer, enemy.collision_mask, PROXY_LAYER])
	if mode == "bc-direct":
		await _run_direct_physical_bc(enemy, path, point_a.global_position)
		get_tree().quit()
		return
	var start := enemy.global_position
	var previous := start
	var accumulated := 0.0
	var target_changes := 0
	var agent_target_changes := 0
	var next_changes := 0
	var previous_patrol: int = int(enemy.get_patrol_runtime_debug()["patrol_index"])
	var previous_agent_target := enemy.navigation_agent.target_position
	var previous_next := Vector3.INF
	var collision_count := 0
	var first_collision := "NONE"
	var yaw_oscillations := 0
	var micro_yaw_oscillations := 0
	var previous_yaw := enemy.rotation.y
	var elapsed := 0.0
	var minimum_distance_to_b := _flat_distance(enemy.global_position, point_b.global_position)
	while elapsed < DURATION_SECONDS:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		var current := enemy.global_position
		minimum_distance_to_b = minf(minimum_distance_to_b, _flat_distance(current, point_b.global_position))
		var moved := _flat_distance(current, previous)
		accumulated += moved
		var next := enemy.navigation_agent.get_next_path_position()
		var agent_anchor := enemy.navigation_agent.get_parent() as Node3D
		var agent_origin := agent_anchor.global_position if agent_anchor != null else enemy.global_position
		if previous_next != Vector3.INF and not next.is_equal_approx(previous_next):
			next_changes += 1
		var patrol_index: int = int(enemy.get_patrol_runtime_debug()["patrol_index"])
		if patrol_index != previous_patrol:
			target_changes += 1
			previous_patrol = patrol_index
		if not enemy.navigation_agent.target_position.is_equal_approx(previous_agent_target):
			agent_target_changes += 1
			previous_agent_target = enemy.navigation_agent.target_position
		if absf(wrapf(enemy.rotation.y - previous_yaw, -PI, PI)) > 0.4 and moved < 0.01:
			yaw_oscillations += 1
		if absf(wrapf(enemy.rotation.y - previous_yaw, -PI, PI)) > 0.4 and moved < 0.02:
			micro_yaw_oscillations += 1
		previous_yaw = enemy.rotation.y
		for collision_index in enemy.get_slide_collision_count():
			collision_count += 1
			if first_collision == "NONE":
				var hit := enemy.get_slide_collision(collision_index)
				var collider := hit.get_collider() as Node
				first_collision = "%s layer=%d" % [collider.get_path() if collider != null else "NULL", collider.collision_layer if collider is CollisionObject3D else -1]
		if elapsed <= TELEMETRY_SECONDS and int(elapsed * 10.0) != int((elapsed - 1.0 / 60.0) * 10.0):
			print("PATROL_AB %s TICK t=%.1f pos=%s yaw=%.3f req=%.3f actual=%.3f patrol=%d agent_origin=%s agent_target=%s next=%s dist_target=%.3f dist_next_xz=%.3f body_next_3d=%.3f agent_next_3d=%.3f finished=%s reachable=%s source=%s state=%s stalled=%s slides=%d" % [mode, elapsed, current, enemy.rotation.y, Vector2(enemy.velocity.x, enemy.velocity.z).length(), moved * 60.0, patrol_index, agent_origin, enemy.navigation_agent.target_position, next, _flat_distance(current, point_a.global_position if patrol_index == 0 else point_b.global_position), _flat_distance(current, next), current.distance_to(next), agent_origin.distance_to(next), enemy.navigation_agent.is_navigation_finished(), enemy.navigation_agent.is_target_reachable(), enemy.get_debug_movement_source(), enemy.get_debug_state_name(), enemy.get_debug_ai_stalled(), enemy.get_slide_collision_count()])
		previous = current
		previous_next = next
	print("PATROL_AB %s %s RESULT | net=%.3f accumulated=%.3f target_changes=%d min_distance_to_b=%.3f agent_target_changes=%d next_changes=%d yaw_oscillations=%d micro_yaw_oscillations=%d collisions=%d recovery=%d first_collision=%s" % [mode, enemy_name, _flat_distance(start, enemy.global_position), accumulated, target_changes, minimum_distance_to_b, agent_target_changes, next_changes, yaw_oscillations, micro_yaw_oscillations, collision_count, enemy.get_debug_stuck_recovery_count(), first_collision])
	get_tree().quit()

func _activate_bc_only(fortress: Node3D) -> void:
	for legacy_path in [NodePath("NavigationRegion3D"), NodePath("NavigationEntryBridge")]:
		var legacy := fortress.get_node_or_null(legacy_path) as NavigationRegion3D
		if legacy != null:
			# El fallo histórico ocurrió con B+C como única región, no sólo con la
			# malla manual deshabilitada. Retiramos estas regiones únicamente del
			# árbol de este proceso diagnóstico; la escena productiva no cambia.
			legacy.queue_free()
	for _frame in 5:
		await get_tree().physics_frame
	var root := Node3D.new()
	root.name = "PatrolABProxies"
	fortress.add_child(root)
	for source in _all_csg(fortress):
		var body := StaticBody3D.new()
		body.global_transform = source.global_transform
		body.collision_layer = PROXY_LAYER
		body.collision_mask = 0
		body.add_to_group(SOURCE_GROUP)
		var box := BoxShape3D.new()
		box.size = source.size
		var collision := CollisionShape3D.new()
		collision.shape = box
		collision.add_to_group(SOURCE_GROUP)
		body.add_child(collision)
		root.add_child(body)
	await get_tree().physics_frame
	var mesh := NavigationMesh.new()
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = SOURCE_GROUP
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.55
	mesh.agent_height = 1.80
	mesh.agent_max_climb = 0.20
	mesh.agent_max_slope = 1.0
	mesh.cell_size = 0.05
	mesh.cell_height = 0.10
	mesh.filter_walkable_low_height_spans = true
	var source_data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(mesh, source_data, fortress, Callable())
	NavigationMeshGenerator.bake_from_source_geometry_data(mesh, source_data, Callable())
	var region := NavigationRegion3D.new()
	region.name = "PatrolABBakedRegion"
	fortress.add_child(region)
	var map := region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, 0.05)
	NavigationServer3D.map_set_cell_height(map, 0.10)
	region.navigation_mesh = mesh
	for _frame in 5:
		await get_tree().physics_frame
	NavigationServer3D.map_force_update(region.get_navigation_map())
	print("PATROL_AB BC BAKE proxies=%d vertices=%d polygons=%d" % [_all_csg(fortress).size(), mesh.vertices.size(), mesh.get_polygon_count()])

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

func _path_length(path: PackedVector3Array) -> float:
	var result := 0.0
	for i in range(1, path.size()):
		result += _flat_distance(path[i - 1], path[i])
	return result


## Consume exactamente el raw path B+C con la cápsula y move_and_slide reales,
## pero sin Enemy._physics_process ni NavigationAgent3D. Separa malla/colisión
## de la interpretación 3D del agente; no modifica ninguna escena productiva.
func _run_direct_physical_bc(enemy: Enemy, path: PackedVector3Array, physical_start: Vector3) -> void:
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(physical_start.x, enemy.global_position.y, physical_start.z)
	enemy.velocity = Vector3.ZERO
	var waypoint_index := 1
	var elapsed := 0.0
	var accumulated := 0.0
	var previous := enemy.global_position
	var collisions := 0
	while elapsed < 12.0 and waypoint_index < path.size():
		var target := path[waypoint_index]
		var delta_flat := target - enemy.global_position
		delta_flat.y = 0.0
		if delta_flat.length() <= 0.08:
			waypoint_index += 1
			continue
		var direction := delta_flat.normalized()
		enemy.velocity = direction * 1.0
		enemy.move_and_slide()
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		accumulated += _flat_distance(enemy.global_position, previous)
		previous = enemy.global_position
		collisions += enemy.get_slide_collision_count()
	var end_point := path[path.size() - 1] if not path.is_empty() else enemy.global_position
	var reached := _flat_distance(enemy.global_position, end_point) <= 0.20
	print("PATROL_AB bc DIRECT RESULT | reached=%s final=%s distance_to_end=%.3f accumulated=%.3f collisions=%d" % [reached, enemy.global_position, _flat_distance(enemy.global_position, end_point), accumulated, collisions])


## Prototipo de corrección vertical: conserva el CharacterBody, cápsula,
## visual y NavMesh intactos. Sólo sitúa el origen del NavigationAgent en el
## plano que el NavigationMap devuelve para su propia posición física.
func _align_agent_to_navigation_plane(enemy: Enemy, navigation_map: RID) -> void:
	var projected := NavigationServer3D.map_get_closest_point(navigation_map, enemy.global_position)
	var local_offset_y := projected.y - enemy.global_position.y
	# NavigationAgent3D no hereda Node3D en Godot 4.7.2. El offset se expresa
	# con un parent Node3D temporal; el agente sigue siendo el mismo objeto que
	# Enemy.gd ya referencia y el CharacterBody no se mueve.
	var anchor := Node3D.new()
	anchor.name = "NavigationAgentHeightAnchor"
	anchor.position.y = local_offset_y
	enemy.add_child(anchor)
	enemy.navigation_agent.reparent(anchor)
	print("PATROL_AB bc-offset ALIGN | enemy_y=%.3f nav_plane_y=%.3f agent_anchor_local_y=%.3f agent_effective_y=%.3f" % [enemy.global_position.y, projected.y, local_offset_y, anchor.global_position.y])
