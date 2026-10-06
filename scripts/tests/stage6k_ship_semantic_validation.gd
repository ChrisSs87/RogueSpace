extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")

func _ready() -> void:
	var director := DIRECTOR.new()
	var valid := true
	var stats := {"small": _size_stats(), "medium": _size_stats(), "large": _size_stats(), "factions": {}, "examples": []}
	for seed in range(64001, 64021):
		var run: DungeonSectorRun = director.create_sector_run(SHIP, seed)
		var same: DungeonSectorRun = director.create_sector_run(SHIP, seed)
		var plan := director.build_sector_plan(run, 0)
		var duplicate := director.build_sector_plan(same, 0)
		var size_profile: DungeonSizeProfileResource = run.sector_size_profiles[0]
		var size_stats: Dictionary = stats[String(size_profile.size_id).to_lower()]
		size_stats.count += 1
		size_stats.nodes += plan.module_ids.size() if plan != null else 0
		stats.factions[run.selected_faction] = int(stats.factions.get(run.selected_faction, 0)) + 1
		valid = valid and plan != null and plan.is_valid() and duplicate != null and duplicate.is_valid()
		if plan != null and not plan.is_valid():
			print("6K invalid seed=%d roles=%s generation_error=%s semantic_error=%s" % [seed, plan.module_types, plan.generation_error, plan.semantic_error])
		valid = valid and plan.get_topology_signature() == duplicate.get_topology_signature() and _semantic_signature(plan) == _semantic_signature(duplicate)
		var semantics := _by_id(plan)
		valid = valid and semantics.has(&"AIRLOCK_SHIP_EXIT") and semantics.has(&"BRIDGE") and semantics.has(&"CARGO_HOLD") and semantics.has(&"CREW_QUARTERS")
		valid = valid and (not semantics.has(&"LABORATORY") or (size_profile.size_id == &"LARGE"))
		valid = valid and _destination_chain_free(plan)
		for role in plan.module_types.values():
			match StringName(role):
				&"CORRIDOR": size_stats.corridors += 1
				&"ROOM": size_stats.rooms += 1
				&"JUNCTION": size_stats.branches += 1
		for id in semantics:
			if id == &"ENGINE_ROOM": size_stats.engine += 1
			if id == &"MEDBAY": size_stats.medbay += 1
			if id == &"LABORATORY": size_stats.laboratory += 1
		if seed in [64001, 64005, 64013]:
			var cargo_depth := int(semantics[&"CARGO_HOLD"].depth_from_start) if semantics.has(&"CARGO_HOLD") else -1
			stats.examples.append("seed=%d size=%s faction=%s semantic=%s cargo_depth=%d error=%s" % [seed, size_profile.size_id, run.selected_faction, _semantic_signature(plan), cargo_depth, plan.semantic_error])
	valid = valid and int(stats.small.corridors) > int(stats.small.rooms) and int(stats.medium.corridors) > int(stats.medium.rooms) and int(stats.large.corridors) > int(stats.large.rooms)
	valid = valid and int(stats.small.branches) <= int(stats.small.count) * 2 and int(stats.medium.branches) <= int(stats.medium.count) * 3 and int(stats.large.branches) <= int(stats.large.count) * 4
	print("6K ship stats=%s" % stats)
	if valid:
		print("Stage6K ship semantic: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K ship semantic: FAIL")
		get_tree().quit(1)

func _by_id(plan: DungeonPlan) -> Dictionary:
	var result := {}
	for location in plan.semantic_locations:
		result[location.definition.semantic_id] = location
	return result

func _semantic_signature(plan: DungeonPlan) -> String:
	var values: Array[String] = []
	for location in plan.semantic_locations:
		values.append("%s@%s:%d" % [location.definition.semantic_id, location.node_id, location.depth_from_start])
	values.sort()
	return "|".join(values)

func _destination_chain_free(plan: DungeonPlan) -> bool:
	var destination_nodes: Dictionary = {}
	for location in plan.semantic_locations:
		if location.definition.space_kind == SemanticLocationResource.SpaceKind.DESTINATION:
			destination_nodes[location.node_id] = true
	for node in destination_nodes:
		for child in plan.links.get(node, []):
			if destination_nodes.has(child): return false
	return true

func _size_stats() -> Dictionary:
	return {"count": 0, "nodes": 0, "corridors": 0, "rooms": 0, "branches": 0, "engine": 0, "medbay": 0, "laboratory": 0}
