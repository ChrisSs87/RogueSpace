extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")
const VARKHEM := preload("res://resources/run/test_archetypes/VarkhemBase.tres")
const HORVEX := preload("res://resources/run/test_archetypes/HorvexNest.tres")

func _ready() -> void:
	var valid := true
	var summaries: Dictionary = {}
	for archetype in [SHIP, VARKHEM, HORVEX]:
		var summary := _sample(archetype)
		summaries[archetype.archetype_id] = summary
		valid = valid and bool(summary.deterministic) and int(summary.invalid) == 0
	var ship: Dictionary = summaries[&"ABANDONED_SHIP"]
	var base: Dictionary = summaries[&"VARKHEM_BASE"]
	var nest: Dictionary = summaries[&"HORVEX_NEST"]
	# Relaciones estructurales: raw side nodes are not comparable between
	# archetypes. A ship uses terminal destination spurs; a base uses actual
	# exploratory decisions rooted in hubs/junctions.
	valid = valid and float(ship.corridors) > float(ship.rooms)
	valid = valid and int(ship.exploratory_branches) == 0 and int(ship.short_destination_spurs) > 0
	valid = valid and float(base.rooms) > float(base.corridors) and int(base.central_hubs) > 0
	valid = valid and int(base.exploratory_branches) > int(ship.exploratory_branches)
	valid = valid and int(base.real_decisions) > int(ship.real_decisions)
	valid = valid and float(nest.corridors) > float(nest.rooms) and float(nest.branches) >= float(ship.branches)
	valid = valid and int(ship.sectors_min) == 1 and int(ship.sectors_max) == 1
	valid = valid and int(nest.sectors_min) >= 2 and int(nest.sectors_max) <= 3
	for id in summaries:
		print("6J archetype=%s %s" % [id, summaries[id]])
	if valid:
		print("Stage6J archetype data: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6J archetype data: FAIL")
		get_tree().quit(1)

func _sample(archetype: DungeonArchetypeResource) -> Dictionary:
	var totals := {"corridors": 0, "rooms": 0, "junctions": 0, "branches": 0, "short_destination_spurs": 0, "exploratory_branches": 0, "real_decisions": 0, "reconnections": 0, "circuits": 0, "central_hubs": 0, "invalid": 0}
	var signatures: Dictionary = {}
	var deterministic := true
	var sectors_min := 99
	var sectors_max := 0
	for seed in range(63001, 63021):
		var director: DungeonArchetypeDirector = DIRECTOR.new()
		var run: DungeonSectorRun = director.create_sector_run(archetype, seed)
		var duplicate: DungeonSectorRun = director.create_sector_run(archetype, seed)
		if run.sector_count() != duplicate.sector_count() or run.selected_faction != duplicate.selected_faction:
			deterministic = false
		sectors_min = mini(sectors_min, run.sector_count())
		sectors_max = maxi(sectors_max, run.sector_count())
		for index in range(run.sector_count()):
			var plan := director.build_sector_plan(run, index)
			var plan_again := director.build_sector_plan(duplicate, index)
			if plan == null or not plan.is_valid():
				totals.invalid += 1
				continue
			if plan.get_topology_signature() != plan_again.get_topology_signature():
				deterministic = false
			signatures[plan.get_topology_signature()] = true
			for role in plan.module_types.values():
				match StringName(role):
					&"CORRIDOR": totals.corridors += 1
					# Both main-path rooms and terminal side rooms are physical
					# destinations. Structural density must count both.
					&"ROOM", &"SIDE_ROOM": totals.rooms += 1
					&"JUNCTION": totals.junctions += 1; totals.branches += 1
			for location in plan.semantic_locations:
				if location.definition.semantic_id == &"CENTRAL_HUB":
					totals.central_hubs += 1
			var branch_metrics := _branch_metrics(plan)
			totals.short_destination_spurs += int(branch_metrics.short_destination_spurs)
			totals.exploratory_branches += int(branch_metrics.exploratory_branches)
			totals.real_decisions += int(branch_metrics.real_decisions)
			totals.reconnections += plan.reconnections.size()
			totals.circuits += plan.get_independent_circuit_count()
	totals.deterministic = deterministic
	totals.signatures = signatures.size()
	totals.sectors_min = sectors_min
	totals.sectors_max = sectors_max
	return totals


func _branch_metrics(plan: DungeonPlan) -> Dictionary:
	var result := {"short_destination_spurs": 0, "exploratory_branches": 0, "real_decisions": 0}
	for node_id in plan.module_ids:
		if plan.module_types.get(node_id, &"") != &"JUNCTION":
			continue
		for child_variant in plan.links.get(node_id, []):
			var child_id: StringName = child_variant
			# 6K.4A: una reconexión vuelve a un nodo existente y es circulación,
			# no una rama de exploración aunque no pertenezca al main path lineal.
			if plan.reconnection_nodes.has(child_id):
				continue
			if plan.main_path_nodes.has(child_id):
				continue
			var branch_size := _branch_subtree_size(plan, child_id)
			if branch_size <= 1:
				result.short_destination_spurs += 1
			else:
				result.exploratory_branches += 1
				result.real_decisions += 1
	return result


func _branch_subtree_size(plan: DungeonPlan, node_id: StringName) -> int:
	var count := 1
	for child_variant in plan.links.get(node_id, []):
		count += _branch_subtree_size(plan, StringName(child_variant))
	return count
