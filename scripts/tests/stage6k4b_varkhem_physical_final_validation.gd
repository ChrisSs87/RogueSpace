extends Node3D

const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")

const EXPECTED := {
	&"CENTRAL_HUB": {"definition": &"base_central_hub_large", "size": Vector2(16, 16)},
	&"BARRACKS": {"definition": &"base_barracks", "size": Vector2(14, 10)},
	&"VARKHEM_ROOM": {"definition": &"base_varkhem_private_room", "size": Vector2(6, 6)},
	&"COMMAND_ROOM": {"definition": &"base_command_room", "size": Vector2(14, 12)},
	&"PRISON": {"definition": &"base_prison", "size": Vector2(12, 10)},
	&"ARMORY": {"definition": &"base_armory", "size": Vector2(10, 10)},
	&"FOOD_STORAGE": {"definition": &"base_food_storage", "size": Vector2(10, 8)},
}

func _ready() -> void:
	var dungeon: Node3D = STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65001
	add_child(dungeon)
	await _await_result(dungeon)
	var report := {
		"runs": 0, "passed_runs": 0, "sectors": 0, "sizes": {}, "paths": {}, "variants": {},
		"required_failures": [], "overlaps_rejected": 0, "overlaps_accepted": 0, "seams_invalid": 0,
		"backtracks": 0, "backtrack_depth": {0: 0, 1: 0, 2: 0}, "backtrack_over_limit": [],
		"assembly_ms_total": 0, "assembly_ms_max": 0, "nav_failures": [], "transition_failures": [], "failures": [],
		"feasibility_probes": 0, "feasibility_rejected": 0, "feasibility_elapsed_ms": 0, "feasibility_elapsed_max": 0, "feasibility_by_semantic": {},
	}
	var valid := true
	var first_seed := 65001
	var last_seed := 65020
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		first_seed = int(args[0])
		last_seed = int(args[1])
	for seed in range(first_seed, last_seed + 1):
		await dungeon.regenerate(seed)
		await _await_result(dungeon)
		report.runs += 1
		var path := _path_label(dungeon)
		report.paths[path] = int(report.paths.get(path, 0)) + 1
		var run_valid := true
		var saved_hp := RunState.player_health
		var saved_o2 := RunState.oxygen_current
		var saved_stats: Variant = RunState.character_stats
		var saved_dna := DNAManager.dna.duplicate(true)
		var saved_loadout := RunState.equipped_loadout
		for sector_index in range(dungeon.sector_run.sector_count()):
			var sector_valid := _validate_sector(dungeon, report, seed, sector_index)
			run_valid = run_valid and sector_valid
			if sector_index < dungeon.sector_run.sector_count() - 1:
				await dungeon.advance_sector_from_debug()
				await _await_result(dungeon)
				var persistence: bool = RunState.player_health == saved_hp and is_equal_approx(RunState.oxygen_current, saved_o2) and RunState.character_stats == saved_stats and DNAManager.dna == saved_dna and RunState.equipped_loadout == saved_loadout
				var counts: Dictionary = dungeon.get_runtime_counts()
				if not persistence or int(counts.regions) != 1 or int(counts.modules) <= 0:
					report.transition_failures.append("seed=%d sector=%d persistence=%s counts=%s" % [seed, sector_index, persistence, counts])
					run_valid = false
		if run_valid:
			report.passed_runs += 1
		else:
			report.failures.append("seed=%d path=%s error=%s" % [seed, path, dungeon.assembly_error])
		valid = valid and run_valid
	var deterministic := await _validate_determinism(dungeon) if first_seed == 65001 and last_seed == 65020 else true
	valid = valid and deterministic
	print("6K.4B FINAL range=%d-%d report=%s determinism=%s" % [first_seed, last_seed, report, deterministic])
	if valid and report.passed_runs == (last_seed - first_seed + 1):
		print("Stage6K.4B Varkhem physical final: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4B Varkhem physical final: FAIL")
		get_tree().quit(1)


