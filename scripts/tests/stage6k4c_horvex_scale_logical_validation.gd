extends Node

## Métrica lógica 6K.4C Parte 2.1. Lee sólo DungeonPlan/SemanticLocations;
## no invoca assembler, retry físico ni navegación.
const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const NEST := preload("res://resources/run/test_archetypes/HorvexNest.tres")
const FIRST_SEED := 66301
const RUN_COUNT := 200


func _ready() -> void:
	var metrics := {"runs_two": 0, "runs_three": 0, "plans": 0, "invalid": [], "levels": {}}
	for sector_id in [&"UPPER_NEST", &"DEEP_NEST", &"CORE_NEST"]:
		metrics.levels[sector_id] = _new_level_metrics()
	for seed in range(FIRST_SEED, FIRST_SEED + RUN_COUNT):
		_validate_run(seed, metrics)
	_finalize(metrics)
	var contract := _meets_scale_contract(metrics)
	print("6K.4C Horvex scale logical contract=%s metrics=%s" % [contract, metrics])
	if (metrics.invalid as Array).is_empty() and bool(contract.valid):
		print("Stage6K4C Horvex scale logical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K4C Horvex scale logical: FAIL invalid=%s contract=%s" % [metrics.invalid, contract])
		get_tree().quit(1)


func _new_level_metrics() -> Dictionary:
	return {"sectors": 0, "nodes": 0, "main_path": 0, "tunnels": 0, "turns": 0, "junctions": 0, "dead_ends": 0, "rooms": 0, "chambers": 0, "exploratory_branches": 0, "branch_depth_total": 0, "branch_depth_max": 0, "shortest_total": 0, "traversable_length_total": 0.0, "main_ratio_total": 0.0, "junction_density_total": 0.0, "tunnel_like_ratio_total": 0.0, "core_depth_total": 0, "core_depth_min": 999, "core_depth_max": 0, "small": 0, "brood": 0, "remains": 0, "central": 0, "core": 0}


func _validate_run(seed: int, metrics: Dictionary) -> void:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	var run: DungeonSectorRun = director.create_sector_run(NEST, seed)
	var duplicate: DungeonSectorRun = director.create_sector_run(NEST, seed)
	if not run.initialization_error.is_empty() or run.sector_count() < 2 or run.sector_count() > 3:
		metrics.invalid.append("%d:init:%s" % [seed, run.initialization_error])
		return
	if run.sector_count() == 2: metrics.runs_two += 1
	else: metrics.runs_three += 1
	var core_count := 0
	for index in range(run.sector_count()):
		var plan := director.build_sector_plan(run, index)
		var same := director.build_sector_plan(duplicate, index)
		if plan == null or not plan.is_valid() or same == null or plan.get_topology_signature() != same.get_topology_signature() or _semantic_signature(plan) != _semantic_signature(same):
			metrics.invalid.append("%d:sector=%d generation=%s semantic=%s" % [seed, index, plan.generation_error if plan != null else "null", plan.semantic_error if plan != null else "null"])
			continue
		metrics.plans += 1
		var sector_id: StringName = run.get_sector(index).sector_id
		var level: Dictionary = metrics.levels[sector_id]
		level.sectors += 1
		level.nodes += plan.module_ids.size()
		level.main_path += plan.main_path_nodes.size()
		var tunnel_like := 0
		var traversable_length := 0.0
		for node_id in plan.module_ids:
			var role: StringName = plan.module_types.get(node_id, &"")
			match role:
				&"CORRIDOR": level.tunnels += 1; tunnel_like += 1
				&"TURN_LEFT", &"TURN_RIGHT": level.turns += 1; tunnel_like += 1
				&"JUNCTION": level.junctions += 1; tunnel_like += 1
				&"DEAD_END": level.dead_ends += 1; tunnel_like += 1
				&"ROOM": level.rooms += 1
			var definition: ModuleDefinitionResource = plan.module_definitions.get(node_id, null)
			if definition != null:
				var footprint := definition.footprint_size
				traversable_length += maxf(footprint.x, footprint.y) if footprint.x > 0.0 and footprint.y > 0.0 else 8.0
		level.traversable_length_total += traversable_length
		var structural_nodes := maxi(1, plan.module_ids.size() - 2)
		level.main_ratio_total += float(plan.main_path_nodes.size()) / float(maxi(1, plan.module_ids.size()))
		level.junction_density_total += float(level.junctions) / float(maxi(1, level.nodes)) # corrected in _finalize from totals.
		level.tunnel_like_ratio_total += float(tunnel_like) / float(structural_nodes)
		var branch := _branch_metrics(plan)
		level.exploratory_branches += int(branch.count)
		level.branch_depth_total += int(branch.depth_total)
		level.branch_depth_max = maxi(int(level.branch_depth_max), int(branch.depth_max))
		var target: StringName = &"EXIT"
		for location in plan.semantic_locations:
			match location.definition.semantic_id:
				&"SMALL_CHAMBER": level.small += 1; level.chambers += 1
				&"BROOD_CHAMBER": level.brood += 1; level.chambers += 1
				&"REMAINS_CHAMBER": level.remains += 1; level.chambers += 1
				&"CENTRAL_CHAMBER": level.central += 1
				&"NEST_CORE":
					level.core += 1
					core_count += 1
					target = location.node_id
					level.core_depth_total += location.depth_from_start
					level.core_depth_min = mini(int(level.core_depth_min), location.depth_from_start)
					level.core_depth_max = maxi(int(level.core_depth_max), location.depth_from_start)
		level.shortest_total += plan.shortest_path_length(&"START", target)
		if index < run.sector_count() - 1 and _has_semantic(plan, &"NEST_CORE"):
			metrics.invalid.append("%d:NEST_CORE before final" % seed)
		if index == run.sector_count() - 1 and not _has_semantic(plan, &"NEST_CORE"):
			metrics.invalid.append("%d:NEST_CORE missing final" % seed)
	if core_count != 1:
		metrics.invalid.append("%d:core_count=%d" % [seed, core_count])


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


