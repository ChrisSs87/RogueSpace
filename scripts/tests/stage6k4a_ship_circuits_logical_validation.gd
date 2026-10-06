extends Node

## Gate lógico 6K.4A. No instancia módulos ni NavigationMesh: certifica que
## ABANDONED_SHIP expresa circulación y circuitos en el mismo DungeonPlan.
const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")

func _ready() -> void:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	var valid := true
	var stats := {"small": _empty_stats(), "medium": _empty_stats(), "large": _empty_stats()}
	var examples: Dictionary = {}
	for seed in range(67001, 67101):
		var run: DungeonSectorRun = director.create_sector_run(SHIP, seed)
		var same: DungeonSectorRun = director.create_sector_run(SHIP, seed)
		var plan: DungeonPlan = director.build_sector_plan(run, 0)
		var duplicate: DungeonPlan = director.build_sector_plan(same, 0)
		var size_id := String(run.sector_size_profiles[0].size_id).to_lower()
		var bucket: Dictionary = stats[size_id]
		bucket.plans += 1
		var seed_valid := plan != null and plan.is_valid() and duplicate != null and duplicate.is_valid()
		if seed_valid:
			seed_valid = plan.get_topology_signature() == duplicate.get_topology_signature() and _semantic_signature(plan) == _semantic_signature(duplicate) and _reconnection_signature(plan) == _reconnection_signature(duplicate)
			seed_valid = _has_mandatory_ship_semantics(plan) and _has_no_circulation_dead_ends(plan)
			_measure(bucket, plan)
			if size_id == "medium":
				seed_valid = plan.get_independent_circuit_count() >= 1 and _has_meaningful_alternative(plan)
			if size_id == "large":
				seed_valid = plan.get_independent_circuit_count() >= 1 and _has_meaningful_alternative(plan)
		if not seed_valid:
			valid = false
			print("6K.4A invalid seed=%d size=%s error=%s/%s links=%s reconnect=%s" % [seed, size_id, plan.generation_error if plan != null else "null", plan.semantic_error if plan != null else "null", plan.links if plan != null else {}, plan.reconnections if plan != null else []])
		if not examples.has(size_id): examples[size_id] = _format_example(seed, plan)
	# Contratos comparativos: SMALL puede ser lineal; MEDIUM debe tener un
	# circuito, y LARGE mantiene complejidad de circulación superior a SMALL.
	valid = valid and stats.medium.circuits >= stats.medium.plans
	valid = valid and stats.large.circuits >= stats.large.plans
	valid = valid and float(stats.large.reconnections) / maxf(1.0, stats.large.plans) > float(stats.small.reconnections) / maxf(1.0, stats.small.plans)
	print("6K.4A Ship circuit stats=%s" % stats)
	print("6K.4A topology examples=%s" % examples)
	if valid:
		print("Stage6K.4A Ship circuits logical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4A Ship circuits logical: FAIL")
		get_tree().quit(1)


func _empty_stats() -> Dictionary:
	return {"plans": 0, "main_path_length": 0, "corridors": 0, "rooms": 0, "junctions": 0, "terminal_destinations": 0, "reconnections": 0, "circuits": 0, "nodes_in_circuits": 0, "max_consecutive_corridors": 0, "cargo_shortest_path_total": 0, "cargo_alternative_routes": 0}


func _measure(stats: Dictionary, plan: DungeonPlan) -> void:
	stats.main_path_length += plan.main_path_nodes.size()
	stats.reconnections += plan.reconnections.size()
	stats.circuits += plan.get_independent_circuit_count()
	stats.max_consecutive_corridors = maxi(int(stats.max_consecutive_corridors), _max_main_corridor_run(plan))
	var adjacency := plan.get_undirected_adjacency()
	for id in plan.module_ids:
		var role: StringName = plan.module_types.get(id, &"")
		if role == &"CORRIDOR": stats.corridors += 1
		if role == &"ROOM": stats.rooms += 1
		if role == &"JUNCTION": stats.junctions += 1
		if adjacency.get(id, []).size() == 1 and _is_destination_node(plan, id): stats.terminal_destinations += 1
		if plan.has_alternative_route(&"START", id): stats.nodes_in_circuits += 1
	var cargo := _semantic_node(plan, &"CARGO_HOLD")
	if not cargo.is_empty():
		stats.cargo_shortest_path_total += plan.shortest_path_length(&"START", cargo)
		if plan.has_alternative_route(&"START", cargo): stats.cargo_alternative_routes += 1


func _has_mandatory_ship_semantics(plan: DungeonPlan) -> bool:
	return not _semantic_node(plan, &"AIRLOCK_SHIP_EXIT").is_empty() and not _semantic_node(plan, &"BRIDGE").is_empty() and not _semantic_node(plan, &"CARGO_HOLD").is_empty() and not _semantic_node(plan, &"CREW_QUARTERS").is_empty()


func _has_no_circulation_dead_ends(plan: DungeonPlan) -> bool:
	var adjacency := plan.get_undirected_adjacency()
	for id in plan.module_ids:
		if id in [&"START", &"EXIT"]: continue
		if adjacency.get(id, []).size() <= 1 and not _is_destination_node(plan, id): return false
	return true


func _is_destination_node(plan: DungeonPlan, node_id: StringName) -> bool:
	for location in plan.semantic_locations:
		if location.node_id == node_id and location.definition.space_kind == SemanticLocationResource.SpaceKind.DESTINATION:
			return true
	return plan.module_types.get(node_id, &"") in [&"ROOM", &"SIDE_ROOM"]


func _has_meaningful_alternative(plan: DungeonPlan) -> bool:
	var cargo := _semantic_node(plan, &"CARGO_HOLD")
	if not cargo.is_empty() and plan.has_alternative_route(&"START", cargo): return true
	for reconnect in plan.reconnections:
		if plan.has_alternative_route(reconnect.source, reconnect.target): return true
	return false


func _semantic_node(plan: DungeonPlan, semantic_id: StringName) -> StringName:
	for location in plan.semantic_locations:
		if location.definition.semantic_id == semantic_id: return location.node_id
	return &""


func _max_main_corridor_run(plan: DungeonPlan) -> int:
	var run := 0
	var maximum := 0
	for id in plan.module_ids:
		if not plan.main_path_nodes.has(id): continue
		if plan.module_types.get(id, &"") == &"CORRIDOR":
			run += 1
			maximum = maxi(maximum, run)
		else:
			run = 0
	return maximum


func _semantic_signature(plan: DungeonPlan) -> String:
	var values: Array[String] = []
	for location in plan.semantic_locations: values.append("%s@%s" % [location.definition.semantic_id, location.node_id])
	values.sort()
	return "|".join(values)


func _reconnection_signature(plan: DungeonPlan) -> String:
	var values: Array[String] = []
	for item in plan.reconnections: values.append("%s:%s>%s" % [item.id, item.source, item.target])
	values.sort()
	return "|".join(values)


func _format_example(seed: int, plan: DungeonPlan) -> String:
	if plan == null: return "seed=%d INVALID" % seed
	var edges: Array[String] = []
	for source in plan.links:
		for target in plan.links[source]: edges.append("%s→%s" % [source, target])
	edges.sort()
	return "seed=%d signature=%s circuits=%d reconnect=%s edges=[%s]" % [seed, plan.get_topology_signature(), plan.get_independent_circuit_count(), _reconnection_signature(plan), ", ".join(edges)]
