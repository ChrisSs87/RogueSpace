extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")
const BASE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")

func _ready() -> void:
	var ship := _measure(SHIP, 64001, 20)
	var base := _measure(BASE, 64001, 20)
	print("6K Ship branch diagnostic=%s" % ship)
	print("6K Base legacy comparison=%s" % base)
	print("Stage6K ship branch diagnostic: PASS")
	get_tree().quit(0)

func _measure(archetype: DungeonArchetypeResource, first_seed: int, count: int) -> Dictionary:
	var result := {"small": _empty(), "medium": _empty(), "large": _empty(), "all": _empty()}
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	for seed in range(first_seed, first_seed + count):
		var run := director.create_sector_run(archetype, seed)
		for sector_index in range(run.sector_count()):
			var plan := director.build_sector_plan(run, sector_index)
			if plan == null or not plan.is_valid(): continue
			var bucket: Dictionary = result.all
			var size_id := "legacy"
			if sector_index < run.sector_size_profiles.size() and run.sector_size_profiles[sector_index] != null:
				size_id = String(run.sector_size_profiles[sector_index].size_id).to_lower()
				bucket = result[size_id]
			_accumulate(bucket, plan)
			if size_id != "legacy": _accumulate(result.all, plan)
	return result

func _empty() -> Dictionary:
	return {"plans": 0, "main_path_nodes": 0, "junctions": 0, "side_rooms": 0, "branches": 0, "branch_depth_total": 0, "branch_depth_max": 0, "semantic_destination_spurs": 0, "multi_node_branches": 0, "exploratory_branches": 0}

func _accumulate(stats: Dictionary, plan: DungeonPlan) -> void:
	stats.plans += 1
	stats.main_path_nodes += plan.main_path_nodes.size()
	for role in plan.module_types.values():
		if StringName(role) == &"JUNCTION": stats.junctions += 1
		if StringName(role) == &"SIDE_ROOM": stats.side_rooms += 1
	for branch_id in plan.branch_nodes:
		stats.branches += 1
		var depth := int(plan.node_depths.get(branch_id, 0))
		stats.branch_depth_total += depth
		stats.branch_depth_max = maxi(int(stats.branch_depth_max), depth)
		var child_count := _subtree_node_count(plan, branch_id)
		if child_count > 1: stats.multi_node_branches += 1
		if child_count > 2: stats.exploratory_branches += 1
		for location in plan.semantic_locations:
			if location.node_id == branch_id and location.definition.space_kind == SemanticLocationResource.SpaceKind.DESTINATION:
				stats.semantic_destination_spurs += 1
				break

func _subtree_node_count(plan: DungeonPlan, node_id: StringName) -> int:
	var count := 1
	for child in plan.links.get(node_id, []): count += _subtree_node_count(plan, child)
	return count
