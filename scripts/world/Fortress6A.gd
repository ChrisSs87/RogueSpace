extends Node3D

## Fuente única de navegación de Fortress6A.
## La arquitectura visible/física sigue siendo CSGBox3D; los StaticBody3D de
## layer 32 sólo son proxies efímeros para el bake y no participan de gameplay.
const NAV_SOURCE_GROUP := &"fortress6a_navmesh_source"
const NAV_PROXY_LAYER := 32
const NAV_AGENT_RADIUS_M := 0.55
const NAV_AGENT_HEIGHT_M := 1.80
const NAV_CELL_SIZE_M := 0.05
const NAV_CELL_HEIGHT_M := 0.10

var _navigation_bake_ready := false
var _navigation_proxy_count := 0
var _baked_navigation_mesh: NavigationMesh


func _ready() -> void:
	LightingManager.set_ambient_light_level(1)
	# La malla manual ya no participa: el bake B+C será la única región del
	# mapa antes de que arranque la exploración normal.
	for legacy_path in [NodePath("NavigationRegion3D"), NodePath("NavigationEntryBridge")]:
		var legacy := get_node_or_null(legacy_path) as NavigationRegion3D
		if legacy != null:
			legacy.queue_free()
	call_deferred("_build_baked_navigation")


func is_navigation_bake_ready() -> bool:
	return _navigation_bake_ready


func get_navigation_bake_debug() -> Dictionary:
	return {
		"ready": _navigation_bake_ready,
		"proxies": _navigation_proxy_count,
		"vertices": _baked_navigation_mesh.vertices.size() if _baked_navigation_mesh != null else 0,
		"polygons": _baked_navigation_mesh.get_polygon_count() if _baked_navigation_mesh != null else 0,
	}


func _build_baked_navigation() -> void:
	# Los CSG instanciados necesitan entrar al árbol y completar su geometría
	# antes de derivar los proxies. No hay navegación manual activa durante
	# esta breve sincronización.
	for _frame in 5:
		await get_tree().physics_frame

	var proxy_root := Node3D.new()
	proxy_root.name = "NavigationBakeProxies"
	add_child(proxy_root)
	for source in _collect_csg_boxes(self):
		var proxy := StaticBody3D.new()
		proxy.name = "NavProxy_%s" % source.name
		proxy.global_transform = source.global_transform
		proxy.collision_layer = NAV_PROXY_LAYER
		proxy.collision_mask = 0
		proxy.add_to_group(NAV_SOURCE_GROUP)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = source.size
		collision.shape = box
		proxy.add_child(collision)
		proxy_root.add_child(proxy)
		_navigation_proxy_count += 1

	await get_tree().physics_frame
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	navigation_mesh.geometry_source_group_name = NAV_SOURCE_GROUP
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.agent_radius = NAV_AGENT_RADIUS_M
	navigation_mesh.agent_height = NAV_AGENT_HEIGHT_M
	navigation_mesh.agent_max_climb = 0.20
	navigation_mesh.agent_max_slope = 1.0
	navigation_mesh.cell_size = NAV_CELL_SIZE_M
	navigation_mesh.cell_height = NAV_CELL_HEIGHT_M
	navigation_mesh.filter_walkable_low_height_spans = true
	var source_data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(navigation_mesh, source_data, self, Callable())
	NavigationMeshGenerator.bake_from_source_geometry_data(navigation_mesh, source_data, Callable())

	var region := NavigationRegion3D.new()
	region.name = "BakedNavigationRegion"
	add_child(region)
	var navigation_map := region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(navigation_map, NAV_CELL_SIZE_M)
	NavigationServer3D.map_set_cell_height(navigation_map, NAV_CELL_HEIGHT_M)
	region.navigation_mesh = navigation_mesh
	for _frame in 5:
		await get_tree().physics_frame
	NavigationServer3D.map_force_update(navigation_map)
	_baked_navigation_mesh = navigation_mesh
	_navigation_bake_ready = navigation_mesh.vertices.size() > 0 and navigation_mesh.get_polygon_count() > 0
	print("Fortress6A B+C navigation | proxies=%d source_vertices=%d source_indices=%d nav_vertices=%d nav_polygons=%d" % [_navigation_proxy_count, source_data.vertices.size(), source_data.indices.size(), navigation_mesh.vertices.size(), navigation_mesh.get_polygon_count()])


func _collect_csg_boxes(root: Node) -> Array[CSGBox3D]:
	var result: Array[CSGBox3D] = []
	_collect_csg_boxes_recursive(root, result)
	return result


func _collect_csg_boxes_recursive(node: Node, result: Array[CSGBox3D]) -> void:
	if node is CSGBox3D:
		result.append(node)
	for child in node.get_children():
		_collect_csg_boxes_recursive(child, result)
