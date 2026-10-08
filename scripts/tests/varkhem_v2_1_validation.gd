extends "res://scripts/tests/stage6k4_varkhem_architecture_v2_physical_validation.gd"

const ARCHETYPE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--mobile-smoke"):
		await _mobile_smoke()
		return
	if OS.get_cmdline_user_args().has("--logical"):
		_logical()
		return
	var first := 65001
	var last := 65020
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="): first = int(arg.trim_prefix("--from="))
		if arg.begins_with("--to="): last = int(arg.trim_prefix("--to="))
	var dungeon := STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = first
	add_child(dungeon)
	await _await_sector(dungeon)
	var failures: Array = []
	var runs := 0
	var sectors := 0
	for seed in range(first, last + 1):
		await dungeon.regenerate(seed)
		await _await_sector(dungeon)
		while true:
			if not dungeon.assembly_valid or not dungeon.nav_ready:
				failures.append({"seed":seed,"sector":dungeon.current_sector_index,"error":dungeon.assembly_error,"attempts":dungeon.sector_attempt_reports})
				break
			var audit := await _audit_sector(dungeon, seed)
			var errors: Array = []
			for key in ["containment","capsule","floor","seams","nav"]: errors.append_array(audit[key])
			errors.append_array(_transition_errors(dungeon, seed, dungeon.current_sector_index))
			errors.append_array(_required_variant_errors(dungeon, seed, dungeon.current_sector_index))
			var row := _row(dungeon.current_plan, dungeon.sector_run, dungeon.current_sector_index)
			row["seed"] = seed
			row["assembly_ms"] = dungeon.assembly_elapsed_ms
			row["retry"] = dungeon.sector_retry_index
			row["backtracks"] = dungeon.placement_stats.get("backtracks",0)
			row["placement_stats"] = dungeon.placement_stats
			row["effective_seed"] = dungeon.sector_effective_seed
			row["audit"] = audit
			row["runtime"] = dungeon.get_runtime_content_metrics()
			var modules: Node3D = dungeon.get_node("AssembledModules")
			var map: RID = dungeon.nav_region.get_navigation_map()
			var occupied := {}
			var overlaps := 0
			var edges_m := 0.0
			var exit_center_route := 0.0
			var parents := {}
			var edge_distances := {}
			for module in modules.get_children():
				overlaps += dungeon._overlap_details(module, occupied).size()
				occupied[module.name] = module
			for parent in dungeon.current_plan.links:
				for child in dungeon.current_plan.links[parent]:
					var a: Vector3 = modules.get_node(NodePath(String(parent))).global_position
					var b: Vector3 = modules.get_node(NodePath(String(child))).global_position
					var path := NavigationServer3D.map_get_path(map,a,b,true)
					if path.size() < 2: errors.append("disconnected edge %s -> %s" % [parent,child])
					var distance := _meters(path)
					edges_m += distance
					parents[child] = parent
					edge_distances[child] = distance
					if dungeon.current_plan.main_path_nodes.has(child): exit_center_route += distance
			var exit_route := NavigationServer3D.map_get_path(map,dungeon.start_point,dungeon.exit_point,true)
			row["exit_m"] = _meters(exit_route)
			var required_edges := {}
			for id in dungeon.current_plan.module_ids:
				if dungeon.current_plan.module_types[id] not in [&"ROOM",&"SIDE_ROOM"]: continue
				var cursor: StringName = id
				while parents.has(cursor):
					required_edges[cursor] = true
					cursor = parents[cursor]
			var visit_m := 0.0
			for child in required_edges: visit_m += float(edge_distances[child])
			row["all_destinations_return_m"] = 2.0 * visit_m
			# Tree itinerary: visit all destination leaves, continue to EXIT.
			row["all_destinations_then_exit_m"] = 2.0 * edges_m - exit_center_route
			row["command_m"] = -1.0
			for location in dungeon.current_plan.semantic_locations:
				if location.definition.semantic_id == &"COMMAND_ROOM":
					var position: Vector3 = modules.get_node(NodePath(String(location.node_id))).global_position
					var route := NavigationServer3D.map_get_path(map,dungeon.start_point,position,true)
					var reverse := NavigationServer3D.map_get_path(map,position,dungeon.start_point,true)
					if route.size() < 2 or reverse.size() < 2: errors.append("COMMAND unreachable")
					row.command_m = _meters(route)
			var content: ContentPlacementPlan = dungeon.current_content_plan
			var runtime: Node3D = dungeon.get_node_or_null("RuntimeContent")
			if content == null or not content.is_valid() or runtime == null or runtime.get_child_count() != content.selected_slots.size(): errors.append("runtime encounter mismatch")
			if row.runtime.has("navigation_rejected") or not row.runtime.invalid_payloads.is_empty(): errors.append("runtime invalid spawn")
			if overlaps > 0: errors.append("accepted overlaps")
			row["overlaps"] = overlaps
			row["errors"] = errors
			print("V21_PHYSICAL=%s" % JSON.stringify(row))
			sectors += 1
			if not errors.is_empty():
				failures.append({"seed":seed,"sector":dungeon.current_sector_index,"errors":errors})
				break
			if dungeon.current_sector_index == dungeon.sector_run.sector_count()-1: break
			await dungeon.advance_sector_from_debug()
			await _await_sector(dungeon)
		if not failures.is_empty(): break
		runs += 1
	var determinism: Array = []
	if failures.is_empty():
		for seed in [65001,65003,65005,65015,65020]: determinism.append(await _determinism(dungeon,seed))
	var valid: bool = failures.is_empty() and determinism.all(func(item): return bool(item.valid))
	print("V21_PHYSICAL_RESULT=%s" % JSON.stringify({"runs":runs,"sectors":sectors,"failures":failures,"determinism":determinism,"valid":valid}))
	get_tree().quit(0 if valid else 1)


