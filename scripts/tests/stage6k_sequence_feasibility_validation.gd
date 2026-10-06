extends Node

func _ready() -> void:
	var cardinal := _template(5, 5, 3, 1, -1)
	var sequential := _template(4, 4, 0, 2, 2)
	var valid_template := _template(5, 5, 1, 2, 2)
	var cardinal_error := cardinal.validate_cardinality()
	var sequence_error := sequential.validate_cardinality()
	var first := _plan(valid_template, 64101)
	var second := _plan(valid_template, 64101)
	var valid := cardinal_error.begins_with("INVALID TEMPLATE CARDINALITY") and sequence_error.begins_with("INVALID TEMPLATE SEQUENCE") and first.is_valid() and second.is_valid() and _counts_ok(first) and _max_consecutive_ok(first, &"ROOM", 1) and first.get_topology_signature() == second.get_topology_signature() and _roles(first) == _roles(second)
	print("6K sequence cardinal='%s' sequence='%s' roles=%s deterministic=%s" % [cardinal_error, sequence_error, _roles(first), _roles(first) == _roles(second)])
	if valid:
		print("Stage6K sequence feasibility: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K sequence feasibility: FAIL")
		get_tree().quit(1)

func _template(min_modules: int, max_modules: int, corridor_min: int, room_min: int, room_max: int) -> DungeonTemplateResource:
	var template := DungeonTemplateResource.new()
	template.min_modules = min_modules
	template.max_modules = max_modules
	var corridor := DungeonGrammarRuleResource.new()
	corridor.role = &"CORRIDOR"
	corridor.min_count = corridor_min
	corridor.max_count = maxi(corridor_min, 3)
	corridor.max_consecutive = 3
	corridor.selection_weight = 1.0
	var room := DungeonGrammarRuleResource.new()
	room.role = &"ROOM"
	room.min_count = room_min
	room.max_count = room_max if room_max >= 0 else room_min
	room.max_consecutive = 1
	room.selection_weight = 1.0
	template.grammar_rules = [corridor, room]
	return template

func _plan(template: DungeonTemplateResource, seed: int) -> DungeonPlan:
	var director := RunDirector.new()
	director.seed = seed
	director.current_node_id = &"SEQUENCE_TEST"
	return director.build_plan(template)

func _counts_ok(plan: DungeonPlan) -> bool:
	return plan.get_nodes_by_role(&"CORRIDOR").size() >= 1 and plan.get_nodes_by_role(&"ROOM").size() >= 2

func _max_consecutive_ok(plan: DungeonPlan, role: StringName, max_count: int) -> bool:
	var run := 0
	for node in plan.module_ids:
		if plan.module_types.get(node, &"") == role:
			run += 1
			if run > max_count: return false
		else:
			run = 0
	return true

func _roles(plan: DungeonPlan) -> String:
	var values: Array[String] = []
	for node in plan.module_ids: values.append(String(plan.module_types.get(node, &"")))
	return ",".join(values)
