extends Node
const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const BASE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")

func _ready() -> void:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	var valid := true
	var stats := {"plans": 0, "ground_only": 0, "basement": 0, "upper": 0, "rooms": 0, "corridors": 0, "junctions": 0, "short_spurs": 0, "exploratory": 0, "command_depth_total": 0, "command_count": 0, "examples": []}
	for seed in range(65001, 65021):
		var run: DungeonSectorRun = director.create_sector_run(BASE, seed)
		var same: DungeonSectorRun = director.create_sector_run(BASE, seed)
		valid = valid and run.initialization_error.is_empty() and run.sector_count() >= 1 and run.sector_count() <= 2
		if run.sector_count() == 1: stats.ground_only += 1
		elif run.get_sector(1).sector_id == &"BASEMENT": stats.basement += 1
		else: stats.upper += 1
		var command_sector := &""
		for index in range(run.sector_count()):
			var plan := director.build_sector_plan(run, index)
			var duplicate := director.build_sector_plan(same, index)
			valid = valid and plan != null and plan.is_valid() and duplicate != null and plan.get_topology_signature() == duplicate.get_topology_signature() and _semantic_signature(plan) == _semantic_signature(duplicate)
			if plan == null or not plan.is_valid(): print("6K base invalid seed=%d sector=%d error=%s/%s" % [seed, index, plan.generation_error if plan != null else "null", plan.semantic_error if plan != null else "null"])
			var semantics := _by_id(plan)
			if index == 0: valid = valid and semantics.has(&"BASE_ACCESS") and semantics.has(&"CENTRAL_HUB")
			if run.get_sector(index).sector_id == &"BASEMENT": valid = valid and semantics.has(&"PRISON")
			if semantics.has(&"COMMAND_ROOM"):
				command_sector = run.get_sector(index).sector_id
				var command: DungeonSemanticLocation = semantics[&"COMMAND_ROOM"]
				valid = valid and command.depth_from_start >= 4
				stats.command_depth_total += command.depth_from_start; stats.command_count += 1
			for role in plan.module_types.values():
				if StringName(role) == &"ROOM": stats.rooms += 1
				if StringName(role) == &"SIDE_ROOM": stats.rooms += 1
				if StringName(role) == &"CORRIDOR": stats.corridors += 1
				if StringName(role) == &"JUNCTION": stats.junctions += 1
			for branch_id in plan.branch_nodes:
				var size := _subtree(plan, branch_id)
				if size == 1: stats.short_spurs += 1
				if size >= 2: stats.exploratory += 1
		valid = valid and not command_sector.is_empty()
		if command_sector.is_empty(): print("6K base missing command seed=%d sectors=%s" % [seed, _sector_label(run)])
		if run.sector_count() > 1 and run.get_sector(1).sector_id == &"UPPER_FLOOR": valid = valid and command_sector == &"UPPER_FLOOR"
		if seed in [65001, 65006, 65012]: stats.examples.append("seed=%d sectors=%s command=%s" % [seed, _sector_label(run), command_sector])
	valid = valid and stats.rooms > stats.corridors and stats.exploratory > 0 and stats.junctions > 0
	print("6K Varkhem stats=%s" % stats)
	if valid: print("Stage6K Varkhem semantic: PASS"); get_tree().quit(0)
	else: push_error("Stage6K Varkhem semantic: FAIL"); get_tree().quit(1)

func _by_id(plan: DungeonPlan) -> Dictionary:
	var result := {}
	for loc in plan.semantic_locations: result[loc.definition.semantic_id] = loc
	return result
func _semantic_signature(plan: DungeonPlan) -> String:
	var out: Array[String] = []
	for loc in plan.semantic_locations: out.append("%s@%s" % [loc.definition.semantic_id, loc.node_id])
	out.sort(); return "|".join(out)
func _subtree(plan: DungeonPlan, id: StringName) -> int:
	var result := 1
	for child in plan.links.get(id, []): result += _subtree(plan, child)
	return result
func _sector_label(run: DungeonSectorRun) -> String:
	var labels: Array[String] = []
	for sector in run.sector_definitions: labels.append(String(sector.sector_id))
	return ",".join(labels)
