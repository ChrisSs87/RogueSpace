extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const BASE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")
const HISTORICAL_FAILS: Array[int] = [63001, 63011, 63012, 63015, 63019, 63020, 65033, 65036, 65037, 65041, 65059]


func _ready() -> void:
	var seeds: Array[int] = []
	for seed in range(63001, 63021):
		seeds.append(seed)
	for seed in range(65001, 65181):
		seeds.append(seed)
	var valid := true
	var invalid: Array[String] = []
	var targeted: Dictionary = {}
	var sector_distribution: Dictionary = {&"GROUND_ONLY": 0, &"GROUND_BASEMENT": 0, &"GROUND_UPPER": 0}
	var command_depth_min := 999
	var command_depth_max := 0
	for seed in seeds:
		var result := _validate_seed(seed)
		valid = valid and bool(result.valid)
		if not bool(result.valid):
			invalid.append("%d:%s" % [seed, result.error])
		if HISTORICAL_FAILS.has(seed):
			targeted[seed] = result
		sector_distribution[result.path] = int(sector_distribution.get(result.path, 0)) + 1
		command_depth_min = mini(command_depth_min, int(result.command_depth))
		command_depth_max = maxi(command_depth_max, int(result.command_depth))
	for seed in HISTORICAL_FAILS:
		var item: Dictionary = targeted[seed]
		print("6K.2 targeted seed=%d valid=%s central=%s command_depth=%d deterministic=%s error=%s" % [seed, item.valid, item.central, item.command_depth, item.deterministic, item.error])
	print("6K.2 Varkhem 200 logical valid=%d invalid=%d paths=%s command_depth=%d..%d" % [seeds.size() - invalid.size(), invalid.size(), sector_distribution, command_depth_min, command_depth_max])
	if not invalid.is_empty():
		print("6K.2 Varkhem invalid=%s" % invalid)
	if valid and seeds.size() == 200:
		print("Stage6K.2 Varkhem 200 logical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.2 Varkhem 200 logical: FAIL")
		get_tree().quit(1)


func _validate_seed(seed: int) -> Dictionary:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	var run: DungeonSectorRun = director.create_sector_run(BASE, seed)
	var duplicate: DungeonSectorRun = director.create_sector_run(BASE, seed)
	var valid := run.initialization_error.is_empty() and run.sector_count() >= 1 and run.sector_count() <= 2
	var central := false
	var command_depth := -1
	var error := run.initialization_error
	for index in range(run.sector_count()):
		var sector: DungeonSectorDefinitionResource = run.get_sector(index)
		var plan := director.build_sector_plan(run, index)
		var same := director.build_sector_plan(duplicate, index)
		var deterministic := plan != null and same != null and plan.get_topology_signature() == same.get_topology_signature() and _semantic_signature(plan) == _semantic_signature(same)
		valid = valid and plan != null and plan.is_valid() and deterministic
		if plan == null or not plan.is_valid():
			error = "generation=%s semantic=%s" % [plan.generation_error if plan != null else "null", plan.semantic_error if plan != null else "null"]
			continue
		var semantic := _by_id(plan)
		if sector.sector_id == &"GROUND_FLOOR":
			central = semantic.has(&"CENTRAL_HUB") and plan.module_types.get(semantic[&"CENTRAL_HUB"].node_id, &"") == &"JUNCTION"
			valid = valid and semantic.has(&"BASE_ACCESS") and central
		if sector.sector_id == &"BASEMENT":
			valid = valid and semantic.has(&"PRISON")
		if semantic.has(&"COMMAND_ROOM"):
			command_depth = int(semantic[&"COMMAND_ROOM"].depth_from_start)
			valid = valid and command_depth >= 4
	var expected_upper := run.sector_count() > 1 and run.get_sector(1).sector_id == &"UPPER_FLOOR"
	valid = valid and command_depth >= 4
	if expected_upper:
		var upper_plan := director.build_sector_plan(run, 1)
		valid = valid and _by_id(upper_plan).has(&"COMMAND_ROOM")
	var deterministic_run := run.sector_count() == duplicate.sector_count()
	for index in range(run.sector_count()):
		deterministic_run = deterministic_run and director.build_sector_plan(run, index).get_topology_signature() == director.build_sector_plan(duplicate, index).get_topology_signature()
	valid = valid and deterministic_run
	var path := &"GROUND_ONLY"
	if run.sector_count() > 1:
		path = &"GROUND_BASEMENT" if run.get_sector(1).sector_id == &"BASEMENT" else &"GROUND_UPPER"
	return {"valid": valid, "central": central, "command_depth": command_depth, "deterministic": deterministic_run, "error": error, "path": path}


func _by_id(plan: DungeonPlan) -> Dictionary:
	var result := {}
	for location in plan.semantic_locations:
		result[location.definition.semantic_id] = location
	return result


func _semantic_signature(plan: DungeonPlan) -> String:
	var entries: Array[String] = []
	for location in plan.semantic_locations:
		entries.append("%s@%s:%d" % [location.definition.semantic_id, location.node_id, location.depth_from_start])
	entries.sort()
	return "|".join(entries)