func _finalize(metrics: Dictionary) -> void:
	for level in metrics.levels.values():
		var sectors: int = maxi(1, int(level.sectors))
		level.avg_nodes = float(level.nodes) / sectors
		level.avg_main_path = float(level.main_path) / sectors
		level.avg_tunnels = float(level.tunnels) / sectors
		level.avg_turns = float(level.turns) / sectors
		level.avg_junctions = float(level.junctions) / sectors
		level.avg_dead_ends = float(level.dead_ends) / sectors
		level.avg_rooms = float(level.rooms) / sectors
		level.avg_chambers = float(level.chambers) / sectors
		level.avg_branches = float(level.exploratory_branches) / sectors
		level.avg_branch_depth = float(level.branch_depth_total) / float(maxi(1, int(level.exploratory_branches)))
		level.avg_shortest_path = float(level.shortest_total) / sectors
		level.avg_traversable_length = float(level.traversable_length_total) / sectors
		level.avg_main_ratio = float(level.main_ratio_total) / sectors
		level.junction_density = float(level.junctions) / float(maxi(1, int(level.nodes)))
		level.avg_tunnel_like_ratio = float(level.tunnel_like_ratio_total) / sectors
		if int(level.core) > 0:
			level.avg_core_depth = float(level.core_depth_total) / float(level.core)


func _meets_scale_contract(metrics: Dictionary) -> Dictionary:
	var upper: Dictionary = metrics.levels[&"UPPER_NEST"]
	var deep: Dictionary = metrics.levels[&"DEEP_NEST"]
	var core: Dictionary = metrics.levels[&"CORE_NEST"]
	var conditions := {
		"200_runs": int(metrics.runs_two) + int(metrics.runs_three) == RUN_COUNT,
		"all_plans": int(metrics.plans) == 504,
		"level2_complexity": float(deep.avg_nodes) > float(upper.avg_nodes) and float(deep.avg_junctions) > float(upper.avg_junctions) and float(deep.avg_dead_ends) > float(upper.avg_dead_ends) and float(deep.avg_turns) > float(upper.avg_turns) and float(deep.avg_branches) > float(upper.avg_branches) and float(deep.avg_shortest_path) > float(upper.avg_shortest_path),
		"level3_complexity": float(core.avg_nodes) >= float(deep.avg_nodes) and float(core.avg_turns) >= float(deep.avg_turns) and float(core.avg_junctions) >= float(deep.avg_junctions) and float(core.avg_dead_ends) >= float(deep.avg_dead_ends) and float(core.avg_branches) >= float(deep.avg_branches) and float(core.avg_shortest_path) >= float(deep.avg_shortest_path),
		"tunnel_dominance": float(upper.avg_tunnel_like_ratio) > 0.75 and float(deep.avg_tunnel_like_ratio) > 0.75 and float(core.avg_tunnel_like_ratio) > 0.75,
		"chambers_minor": float(upper.avg_rooms) < float(upper.avg_tunnels) and float(deep.avg_rooms) < float(deep.avg_tunnels) and float(core.avg_rooms) < float(core.avg_tunnels),
		"deep_core": int(core.core) == 104 and int(core.core_depth_min) >= 5,
	}
	var valid := true
	for condition in conditions.values(): valid = valid and bool(condition)
	return {"valid": valid, "conditions": conditions}
