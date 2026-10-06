extends Node

const DIRECTOR := preload("res://scripts/world/RunDirector.gd")
const TEMPLATE_A := preload("res://resources/run/test_templates/TestCorridorHeavy.tres")
const TEMPLATE_B := preload("res://resources/run/test_templates/TestRoomBranchHeavy.tres")

func _ready() -> void:
	var report_a := _validate_template(TEMPLATE_A, "A")
	var report_b := _validate_template(TEMPLATE_B, "B")
	var contrast := float(report_a.corridors) > float(report_b.corridors) and float(report_b.rooms) > float(report_a.rooms) and int(report_b.branches) == 20
	var passed := bool(report_a.valid) and bool(report_b.valid) and contrast
	print("6H grammar A generations=%d signatures=%d modules(avg/min/max)=%.2f/%d/%d corridors=%.2f rooms=%.2f junctions=%d branches=%d dead_ends=%d" % [report_a.generations, report_a.signatures, report_a.modules_avg, report_a.modules_min, report_a.modules_max, report_a.corridors, report_a.rooms, report_a.junctions, report_a.branches, report_a.dead_ends])
	print("6H grammar B generations=%d signatures=%d modules(avg/min/max)=%.2f/%d/%d corridors=%.2f rooms=%.2f junctions=%d branches=%d dead_ends=%d" % [report_b.generations, report_b.signatures, report_b.modules_avg, report_b.modules_min, report_b.modules_max, report_b.corridors, report_b.rooms, report_b.junctions, report_b.branches, report_b.dead_ends])
	print("6H grammar contrast=%s" % contrast)
	if passed:
		print("Stage6H template grammar: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6H template grammar: FAIL")
		get_tree().quit(1)


func _validate_template(template: DungeonTemplateResource, label: String) -> Dictionary:
	var signatures: Dictionary = {}
	var total_modules := 0
	var min_modules := 9999
	var max_modules := 0
	var corridors := 0
	var rooms := 0
	var junctions := 0
	var branches := 0
	var dead_ends := 0
	var valid := true
	for seed in range(72001, 72021):
		var director: RunDirector = DIRECTOR.new()
		director.seed = seed
		director.current_node_id = &"STAGE6H_%s" % label
		var plan: DungeonPlan = director.build_plan(template)
		var replay: DungeonPlan = director.build_plan(template)
		var deterministic := plan.get_topology_signature() == replay.get_topology_signature() and plan.module_types == replay.module_types and plan.links == replay.links
		var definitions_valid := true
		for id in plan.module_ids:
			definitions_valid = definitions_valid and plan.module_definitions.has(id)
		var compatibility_valid := _plan_respects_declared_transitions(plan, template)
		valid = valid and plan.is_valid() and deterministic and definitions_valid and compatibility_valid
		signatures[plan.get_topology_signature()] = true
		total_modules += plan.module_ids.size()
		min_modules = mini(min_modules, plan.module_ids.size())
		max_modules = maxi(max_modules, plan.module_ids.size())
		corridors += plan.get_nodes_by_role(&"CORRIDOR").size()
		rooms += plan.get_nodes_by_role(&"ROOM").size()
		junctions += plan.get_nodes_by_role(&"JUNCTION").size()
		branches += plan.get_branch_node_ids().size()
		dead_ends += plan.get_nodes_by_role(&"SIDE_ROOM").size()
	return {
		"valid": valid, "generations": 20, "signatures": signatures.size(),
		"modules_avg": float(total_modules) / 20.0, "modules_min": min_modules, "modules_max": max_modules,
		"corridors": float(corridors) / 20.0, "rooms": float(rooms) / 20.0,
		"junctions": junctions, "branches": branches, "dead_ends": dead_ends,
	}


func _plan_respects_declared_transitions(plan: DungeonPlan, template: DungeonTemplateResource) -> bool:
	var main_roles: Array[StringName] = []
	for id in plan.module_ids:
		if plan.main_path_nodes.has(id):
			main_roles.append(plan.module_types.get(id, &""))
	for constraint in template.forbidden_role_sequences:
		if constraint == null or constraint.selector_pattern.is_empty():
			continue
		if constraint.selector_pattern.size() > main_roles.size():
			continue
		for first in range(main_roles.size() - constraint.selector_pattern.size() + 1):
			var matches := true
			for offset in range(constraint.selector_pattern.size()):
				var role: StringName = main_roles[first + offset]
				var definition: ModuleDefinitionResource = plan.module_definitions.get(_main_path_id_at(plan, first + offset), null)
				var selector: StringName = constraint.selector_pattern[offset]
				matches = matches and (role == selector or (definition != null and (definition.roles.has(selector) or definition.tags.has(selector))))
			if matches:
				return false
	return true


func _main_path_id_at(plan: DungeonPlan, index: int) -> StringName:
	var current := 0
	for id in plan.module_ids:
		if plan.main_path_nodes.has(id):
			if current == index:
				return id
			current += 1
	return &""
