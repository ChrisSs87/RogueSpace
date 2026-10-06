extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const NEST := preload("res://resources/run/test_archetypes/HorvexNest.tres")


func _ready() -> void:
	var valid := true
	var failures: Array[String] = []
	var metrics := {
		"runs_two": 0, "runs_three": 0, "plans": 0,
		"tunnels": 0, "turns": 0, "junctions": 0, "dead_ends": 0, "rooms": 0,
		"exploratory_branches": 0, "branch_depth_total": 0, "branch_depth_max": 0,
		"small": 0, "brood": 0, "remains": 0, "central": 0, "core": 0,
		"core_depth_total": 0, "core_depth_min": 999, "core_depth_max": 0,
	}
	for seed in range(66001, 66201):
		var result := _validate_run(seed, metrics)
		valid = valid and bool(result.valid)
		if not bool(result.valid):
			failures.append("%d:%s" % [seed, result.error])
	metrics.branch_depth_average = float(metrics.branch_depth_total) / float(maxi(1, int(metrics.exploratory_branches)))
	metrics.core_depth_average = float(metrics.core_depth_total) / float(maxi(1, int(metrics.core)))
	valid = valid and int(metrics.runs_two) + int(metrics.runs_three) == 200
	valid = valid and int(metrics.core) == 200 and int(metrics.dead_ends) > 0
	valid = valid and int(metrics.tunnels) > int(metrics.rooms) and int(metrics.turns) > 0 and int(metrics.exploratory_branches) > 0
	print("6K Horvex 200 logical metrics=%s" % metrics)
	if not failures.is_empty():
		print("6K Horvex logical failures=%s" % failures)
	if valid:
		print("Stage6K Horvex 200 logical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K Horvex 200 logical: FAIL")
		get_tree().quit(1)


func _validate_run(seed: int, metrics: Dictionary) -> Dictionary:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	var run: DungeonSectorRun = director.create_sector_run(NEST, seed)
	var duplicate: DungeonSectorRun = director.create_sector_run(NEST, seed)
	var valid := run.initialization_error.is_empty() and run.sector_count() >= 2 and run.sector_count() <= 3
	var error := run.initialization_error
	if run.sector_count() == 2: metrics.runs_two += 1
	if run.sector_count() == 3: metrics.runs_three += 1
	var core_count := 0
	for index in range(run.sector_count()):
		var plan := director.build_sector_plan(run, index)
		var same := director.build_sector_plan(duplicate, index)
		valid = valid and plan != null and plan.is_valid() and same != null and plan.get_topology_signature() == same.get_topology_signature() and _semantic_signature(plan) == _semantic_signature(same)
		if plan == null or not plan.is_valid():
			error = "generation=%s semantic=%s" % [plan.generation_error if plan != null else "null", plan.semantic_error if plan != null else "null"]
			continue
		metrics.plans += 1
		for role_variant in plan.module_types.values():
			match StringName(role_variant):
				&"CORRIDOR": metrics.tunnels += 1
				&"TURN_LEFT", &"TURN_RIGHT": metrics.turns += 1
				&"JUNCTION": metrics.junctions += 1
				&"DEAD_END": metrics.dead_ends += 1
				&"ROOM": metrics.rooms += 1
		for location in plan.semantic_locations:
			match location.definition.semantic_id:
				&"SMALL_CHAMBER": metrics.small += 1
				&"BROOD_CHAMBER": metrics.brood += 1
				&"REMAINS_CHAMBER": metrics.remains += 1
				&"CENTRAL_CHAMBER":
					metrics.central += 1
					valid = valid and location.definition.space_kind == SemanticLocationResource.SpaceKind.TRANSIT
				&"NEST_CORE":
					core_count += 1
					metrics.core += 1
					metrics.core_depth_total += location.depth_from_start
					metrics.core_depth_min = mini(int(metrics.core_depth_min), location.depth_from_start)
					metrics.core_depth_max = maxi(int(metrics.core_depth_max), location.depth_from_start)
					valid = valid and index == run.sector_count() - 1 and location.definition.space_kind == SemanticLocationResource.SpaceKind.DESTINATION and location.depth_from_start >= 5
		var branch_metrics := _branch_metrics(plan)
		metrics.exploratory_branches += int(branch_metrics.count)
		metrics.branch_depth_total += int(branch_metrics.depth_total)
		metrics.branch_depth_max = maxi(int(metrics.branch_depth_max), int(branch_metrics.depth_max))
		if index < run.sector_count() - 1:
			valid = valid and not _has_semantic(plan, &"NEST_CORE")
		else:
			valid = valid and _has_semantic(plan, &"NEST_CORE")
	valid = valid and core_count == 1
	if not valid and error.is_empty(): error = "semantic/sector contract"
	return {"valid": valid, "error": error}


func _branch_metrics(plan: DungeonPlan) -> Dictionary:
	var result := {"count": 0, "depth_total": 0, "depth_max": 0}
	for node_id in plan.module_ids:
		if plan.module_types.get(node_id, &"") != &"JUNCTION": continue
		for child_variant in plan.links.get(node_id, []):
			var child_id: StringName = child_variant
			if plan.main_path_nodes.has(child_id): continue
			var size := _subtree_size(plan, child_id)
			result.count += 1
			result.depth_total += size
			result.depth_max = maxi(int(result.depth_max), size)
	return result


func _subtree_size(plan: DungeonPlan, node_id: StringName) -> int:
	var total := 1
	for child_variant in plan.links.get(node_id, []): total += _subtree_size(plan, StringName(child_variant))
	return total


func _has_semantic(plan: DungeonPlan, semantic_id: StringName) -> bool:
	for location in plan.semantic_locations:
		if location.definition.semantic_id == semantic_id: return true
	return false


func _semantic_signature(plan: DungeonPlan) -> String:
	var parts: Array[String] = []
	for location in plan.semantic_locations: parts.append("%s@%s:%d" % [location.definition.semantic_id, location.node_id, location.depth_from_start])
	parts.sort()
	return "|".join(parts)
