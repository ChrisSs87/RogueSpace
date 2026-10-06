extends Node3D

## Gate físico 6K Parte 3. Consume el Nido lógico certificado tal cual está;
## no modifica roles, semánticas ni decisiones del assembler.
const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const NEST := preload("res://resources/run/test_archetypes/HorvexNest.tres")

const FIRST_SEED := 66001
const LAST_SEED := 66020
const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 1.8


func _ready() -> void:
	var bounds := _requested_seed_bounds()
	var first_seed: int = bounds.from
	var last_seed: int = bounds.to
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 2
	dungeon.initial_seed = first_seed
	add_child(dungeon)
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	var metrics := {
		"runs": 0, "sectors": 0, "two_sector_runs": 0, "three_sector_runs": 0,
		"modules": 0, "proxies": 0, "polygons": 0, "attempts": 0,
		"backtracks": 0, "backtrack_depth": 0, "assembly_ms": 0,
		"sector_attempt_0": 0, "sector_attempt_1": 0, "sector_attempt_2": 0,
		"sector_attempts_exhausted": 0, "effective_sector_seeds": [],
		"branches_walked": 0, "dead_ends_walked": 0, "central_transit_walked": 0,
		"small_seen": 0, "brood_seen": 0, "remains_seen": 0, "central_seen": 0,
		"central_physical": 0, "core_physical": 0,
		"base_physical_failures": 0, "required_candidate_failures": 0, "containment_failures": 0,
	}
	var valid := true
	var failures: Array[String] = []
	for seed in range(first_seed, last_seed + 1):
		var started := Time.get_ticks_msec()
		await dungeon.regenerate(seed)
		metrics.assembly_ms += Time.get_ticks_msec() - started
		var result := await _validate_run(dungeon, seed, metrics)
		if not bool(result.valid):
			valid = false
			failures.append("%d:%s" % [seed, result.error])
			break
		metrics.runs += 1
		if dungeon.sector_run.sector_count() == 2:
			metrics.two_sector_runs += 1
		else:
			metrics.three_sector_runs += 1
	# Reproducciones físicas completas: mismas definiciones, transforms y retry
	# efectivo. 66005 cubre explícitamente el caso de regeneración acotada.
	for seed in [66001, 66002, 66003, 66005]:
		if seed < first_seed or seed > last_seed:
			continue
		if not valid:
			break
		valid = valid and await _validate_determinism(dungeon, seed)
	print("6K Horvex physical metrics=%s failures=%s" % [metrics, failures])
	var expected_runs: int = last_seed - first_seed + 1
	var sector_mix_ok: bool = first_seed != FIRST_SEED or last_seed != LAST_SEED or (int(metrics.two_sector_runs) > 0 and int(metrics.three_sector_runs) > 0)
	if valid and metrics.runs == expected_runs and sector_mix_ok:
		print("Stage6K Horvex physical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K Horvex physical: FAIL")
		get_tree().quit(1)


func _requested_seed_bounds() -> Dictionary:
	var result := {"from": FIRST_SEED, "to": LAST_SEED}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--horvex-from="):
			result.from = int(arg.trim_prefix("--horvex-from="))
		elif arg.begins_with("--horvex-to="):
			result.to = int(arg.trim_prefix("--horvex-to="))
	result.from = clampi(int(result.from), FIRST_SEED, LAST_SEED)
	result.to = clampi(int(result.to), int(result.from), LAST_SEED)
	return result


func _validate_run(dungeon: Node3D, seed: int, metrics: Dictionary) -> Dictionary:
	if dungeon.sector_run == null or dungeon.sector_run.sector_count() < 2 or dungeon.sector_run.sector_count() > 3:
		return {"valid": false, "error": "invalid sector run"}
	var hp := RunState.player_health
	var oxygen := RunState.oxygen_current
	var damage_stat := RunState.character_stats.get_value(&"damage")
	var loadout := RunState.equipped_loadout
	var run_seed := RunState.run_seed
	for sector_index in range(dungeon.sector_run.sector_count()):
		var sector_result := await _validate_sector(dungeon, seed, sector_index, metrics)
		if not bool(sector_result.valid):
			return sector_result
		if sector_index < dungeon.sector_run.sector_count() - 1:
			var before: Dictionary = dungeon.get_runtime_counts()
			await dungeon.advance_sector_from_debug()
			var after: Dictionary = dungeon.get_runtime_counts()
			var persisted := RunState.player_health == hp and is_equal_approx(RunState.oxygen_current, oxygen) and RunState.character_stats.get_value(&"damage") == damage_stat and RunState.equipped_loadout == loadout and RunState.run_seed == run_seed
			var cleaned: bool = int(after.modules) == dungeon.module_count and int(after.proxies) == dungeon.proxies and int(after.regions) == 1 and int(before.regions) == 1
			if not persisted or not cleaned:
				return {"valid": false, "error": "transition persistence=%s cleanup=%s before=%s after=%s" % [persisted, cleaned, before, after]}
	return {"valid": true, "error": ""}