func _logical() -> void:
	var valid := true
	var topologies := {}
	var templates := {}
	var sectors := 0
	for seed in range(65001,65101):
		var director := DungeonArchetypeDirector.new()
		var run := director.create_sector_run(ARCHETYPE,seed)
		var replay := director.create_sector_run(ARCHETYPE,seed)
		var commands := 0
		for index in run.sector_count():
			var plan := director.build_sector_plan(run,index)
			var same := director.build_sector_plan(replay,index)
			var row := _row(plan,run,index)
			row["seed"] = seed
			var errors: Array = []
			if plan == null or not plan.is_valid(): errors.append("invalid plan")
			if same == null or var_to_str([plan.links,plan.module_types,plan.node_tags]) != var_to_str([same.links,same.module_types,same.node_tags]): errors.append("non deterministic topology")
			var semantic_a: Array = []
			var semantic_b: Array = []
			for location in plan.semantic_locations:
				semantic_a.append([location.definition.semantic_id,location.node_id])
				if location.definition.semantic_id == &"COMMAND_ROOM": commands += 1
			for location in same.semantic_locations: semantic_b.append([location.definition.semantic_id,location.node_id])
			if semantic_a != semantic_b: errors.append("non deterministic semantics")
			if row.nodes != {&"SMALL":13,&"MEDIUM":17,&"LARGE":21}[run.sector_size_profiles[index].size_id]: errors.append("size")
			if row.destination_depths.min() != 3 or row.destination_depths.max() < 5: errors.append("missing early/advanced destination")
			if row.command_depth >= 0 and row.command_depth < 4: errors.append("shallow COMMAND")
			for id in plan.module_ids:
				if plan.module_types[id] in [&"ROOM",&"SIDE_ROOM"] and (plan.main_path_nodes.has(id) or not plan.links.get(id,[]).is_empty()): errors.append("room transit")
			row["errors"] = errors
			print("V21_LOGICAL=%s" % JSON.stringify(row))
			valid = valid and errors.is_empty()
			topologies[plan.get_topology_signature()] = true
			templates[row.template] = int(templates.get(row.template,0))+1
			sectors += 1
		valid = valid and commands == 1
	print("V21_LOGICAL_RESULT=%s" % JSON.stringify({"valid":valid,"runs":100,"sectors":sectors,"topologies":topologies.size(),"templates":templates}))
	get_tree().quit(0 if valid else 1)


func _row(plan: DungeonPlan, run: DungeonSectorRun, index: int) -> Dictionary:
	var depths: Array = []
	var command := -1
	var hub := -1
	for id in plan.module_ids:
		if plan.module_types[id] in [&"ROOM",&"SIDE_ROOM"]: depths.append(plan.node_depths.get(id,-1))
	for location in plan.semantic_locations:
		if location.definition.semantic_id == &"COMMAND_ROOM": command = location.depth_from_start
		if location.definition.semantic_id == &"CENTRAL_HUB": hub = location.depth_from_start
	return {"sector":index,"size":run.sector_size_profiles[index].size_id,"template":run.sector_templates[index].stable_id,"nodes":plan.module_ids.size(),"destination_depths":depths,"command_depth":command,"hub_depth":hub,"exit_hops":plan.shortest_path_length(&"START",&"EXIT"),"semantics":plan.semantic_locations.map(func(location): return "%s@%s" % [location.definition.semantic_id,location.node_id])}


func _meters(path: PackedVector3Array) -> float:
	var result := 0.0
	for index in range(1,path.size()): result += path[index-1].distance_to(path[index])
	return result


func _mobile_smoke() -> void:
	var stage = load("res://scenes/tests/VarkhemV21ExperienceTest.tscn").instantiate()
	stage.initial_seed = 65002
	add_child(stage)
	await _await_sector(stage)
	var valid: bool = stage.assembly_valid and stage.nav_ready and stage.test_archetype_index == 1
	stage.get_node("V21Controls/Panel/Buttons/NewSeed").pressed.emit()
	await _await_sector(stage)
	valid = valid and stage.seed == 65003 and stage.assembly_valid and stage.nav_ready
	stage.get_node("V21Controls/Panel/Buttons/NextSector").pressed.emit()
	await _await_sector(stage)
	valid = valid and stage.current_sector_index == 1 and stage.assembly_valid and stage.nav_ready
	valid = valid and _transition_errors(stage,65003,1).is_empty()
	print("V21_MOBILE_SMOKE=%s" % valid)
	get_tree().quit(0 if valid else 1)