func _await_result(dungeon: Node3D) -> void:
	for _frame in 900:
		if dungeon.nav_ready or not dungeon.assembly_error.is_empty(): return
		await get_tree().physics_frame


func _path_label(dungeon: Node3D) -> StringName:
	if dungeon.sector_run.sector_count() == 1: return &"GROUND_ONLY"
	return &"GROUND_BASEMENT" if dungeon.sector_run.get_sector(1).sector_id == &"BASEMENT" else &"GROUND_UPPER"


func _validate_sector(dungeon: Node3D, report: Dictionary, seed: int, sector_index: int) -> bool:
	report.sectors += 1
	var valid: bool = dungeon.assembly_valid and dungeon.nav_ready and dungeon.nav_region != null and dungeon.current_plan != null
	var plan: DungeonPlan = dungeon.current_plan
	var counts: Dictionary = dungeon.get_runtime_counts()
	var backtracks := int(counts.placement_backtracks)
	report.backtracks += backtracks
	if backtracks <= 2:
		report.backtrack_depth[backtracks] = int(report.backtrack_depth.get(backtracks, 0)) + 1
	else:
		report.backtrack_over_limit.append("seed=%d sector=%d backtracks=%d" % [seed, sector_index, backtracks])
		valid = false
	report.assembly_ms_total += int(dungeon.assembly_elapsed_ms)
	report.assembly_ms_max = maxi(int(report.assembly_ms_max), int(dungeon.assembly_elapsed_ms))
	if plan == null: return false
	for feasibility in plan.semantic_feasibility:
		report.feasibility_probes += 1
		if not bool(feasibility.get("accepted", false)): report.feasibility_rejected += 1
		var elapsed := int(feasibility.get("elapsed_ms", 0))
		report.feasibility_elapsed_ms += elapsed
		report.feasibility_elapsed_max = maxi(int(report.feasibility_elapsed_max), elapsed)
		var semantic_id: StringName = feasibility.get("semantic_id", &"")
		report.feasibility_by_semantic[semantic_id] = int(report.feasibility_by_semantic.get(semantic_id, 0)) + 1
	var profile: DungeonSizeProfileResource = dungeon.sector_run.sector_size_profiles[dungeon.current_sector_index]
	report.sizes[profile.size_id] = int(report.sizes.get(profile.size_id, 0)) + 1
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	var map: RID = dungeon.nav_region.get_navigation_map() if dungeon.nav_region != null else RID()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var exit := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	if not _has_path(map, start, exit) or not _has_path(map, exit, start):
		report.nav_failures.append("seed=%d sector=%d START<->EXIT" % [seed, sector_index])
		valid = false
	for seam in dungeon._seam_results:
		if not bool(seam.get("valid", false)):
			report.seams_invalid += 1
			valid = false
	for entry in dungeon.assembly_trace:
		if entry.get("status", "") == "CANDIDATE" and not (entry.get("conflicts", []) as Array).is_empty(): report.overlaps_rejected += 1
		if entry.get("status", "") == "PLACED" and not (entry.get("conflicts", []) as Array).is_empty(): report.overlaps_accepted += 1; valid = false
	for location in plan.semantic_locations:
		var id: StringName = location.definition.semantic_id
		if not EXPECTED.has(id): continue
		var expected: Dictionary = EXPECTED[id]
		var definition: ModuleDefinitionResource = plan.module_definitions.get(location.node_id, null)
		var module := root.get_node_or_null(NodePath(String(location.node_id))) as Node3D
		var footprint: Vector2 = module.get_meta("footprint_size", Vector2.ZERO) if module != null else Vector2.ZERO
		var actual_trace := _placed_trace_definition(dungeon, location.node_id)
		var semantic_valid: bool = definition != null and definition.stable_id == expected.definition and actual_trace == expected.definition and footprint == expected.size
		if not semantic_valid:
			report.required_failures.append("seed=%d sector=%d semantic=%s node=%s def=%s trace=%s footprint=%s" % [seed, sector_index, id, location.node_id, definition.stable_id if definition != null else "NONE", actual_trace, footprint])
			valid = false
		else:
			report.variants[id] = int(report.variants.get(id, 0)) + 1
		var point := NavigationServer3D.map_get_closest_point(map, module.global_position + Vector3(0, 0.9, 0)) if module != null else Vector3.INF
		if not _has_path(map, start, point) or not _has_path(map, point, start):
			report.nav_failures.append("seed=%d sector=%d semantic=%s" % [seed, sector_index, id])
			valid = false
	if _has_semantic(plan, &"CENTRAL_HUB"):
		var hub_location := _semantic(plan, &"CENTRAL_HUB")
		var hub_node := root.get_node_or_null(NodePath(String(hub_location.node_id))) as Node3D
		var neighbors := _neighbors(plan, hub_location.node_id)
		valid = valid and hub_location.definition.space_kind == SemanticLocationResource.SpaceKind.TRANSIT and neighbors.size() >= 3 and hub_node != null
		if hub_node != null:
			var hub_point := NavigationServer3D.map_get_closest_point(map, hub_node.global_position + Vector3(0, 0.9, 0))
			for neighbor_id in neighbors:
				var neighbor := root.get_node_or_null(NodePath(String(neighbor_id))) as Node3D
				if neighbor == null or not _has_path(map, hub_point, NavigationServer3D.map_get_closest_point(map, neighbor.global_position + Vector3(0, 0.9, 0))): valid = false
	if int(counts.regions) != 1: valid = false
	return valid


