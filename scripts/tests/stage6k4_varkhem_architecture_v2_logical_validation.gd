extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const BASE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")
const TEMPLATE := preload("res://resources/run/test_templates/TestVarkhemBaseSemantic.tres")

func _ready() -> void:
	var report := {
		"runs": 0, "sectors": 0, "invalid": [], "sizes": {}, "paths": {},
		"main_rooms": 0, "non_leaf_rooms": [], "hub_degrees": {}, "corridor_child_counts": {},
		"command_depths": [], "command_non_terminal": [], "distribution_clearance_violations": [], "topologies": {}, "determinism_failures": [],
	}
	var valid := true
	var first_seed := 65001
	var last_seed := 65100
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		first_seed = int(args[0])
		last_seed = int(args[1])
	for seed in range(first_seed, last_seed + 1):
		var director: DungeonArchetypeDirector = DIRECTOR.new()
		var run: DungeonSectorRun = director.create_sector_run(BASE, seed)
		var duplicate: DungeonSectorRun = director.create_sector_run(BASE, seed)
		report.runs += 1
		report.paths[_path_label(run)] = int(report.paths.get(_path_label(run), 0)) + 1
		for sector_index in range(run.sector_count()):
			var plan := director.build_sector_plan(run, sector_index)
			var replay := director.build_sector_plan(duplicate, sector_index)
			report.sectors += 1
			if plan == null or not plan.is_valid():
				report.invalid.append("seed=%d sector=%d generation=%s semantic=%s" % [seed, sector_index, plan.generation_error if plan != null else "NULL", plan.semantic_error if plan != null else "NULL"])
				valid = false
				continue
			if replay == null or _signature(plan) != _signature(replay):
				report.determinism_failures.append("seed=%d sector=%d" % [seed, sector_index])
				valid = false
			var profile: DungeonSizeProfileResource = run.sector_size_profiles[sector_index]
			report.sizes[profile.size_id] = int(report.sizes.get(profile.size_id, 0)) + 1
			report.topologies[plan.get_topology_signature()] = true
			for node_id in plan.module_ids:
				if plan.module_types.get(node_id, &"") != &"ROOM":
					continue
				if plan.main_path_nodes.has(node_id):
					report.main_rooms += 1
					valid = false
				if not (plan.links.get(node_id, []) as Array).is_empty():
					report.non_leaf_rooms.append("seed=%d sector=%d room=%s children=%s" % [seed, sector_index, node_id, plan.links[node_id]])
					valid = false
			for node_id in plan.node_tags:
				var tags: Array = plan.node_tags[node_id]
				var degree := _degree(plan, node_id)
				if tags.has(&"HUB_DISTRIBUTION"):
					report.hub_degrees[degree] = int(report.hub_degrees.get(degree, 0)) + 1
				if tags.has(&"HUB_DISTRIBUTION") or tags.has(&"CORRIDOR_DISTRIBUTION"):
					var distribution_tag: StringName = &"HUB_DISTRIBUTION" if tags.has(&"HUB_DISTRIBUTION") else &"CORRIDOR_DISTRIBUTION"
					var rule := _branch_rule_for_tag(distribution_tag)
					if rule != null and rule.distribution_clearance_main_path_radius > 0 and rule.max_turns_in_distribution_clearance >= 0 and _main_path_turns_in_clearance_neighborhood(plan, node_id, rule.distribution_clearance_main_path_radius) > rule.max_turns_in_distribution_clearance:
						report.distribution_clearance_violations.append("seed=%d sector=%d node=%s" % [seed, sector_index, node_id])
						valid = false
				if tags.has(&"CORRIDOR_DISTRIBUTION"):
					var destinations := 0
					for child in plan.links.get(node_id, []):
						if plan.module_types.get(child, &"") == &"ROOM": destinations += 1
					report.corridor_child_counts[destinations] = int(report.corridor_child_counts.get(destinations, 0)) + 1
			for location in plan.semantic_locations:
				if location.definition.semantic_id == &"CENTRAL_HUB":
					valid = valid and (plan.node_tags.get(location.node_id, []) as Array).has(&"HUB_DISTRIBUTION") and _degree(plan, location.node_id) >= 3
				if location.definition.semantic_id == &"COMMAND_ROOM":
					report.command_depths.append(location.depth_from_start)
					if not plan.branch_nodes.has(location.node_id) or not (plan.links.get(location.node_id, []) as Array).is_empty():
						report.command_non_terminal.append("seed=%d sector=%d node=%s" % [seed, sector_index, location.node_id])
						valid = false
	valid = valid and report.invalid.is_empty() and report.determinism_failures.is_empty() and report.main_rooms == 0 and report.non_leaf_rooms.is_empty() and report.command_non_terminal.is_empty() and report.distribution_clearance_violations.is_empty() and report.hub_degrees.size() >= 2 and report.corridor_child_counts.size() >= 2
	var printable := report.duplicate()
	printable["topology_count"] = report.topologies.size()
	printable.erase("topologies")
	print("6K.4 Varkhem Architecture V2 logical report=%s" % printable)
	if valid:
		print("Stage6K.4 Varkhem Architecture V2 logical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4 Varkhem Architecture V2 logical: FAIL")
		get_tree().quit(1)

func _path_label(run: DungeonSectorRun) -> StringName:
	if run.sector_count() == 1:
		return &"GROUND_ONLY"
	return &"GROUND_BASEMENT" if run.get_sector(1).sector_id == &"BASEMENT" else &"GROUND_UPPER"

func _degree(plan: DungeonPlan, node_id: StringName) -> int:
	var count := (plan.links.get(node_id, []) as Array).size()
	for parent in plan.links:
		if (plan.links[parent] as Array).has(node_id): count += 1
	return count


func _branch_rule_for_tag(tag: StringName) -> DungeonBranchRuleResource:
	for rule in TEMPLATE.branch_rules:
		if rule != null and rule.parent_plan_tag == tag:
			return rule
	return null


func _main_path_turns_in_clearance_neighborhood(plan: DungeonPlan, node_id: StringName, radius: int) -> int:
	var main_path: Array[StringName] = []
	for current_id in plan.module_ids:
		if plan.main_path_nodes.has(current_id):
			main_path.append(current_id)
	var parent_index := main_path.find(node_id)
	if parent_index < 0:
		return 0
	var first := maxi(0, parent_index - radius)
	var last := mini(main_path.size() - 1, parent_index + radius)
	var count := 0
	for index in range(first, last + 1):
		if plan.module_types.get(main_path[index], &"") in [&"TURN_LEFT", &"TURN_RIGHT"]:
			count += 1
	return count

func _signature(plan: DungeonPlan) -> String:
	var entries: Array[String] = []
	for node_id in plan.module_ids:
		entries.append("%s:%s>%s#%s" % [node_id, plan.module_types.get(node_id, &""), plan.links.get(node_id, []), plan.node_tags.get(node_id, [])])
	return "|".join(entries)