func _validate_sector(dungeon: Node3D, seed: int, sector_index: int, metrics: Dictionary) -> Dictionary:
	if not dungeon.assembly_valid or not dungeon.nav_ready or dungeon.nav_region == null or dungeon.current_plan == null:
		return {"valid": false, "error": "assembly/nav unavailable sector=%d assembly=%s nav=%s error=%s" % [sector_index, dungeon.assembly_valid, dungeon.nav_ready, dungeon.assembly_error]}
	var counts: Dictionary = dungeon.get_runtime_counts()
	if int(counts.modules) != dungeon.module_count or int(counts.proxies) != dungeon.proxies or int(counts.regions) != 1:
		return {"valid": false, "error": "residual counts sector=%d counts=%s" % [sector_index, counts]}
	if not bool(counts.enclosure_valid) or int(counts.enclosure_unsealed_unused) != 0:
		metrics.containment_failures += 1
		return {"valid": false, "error": "containment invalid sector=%d counts=%s" % [sector_index, counts]}
	for attempt_report in counts.sector_attempt_reports:
		if attempt_report.get("status", &"") == &"BASE_PHYSICAL_FAILURE":
			metrics.base_physical_failures += 1
		for feasibility in attempt_report.get("semantic_feasibility", []):
			if feasibility.get("status", &"") == &"REQUIRED_CANDIDATES_INVALID": metrics.required_candidate_failures += 1
	if dungeon._seam_results.is_empty() or dungeon.nav_mesh == null or dungeon.nav_mesh.get_polygon_count() <= 0:
		return {"valid": false, "error": "seam/nav mesh missing sector=%d seams=%d polygons=%d" % [sector_index, dungeon._seam_results.size(), dungeon.nav_mesh.get_polygon_count() if dungeon.nav_mesh != null else 0]}
	metrics.sectors += 1
	metrics.modules += dungeon.module_count
	metrics.proxies += dungeon.proxies
	metrics.polygons += dungeon.nav_mesh.get_polygon_count()
	metrics.attempts += int(counts.placement_candidates)
	metrics.backtracks += int(counts.placement_backtracks)
	metrics.backtrack_depth = maxi(int(metrics.backtrack_depth), (counts.placement_backtrack_nodes as Array).size())
	var sector_retry := int(counts.sector_retry_index)
	metrics["sector_attempt_%d" % sector_retry] = int(metrics.get("sector_attempt_%d" % sector_retry, 0)) + 1
	if sector_retry > 0:
		metrics.effective_sector_seeds.append({"run_seed": seed, "sector": sector_index, "retry": sector_retry, "effective_seed": int(counts.sector_effective_seed)})
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var exit := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	var core: DungeonSemanticLocation = null
	var central: DungeonSemanticLocation = null
	for location in dungeon.current_plan.semantic_locations:
		match location.definition.semantic_id:
			&"SMALL_CHAMBER": metrics.small_seen += 1
			&"BROOD_CHAMBER": metrics.brood_seen += 1
			&"REMAINS_CHAMBER": metrics.remains_seen += 1
			&"CENTRAL_CHAMBER":
				metrics.central_seen += 1
				central = location
			&"NEST_CORE": core = location
		var placed_definition: ModuleDefinitionResource = dungeon.current_plan.module_definitions.get(location.node_id, null)
		if location.definition.semantic_id == &"CENTRAL_CHAMBER":
			if placed_definition == null or placed_definition.stable_id != &"nest_central_chamber":
				return {"valid": false, "error": "CENTRAL_CHAMBER physical identity node=%s definition=%s" % [location.node_id, placed_definition.stable_id if placed_definition != null else &"NONE"]}
			metrics.central_physical += 1
		if location.definition.semantic_id == &"NEST_CORE":
			if placed_definition == null or placed_definition.stable_id != &"nest_core_chamber":
				return {"valid": false, "error": "NEST_CORE physical identity node=%s definition=%s" % [location.node_id, placed_definition.stable_id if placed_definition != null else &"NONE"]}
			metrics.core_physical += 1
		var point := NavigationServer3D.map_get_closest_point(map, location.global_transform.origin)
		if NavigationServer3D.map_get_path(map, start, point, true).size() < 2:
			return {"valid": false, "error": "semantic inaccessible sector=%d semantic=%s" % [sector_index, location.definition.semantic_id]}
	if sector_index < dungeon.sector_run.sector_count() - 1:
		if not await _walk(NavigationServer3D.map_get_path(map, start, exit, true), start, exit):
			return {"valid": false, "error": "START->EXIT blocked sector=%d" % sector_index}
		if not await _walk(NavigationServer3D.map_get_path(map, exit, start, true), exit, start):
			return {"valid": false, "error": "EXIT->START blocked sector=%d" % sector_index}
	else:
		if core == null:
			return {"valid": false, "error": "missing NEST_CORE final sector"}
		var core_point := NavigationServer3D.map_get_closest_point(map, core.global_transform.origin)
		if not await _walk(NavigationServer3D.map_get_path(map, start, core_point, true), start, core_point) or not await _walk(NavigationServer3D.map_get_path(map, core_point, start, true), core_point, start):
			return {"valid": false, "error": "NEST_CORE unreachable sector=%d" % sector_index}
	if central != null:
		var central_point := NavigationServer3D.map_get_closest_point(map, central.global_transform.origin)
		if not await _walk(NavigationServer3D.map_get_path(map, start, central_point, true), start, central_point):
			return {"valid": false, "error": "CENTRAL_CHAMBER blocked sector=%d" % sector_index}
		metrics.central_transit_walked += 1
	if (seed - FIRST_SEED) % 4 == 0:
		var branch_result := await _walk_representative_branch_and_dead_end(dungeon, map, start)
		if not bool(branch_result.valid):
			return branch_result
		metrics.branches_walked += int(branch_result.branch)
		metrics.dead_ends_walked += int(branch_result.dead_end)
	print("6K Horvex physical seed=%d sector=%d/%d retry=%d effective_seed=%d modules=%d proxies=%d polygons=%d backtracks=%d selected=%s" % [seed, sector_index + 1, dungeon.sector_run.sector_count(), sector_retry, int(counts.sector_effective_seed), dungeon.module_count, dungeon.proxies, dungeon.nav_mesh.get_polygon_count(), int(counts.placement_backtracks), dungeon.get_selected_module_definitions()])
	return {"valid": true, "error": ""}