func _placed_trace_definition(dungeon: Node3D, node_id: StringName) -> StringName:
	for entry in dungeon.assembly_trace:
		if entry.get("id", &"") == node_id and entry.get("status", "") == "PLACED": return entry.get("definition", &"")
	return &""


func _has_path(map: RID, from: Vector3, to: Vector3) -> bool:
	return not from.is_equal_approx(Vector3.ZERO) and NavigationServer3D.map_get_path(map, from, to, true).size() >= 2


func _semantic(plan: DungeonPlan, semantic_id: StringName) -> DungeonSemanticLocation:
	for location in plan.semantic_locations:
		if location.definition.semantic_id == semantic_id: return location
	return null


func _has_semantic(plan: DungeonPlan, semantic_id: StringName) -> bool:
	return _semantic(plan, semantic_id) != null


func _neighbors(plan: DungeonPlan, node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for child in plan.links.get(node_id, []):
		if not result.has(child): result.append(child)
	for source in plan.links:
		if (plan.links[source] as Array).has(node_id) and not result.has(source): result.append(source)
	return result


func _validate_determinism(dungeon: Node3D) -> bool:
	var selected: Dictionary = {&"GROUND_ONLY": 65001, &"GROUND_BASEMENT": 65003, &"GROUND_UPPER": 65005}
	var valid := true
	for path in selected:
		var seed := int(selected[path])
		await dungeon.regenerate(seed)
		await _await_result(dungeon)
		var first: Array[String] = []
		for index in range(dungeon.sector_run.sector_count()):
			first.append("%s|%s|%s" % [dungeon.current_plan.get_topology_signature(), dungeon.get_assembly_signature(), dungeon.get_selected_module_definitions()])
			if index < dungeon.sector_run.sector_count() - 1:
				await dungeon.advance_sector_from_debug(); await _await_result(dungeon)
		await dungeon.regenerate(seed)
		await _await_result(dungeon)
		var replay: Array[String] = []
		for index in range(dungeon.sector_run.sector_count()):
			replay.append("%s|%s|%s" % [dungeon.current_plan.get_topology_signature(), dungeon.get_assembly_signature(), dungeon.get_selected_module_definitions()])
			if index < dungeon.sector_run.sector_count() - 1:
				await dungeon.advance_sector_from_debug(); await _await_result(dungeon)
		print("6K.4B DETERMINISM path=%s seed=%d valid=%s" % [path, seed, first == replay])
		valid = valid and first == replay
	return valid
