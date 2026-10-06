extends Node3D

const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")


func _ready() -> void:
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65012
	add_child(dungeon)
	await get_tree().physics_frame
	while dungeon.nav_sync_state == "SYNCING" and dungeon.assembly_error.is_empty():
		await get_tree().physics_frame
	_report_plan(dungeon)
	_report_branch_attempts(dungeon)
	get_tree().quit(0)


func _report_plan(dungeon: Node3D) -> void:
	var plan: DungeonPlan = dungeon.current_plan
	var parents: Dictionary = {}
	for parent_id in plan.links:
		for child_id in plan.links[parent_id]:
			parents[child_id] = parent_id
	print("6K.2 DIAG seed=65012 assembly=%s error=%s topology=%s semantics=%s" % [dungeon.assembly_valid, dungeon.assembly_error, plan.get_topology_signature(), dungeon.get_semantic_location_metrics()])
	for id in plan.module_ids:
		var definition: ModuleDefinitionResource = plan.module_definitions.get(id, null)
		var variants: Array = plan.module_definition_variants.get(id, [])
		var variant_ids: Array[String] = []
		for variant in variants:
			variant_ids.append(String(variant.stable_id))
		var entries: Array = _trace_entries(dungeon, id)
		print("6K.2 NODE id=%s role=%s parent=%s children=%s main=%s branch=%s def=%s variants=%s transform=%s bounds=%s trace=%s" % [id, plan.module_types.get(id, &""), parents.get(id, &""), plan.links.get(id, []), plan.main_path_nodes.has(id), plan.branch_nodes.has(id), definition.stable_id if definition != null else &"NONE", variant_ids, plan.assembly_transforms.get(id, "UNPLACED"), _last_value(entries, "bounds", "UNPLACED"), entries])


func _report_branch_attempts(dungeon: Node3D) -> void:
	var plan: DungeonPlan = dungeon.current_plan
	var node_id: StringName = &"BRANCH_NODE_4_0"
	var entries: Array = _trace_entries(dungeon, node_id)
	print("6K.2 BRANCH target=%s role=%s available_variants=%s attempted=%s" % [node_id, plan.module_types.get(node_id, &""), _variant_ids(plan.module_definition_variants.get(node_id, [])), entries])
	for entry in entries:
		print("6K.2 BRANCH ATTEMPT source=%s incoming=%s definition=%s transform=%s bounds=%s seam=%s conflicts=%s status=%s" % [entry.get("source_connector", ""), entry.get("incoming_connector", ""), entry.get("definition", ""), entry.get("transform", ""), entry.get("bounds", ""), entry.get("seam_error", ""), entry.get("conflicts", []), entry.get("status", "")])


func _trace_entries(dungeon: Node3D, node_id: StringName) -> Array:
	var result: Array = []
	for entry in dungeon.assembly_trace:
		if entry.get("id", &"") == node_id:
			result.append(entry)
	return result


func _last_value(entries: Array, key: String, fallback: Variant) -> Variant:
	if entries.is_empty():
		return fallback
	return entries.back().get(key, fallback)


func _variant_ids(variants: Array) -> Array[String]:
	var result: Array[String] = []
	for variant in variants:
		result.append(String(variant.stable_id))
	return result
