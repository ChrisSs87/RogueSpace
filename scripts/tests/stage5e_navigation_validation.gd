extends Node3D

## Validación de desarrollo acotada para la navegación de DungeonSandbox.
## No modifica recursos: carga la sandbox, consulta el NavigationMap real y
## falla si un patrol point no puede proyectarse o si su par A/B no tiene ruta.

const PATROL_PAIRS: Array[Array] = [
	[NodePath("OrcoMelee1"), NodePath("PatrolPoints/OrcoMelee1_A"), NodePath("PatrolPoints/OrcoMelee1_B")],
	[NodePath("OrcoMelee2"), NodePath("PatrolPoints/OrcoMelee2_A"), NodePath("PatrolPoints/OrcoMelee2_B")],
	[NodePath("OrcoPicaro1"), NodePath("PatrolPoints/OrcoPicaro1_A"), NodePath("PatrolPoints/OrcoPicaro1_B")],
	[NodePath("OrcoMelee3"), NodePath("PatrolPoints/OrcoMelee3_A"), NodePath("PatrolPoints/OrcoMelee3_B")],
	[NodePath("OrcoPicaro2"), NodePath("PatrolPoints/OrcoPicaro2_A"), NodePath("PatrolPoints/OrcoPicaro2_B")],
]


func _ready() -> void:
	var sandbox: Node3D = $DungeonSandbox
	# NavigationServer sincroniza los NavigationRegion en frames de física.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var region: NavigationRegion3D = sandbox.get_node_or_null("NavigationRegion3D")
	if region == null:
		push_error("Stage5E navigation validation: falta NavigationRegion3D.")
		get_tree().quit(1)
		return

	var navigation_map: RID = sandbox.get_world_3d().get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	print("Navigation map regions: %d | mesh polygons: %d" % [NavigationServer3D.map_get_regions(navigation_map).size(), region.navigation_mesh.get_polygon_count()])
	var failures: Array[String] = []
	for pair in PATROL_PAIRS:
		var enemy: Enemy = sandbox.get_node_or_null(pair[0])
		var from_marker: Marker3D = sandbox.get_node_or_null(pair[1])
		var to_marker: Marker3D = sandbox.get_node_or_null(pair[2])
		if enemy == null or from_marker == null or to_marker == null:
			failures.append("faltan nodos de patrulla: %s" % pair)
			continue

		# La malla está a la altura de los CharacterBody (Y=1); los Marker3D
		# de patrulla se dejan sobre el piso (Y=0) solo como referencias visuales.
		var from_position := Vector3(from_marker.global_position.x, 1.0, from_marker.global_position.z)
		var to_position := Vector3(to_marker.global_position.x, 1.0, to_marker.global_position.z)
		var mapped_from := NavigationServer3D.map_get_closest_point(navigation_map, from_position)
		var mapped_to := NavigationServer3D.map_get_closest_point(navigation_map, to_position)
		var from_offset: float = mapped_from.distance_to(from_position)
		var to_offset: float = mapped_to.distance_to(to_position)
		var path := NavigationServer3D.map_get_path(navigation_map, mapped_from, mapped_to, true)
		var path_distance: float = _path_distance(path)
		enemy.navigation_agent.target_position = to_position
		await get_tree().physics_frame
		var agent_reachable: bool = enemy.navigation_agent.is_target_reachable()
		print("PATROL %s | initial %s | A %s -> nearest %s | B %s -> nearest %s | reachable %s | path points %d | path distance %.2f" % [enemy.name, enemy.global_position, from_position, mapped_from, to_position, mapped_to, agent_reachable, path.size(), path_distance])
		if from_offset > 0.15 or to_offset > 0.15:
			failures.append("markers fuera de malla: %s -> %s" % [from_marker.name, to_marker.name])
		if not agent_reachable or path.size() < 2:
			failures.append("sin ruta: %s -> %s" % [from_marker.name, to_marker.name])

	# Atraviesa las cuatro salas y los tres corredores: prueba que las siete
	# superficies no son islas separadas además de las patrullas locales.
	var first_marker: Marker3D = sandbox.get_node("PatrolPoints/OrcoMelee1_A")
	var last_marker: Marker3D = sandbox.get_node("PatrolPoints/OrcoPicaro2_B")
	var first_pos := Vector3(first_marker.global_position.x, 1.0, first_marker.global_position.z)
	var last_pos := Vector3(last_marker.global_position.x, 1.0, last_marker.global_position.z)
	var full_path := NavigationServer3D.map_get_path(navigation_map, first_pos, last_pos, true)
	print("NAV red completa %s -> %s | path points %d" % [first_marker.name, last_marker.name, full_path.size()])
	if full_path.size() < 2:
		failures.append("las siete superficies no forman una red conectada")

	if failures.is_empty():
		print("Stage5E navigation validation: PASS (%d pares de patrulla)." % PATROL_PAIRS.size())
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("Stage5E navigation validation: %s" % failure)
		get_tree().quit(1)


func _path_distance(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total
