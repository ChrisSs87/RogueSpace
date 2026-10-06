extends Node3D

## Diagnóstico deliberadamente no correctivo de 6G.2. Compara el seed que
## navega con el que pierde el EXIT después del bake B+C.

func _ready() -> void:
	var dungeon: Node3D = $Stage6GProceduralPrototype
	while dungeon.seed != 61001 or not dungeon.assembly_valid:
		await get_tree().physics_frame
	await _report("PASS_61001", dungeon)
	await dungeon.regenerate(61005)
	await _report("FAIL_61005", dungeon)
	get_tree().quit(0)


func _report(label: String, dungeon: Node3D) -> void:
	for _frame in 12:
		await get_tree().physics_frame
	var map: RID = dungeon.nav_region.get_navigation_map()
	NavigationServer3D.map_force_update(map)
	await get_tree().physics_frame
	print("6G.2 DIAG %s seed=%d assembly=%s nav=%s source_vertices=%d source_indices=%d source_bounds=%s nav_vertices=%d nav_polygons=%d nav_bounds=%s" % [label, dungeon.seed, dungeon.assembly_valid, dungeon.nav_ready, dungeon.bake_source_vertex_count, dungeon.bake_source_index_count, dungeon.bake_source_bounds, dungeon.nav_mesh.vertices.size(), dungeon.nav_mesh.get_polygon_count(), _points_bounds(dungeon.nav_mesh.vertices)])
	var modules := dungeon.get_node("AssembledModules") as Node3D
	for module in modules.get_children():
		if not module is Node3D:
			continue
		var center: Vector3 = (module as Node3D).global_position + Vector3(0, 0.2, 0)
		var closest := NavigationServer3D.map_get_closest_point(map, center)
		var poly_count := _polygons_near(dungeon.nav_mesh, _module_bounds(module as Node3D))
		print("6G.2 MODULE %s kind=%s transform=%s bounds=%s center_closest=%s center_gap=%.3f nav_polygons=%d" % [module.name, module.get_meta("module_kind", &""), (module as Node3D).global_transform, _module_bounds(module as Node3D), closest, center.distance_to(closest), poly_count])
		for child in module.get_children():
			if child is Marker3D:
				var marker := child as Marker3D
				var seam_closest := NavigationServer3D.map_get_closest_point(map, marker.global_position + Vector3(0, 0.2, 0))
				print("6G.2 CONNECTOR module=%s name=%s role=%s pos=%s forward=%s up=%s width=%.2f height=%.2f closest=%s gap=%.3f" % [module.name, marker.name, marker.get_meta("role", ""), marker.global_position, -marker.global_transform.basis.z.normalized(), marker.global_transform.basis.y.normalized(), float(marker.get_meta("usable_width_m", 0.0)), float(marker.get_meta("usable_height_m", 0.0)), seam_closest, marker.global_position.distance_to(seam_closest)])
	for report in dungeon.bake_proxy_reports:
		print("6G.2 PROXY module=%s source=%s transform=%s bounds=%s layer=%d mask=%d" % [report.module, report.source, report.transform, report.bounds, int(report.layer), int(report.mask)])
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var exit := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	var path := NavigationServer3D.map_get_path(map, start, exit, true)
	print("6G.2 MAP start_expected=%s start_closest=%s start_gap=%.3f exit_expected=%s exit_closest=%s exit_gap=%.3f path_points=%d region_enabled=%s map=%s" % [dungeon.start_point, start, dungeon.start_point.distance_to(start), dungeon.exit_point, exit, dungeon.exit_point.distance_to(exit), path.size(), dungeon.nav_region.enabled, map])


func _module_bounds(module: Node3D) -> AABB:
	return AABB(module.global_position - Vector3(4.0, 0.1, 4.0), Vector3(8.0, 2.1, 8.0))


func _points_bounds(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _polygons_near(mesh: NavigationMesh, bounds: AABB) -> int:
	var count := 0
	for index in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(index)
		var center := Vector3.ZERO
		for vertex_index in polygon:
			center += mesh.vertices[vertex_index]
		center /= maxf(1.0, float(polygon.size()))
		if bounds.grow(0.1).has_point(center):
			count += 1
	return count