func _walk_representative_branch_and_dead_end(dungeon: Node3D, map: RID, start: Vector3) -> Dictionary:
	var branch_node: StringName = &""
	var dead_end_node: StringName = &""
	for node_id_variant in dungeon.current_plan.module_ids:
		var node_id: StringName = node_id_variant
		if branch_node == &"" and not dungeon.current_plan.main_path_nodes.has(node_id):
			branch_node = node_id
		if dead_end_node == &"" and dungeon.current_plan.module_types.get(node_id, &"") == &"DEAD_END":
			dead_end_node = node_id
	for data in [{"id": branch_node, "key": "branch"}, {"id": dead_end_node, "key": "dead_end"}]:
		var node_id: StringName = data.id
		if node_id == &"":
			continue
		var transform: Transform3D = dungeon.current_plan.assembly_transforms.get(node_id, Transform3D.IDENTITY)
		var point := NavigationServer3D.map_get_closest_point(map, transform.origin)
		if not await _walk(NavigationServer3D.map_get_path(map, start, point, true), start, point):
			return {"valid": false, "error": "%s inaccessible node=%s" % [data.key, node_id]}
		if not await _walk(NavigationServer3D.map_get_path(map, point, start, true), point, start):
			return {"valid": false, "error": "%s cannot return node=%s" % [data.key, node_id]}
	return {"valid": true, "error": "", "branch": 1 if branch_node != &"" else 0, "dead_end": 1 if dead_end_node != &"" else 0}


func _validate_determinism(dungeon: Node3D, seed: int) -> bool:
	await dungeon.regenerate(seed)
	await _advance_to_final_sector(dungeon)
	var first_plan: String = dungeon.current_plan.get_topology_signature()
	var first_defs: String = str(dungeon.get_selected_module_definitions())
	var first_assembly: String = dungeon._assembly_signature
	var first_retry: int = dungeon.sector_retry_index
	var first_effective_seed: int = dungeon.sector_effective_seed
	await dungeon.regenerate(seed)
	await _advance_to_final_sector(dungeon)
	var valid: bool = dungeon.assembly_valid and dungeon.nav_ready and first_plan == dungeon.current_plan.get_topology_signature() and first_defs == str(dungeon.get_selected_module_definitions()) and first_assembly == dungeon._assembly_signature and first_retry == dungeon.sector_retry_index and first_effective_seed == dungeon.sector_effective_seed
	print("6K Horvex deterministic seed=%d retry=%d effective_seed=%d valid=%s" % [seed, first_retry, first_effective_seed, valid])
	return valid


func _advance_to_final_sector(dungeon: Node3D) -> void:
	while dungeon.sector_run != null and dungeon.current_sector_index < dungeon.sector_run.sector_count() - 1:
		await dungeon.advance_sector_from_debug()
		if not dungeon.assembly_valid or not dungeon.nav_ready:
			return


func _walk(path: PackedVector3Array, start: Vector3, target: Vector3) -> bool:
	if path.size() < 2:
		return false
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	collision.shape = capsule
	body.add_child(collision)
	add_child(body)
	body.global_position = Vector3(start.x, 0.9, start.z)
	var index := 1
	for _tick in 1800:
		while index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[index].x, path[index].z)) < 0.8:
			index += 1
		var goal: Vector3 = target if index >= path.size() else path[index]
		var direction := goal - body.global_position
		direction.y = 0.0
		body.velocity = direction.normalized() * 30.0 if direction.length() > 0.01 else Vector3.ZERO
		body.move_and_slide()
		if Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) < 0.35:
			body.queue_free()
			return true
		await get_tree().physics_frame
	body.queue_free()
	return false
