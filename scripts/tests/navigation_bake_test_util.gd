class_name NavigationBakeTestUtil
extends RefCounted

## Infraestructura exclusivamente de tests para ejecutar B+C sin tocar la
## escena productiva. Los CSG son la fuente de verdad; los proxies sólo viven
## durante el proceso headless actual.
const PROXY_LAYER := 32


static func activate_bc_only(fortress: Node3D, source_group: StringName) -> void:
	for legacy_path in [NodePath("NavigationRegion3D"), NodePath("NavigationEntryBridge")]:
		var legacy := fortress.get_node_or_null(legacy_path) as NavigationRegion3D
		if legacy != null:
			legacy.queue_free()
	for _frame in 5:
		await fortress.get_tree().physics_frame
	var root := Node3D.new()
	root.name = "TestNavigationBakeProxies"
	fortress.add_child(root)
	for source in _all_csg(fortress):
		var body := StaticBody3D.new()
		body.global_transform = source.global_transform
		body.collision_layer = PROXY_LAYER
		body.collision_mask = 0
		body.add_to_group(source_group)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = source.size
		collision.shape = box
		body.add_child(collision)
		root.add_child(body)
	await fortress.get_tree().physics_frame
	var mesh := NavigationMesh.new()
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	mesh.geometry_source_group_name = source_group
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.55
	mesh.agent_height = 1.80
	mesh.agent_max_climb = 0.20
	mesh.agent_max_slope = 1.0
	mesh.cell_size = 0.05
	mesh.cell_height = 0.10
	mesh.filter_walkable_low_height_spans = true
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(mesh, data, fortress, Callable())
	NavigationMeshGenerator.bake_from_source_geometry_data(mesh, data, Callable())
	var region := NavigationRegion3D.new()
	region.name = "TestBakedNavigationRegion"
	fortress.add_child(region)
	var map := region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, 0.05)
	NavigationServer3D.map_set_cell_height(map, 0.10)
	region.navigation_mesh = mesh
	for _frame in 5:
		await fortress.get_tree().physics_frame
	NavigationServer3D.map_force_update(region.get_navigation_map())
	print("TEST_BC_HEIGHT BAKE proxies=%d vertices=%d polygons=%d" % [_all_csg(fortress).size(), mesh.vertices.size(), mesh.get_polygon_count()])


static func align_agent_to_navigation_plane(enemy: Enemy) -> void:
	var map := enemy.get_world_3d().get_navigation_map()
	var projected := NavigationServer3D.map_get_closest_point(map, enemy.global_position)
	var anchor := Node3D.new()
	anchor.name = "NavigationAgentHeightAnchor"
	anchor.position.y = projected.y - enemy.global_position.y
	enemy.add_child(anchor)
	enemy.navigation_agent.reparent(anchor)
	print("TEST_BC_HEIGHT ALIGN %s body_y=%.3f nav_y=%.3f offset=%.3f" % [enemy.name, enemy.global_position.y, projected.y, anchor.position.y])


static func _all_csg(root: Node) -> Array[CSGBox3D]:
	var result: Array[CSGBox3D] = []
	_collect_csg(root, result)
	return result


static func _collect_csg(node: Node, result: Array[CSGBox3D]) -> void:
	if node is CSGBox3D:
		result.append(node)
	for child in node.get_children():
		_collect_csg(child, result)
