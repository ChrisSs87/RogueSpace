extends "res://scripts/tests/varkhem_v2_1_3_validation.gd"

func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	var report: Dictionary = dungeon.current_room_environment_report
	var modules := dungeon.get_node("AssembledModules")
	var map: RID = dungeon.nav_region.get_navigation_map()
	var environment: RoomEnvironmentProfileResource = dungeon.active_archetype.room_environment_profile
	if report.is_empty(): errors.append("missing environment report")
	for row in report.get("covers",[]):
		var declared_distribution := false
		for audit in report.get("distribution",[]):
			if audit.node == row.node and audit.semantic == row.semantic:
				for candidate in audit.examined:
					if not candidate.accepted or candidate.position != row.position: continue
					for configured in environment.distribution_cover_candidates:
						if configured.get("id") == candidate.id and configured.get("semantic") == row.semantic and configured.get("role") == dungeon.current_plan.module_types[row.node] and row.category == LogicalCover.Category.MEDIUM: declared_distribution = true
		if row.semantic in [&"BASE_ACCESS",&"COMMAND_ROOM"] or (dungeon.current_plan.module_types[row.node] not in [&"ROOM",&"SIDE_ROOM"] and not declared_distribution): errors.append("cover in protected module")
		var module: Node3D = modules.get_node(NodePath(String(row.node)))
		var covers := 0
		for child in module.get_children():
			if child is LogicalCover:
				covers += 1
				# NavMesh must not pass through the new physical cover footprint.
				var center: Vector3 = child.global_position
				# Query walking surface, not the box midpoint: its top may have
				# an isolated bake polygon that is not reachable from the floor.
				center.y = module.global_position.y
				var projected := NavigationServer3D.map_get_closest_point(map,center)
				print("B_COVER_NAV="+JSON.stringify({"center":center,"projected":projected,"size":row.size}))
				if Vector2(center.x-projected.x,center.z-projected.z).length() < 0.45: errors.append("cover absent from collider-derived bake")
		if covers > 2: errors.append("excess room props")
	for id in report.get("lit_rooms",[]):
		var module: Node3D = modules.get_node(NodePath(String(id)))
		if LightingManager.get_light_level_at(module.global_position) < 3: errors.append("functional room not illuminated")
	# Every destination center and every real connector remains reachable;
	# base gate independently audits seams, containment, capsule and transitions.
	for id in dungeon.current_plan.module_ids:
		var module: Node3D = modules.get_node(NodePath(String(id)))
		var target := NavigationServer3D.map_get_closest_point(map,module.global_position)
		var start := NavigationServer3D.map_get_closest_point(map,dungeon.start_point)
		if id != &"START" and NavigationServer3D.map_get_path(map,start,target,true).size() < 2: errors.append("unreachable module center")
		for child in module.get_children():
			if child is Marker3D and child.has_meta("side") and not child.get_meta("sealed_unused",false):
				var connector := NavigationServer3D.map_get_closest_point(map,child.global_position)
				if NavigationServer3D.map_get_path(map,target,connector,true).size() < 2: errors.append("unreachable connector")
	return errors

func _additional_physical_metrics(dungeon: Node3D) -> Dictionary:
	var metrics := super._additional_physical_metrics(dungeon)
	metrics["room_environment"] = dungeon.current_room_environment_report
	return metrics

func _determinism(dungeon: Node3D, seed: int) -> Dictionary:
	var signatures: Array = []
	for attempt in 2:
		await dungeon.regenerate(seed)
		await _await_sector(dungeon)
		var sectors: Array = []
		while true:
			if not dungeon.assembly_valid or not dungeon.nav_ready:
				return {"seed":seed,"valid":false,"error":dungeon.assembly_error}
			sectors.append(var_to_str([dungeon.current_plan.get_topology_signature(),dungeon.get_assembly_signature(),dungeon.get_selected_module_definitions(),dungeon.current_room_environment_report,dungeon.nav_mesh.vertices,dungeon.nav_mesh.get_polygon_count(),dungeon.current_content_plan.get_signature()]))
			if dungeon.current_sector_index >= dungeon.sector_run.sector_count()-1: break
			await dungeon.advance_sector_from_debug()
			await _await_sector(dungeon)
		signatures.append(sectors)
	return {"seed":seed,"valid":signatures[0] == signatures[1],"covers_light_navigation_content":true}
