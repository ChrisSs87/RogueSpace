extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const BASE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")

func _ready() -> void:
	var stats := {"runs": 0, "plans": 0, "invalid": 0, "sizes": {}, "paths": {}, "corridors": 0, "rooms": 0, "destinations": 0, "semantics": {}, "hub_connections_total": 0, "hub_connections_min": 99, "hub_connections_max": 0, "hub_three_plus": 0, "hub_count": 0, "command_depth_total": 0, "command_depth_min": 99, "command_depth_max": 0, "command_count": 0, "physical_variants": {}}
	var valid := true
	for seed in range(65001, 65101):
		var director: DungeonArchetypeDirector = DIRECTOR.new()
		var run: DungeonSectorRun = director.create_sector_run(BASE, seed)
		var duplicate: DungeonSectorRun = director.create_sector_run(BASE, seed)
		stats.runs += 1
		var path := &"GROUND_ONLY" if run.sector_count() == 1 else (&"GROUND_BASEMENT" if run.get_sector(1).sector_id == &"BASEMENT" else &"GROUND_UPPER")
		stats.paths[path] = int(stats.paths.get(path, 0)) + 1
		for index in range(run.sector_count()):
			var plan := director.build_sector_plan(run, index)
			var same := director.build_sector_plan(duplicate, index)
			stats.plans += 1
			var deterministic := plan != null and same != null and _signature(plan) == _signature(same)
			if plan == null or not plan.is_valid() or not deterministic:
				stats.invalid += 1
				valid = false
				continue
			var profile := run.sector_size_profiles[index]
			stats.sizes[profile.size_id] = int(stats.sizes.get(profile.size_id, 0)) + 1
			for role in plan.module_types.values():
				if role == &"CORRIDOR": stats.corridors += 1
				if role == &"ROOM" or role == &"SIDE_ROOM": stats.rooms += 1
			for location in plan.semantic_locations:
				var semantic: StringName = location.definition.semantic_id
				stats.semantics[semantic] = int(stats.semantics.get(semantic, 0)) + 1
				var variants: Array = plan.module_definition_variants.get(location.node_id, [])
				var physical := String(variants[0].stable_id) if not variants.is_empty() else "NONE"
				stats.physical_variants["%s:%s" % [semantic, physical]] = int(stats.physical_variants.get("%s:%s" % [semantic, physical], 0)) + 1
				if location.definition.space_kind == SemanticLocationResource.SpaceKind.DESTINATION: stats.destinations += 1
				if semantic == &"CENTRAL_HUB":
					var degree := _degree(plan, location.node_id)
					valid = valid and location.definition.space_kind == SemanticLocationResource.SpaceKind.TRANSIT and physical == "base_central_hub_large"
					stats.hub_count += 1; stats.hub_connections_total += degree; stats.hub_connections_min = mini(stats.hub_connections_min, degree); stats.hub_connections_max = maxi(stats.hub_connections_max, degree)
					if degree >= 3: stats.hub_three_plus += 1
				if semantic == &"COMMAND_ROOM":
					valid = valid and physical == "base_command_room" and location.depth_from_start >= 4
					stats.command_count += 1; stats.command_depth_total += location.depth_from_start; stats.command_depth_min = mini(stats.command_depth_min, location.depth_from_start); stats.command_depth_max = maxi(stats.command_depth_max, location.depth_from_start)
			if run.get_sector(index).sector_id == &"GROUND_FLOOR":
				valid = valid and _has_semantic(plan, &"BASE_ACCESS") and _has_semantic(plan, &"CENTRAL_HUB")
			if run.get_sector(index).sector_id == &"BASEMENT": valid = valid and _has_semantic(plan, &"PRISON")
	valid = valid and stats.invalid == 0 and stats.hub_count == 100 and stats.command_count == 100
	print("6K.4B Varkhem hierarchy stats=%s" % stats)
	if valid:
		print("Stage6K.4B Varkhem hierarchy logical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4B Varkhem hierarchy logical: FAIL")
		get_tree().quit(1)

func _has_semantic(plan: DungeonPlan, semantic_id: StringName) -> bool:
	for location in plan.semantic_locations:
		if location.definition.semantic_id == semantic_id: return true
	return false

func _degree(plan: DungeonPlan, node_id: StringName) -> int:
	var result := (plan.links.get(node_id, []) as Array).size()
	for parent in plan.links:
		if (plan.links[parent] as Array).has(node_id): result += 1
	return result

func _signature(plan: DungeonPlan) -> String:
	var entries: Array[String] = []
	for location in plan.semantic_locations:
		var variants: Array = plan.module_definition_variants.get(location.node_id, [])
		var physical := String(variants[0].stable_id) if not variants.is_empty() else "NONE"
		entries.append("%s@%s:%s" % [location.definition.semantic_id, location.node_id, physical])
	entries.sort()
	return "%s|%s" % [plan.get_topology_signature(), "|".join(entries)]
