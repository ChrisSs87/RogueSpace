extends Node

const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")

func _ready() -> void:
	var dungeon: Node3D = STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65003
	add_child(dungeon)
	await _await_result(dungeon)
	await dungeon.advance_sector_from_debug()
	await _await_result(dungeon)
	var plan: DungeonPlan = dungeon.current_plan
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	for location in plan.semantic_locations:
		if location.definition.semantic_id != &"BARRACKS": continue
		var node_id: StringName = location.node_id
		var module := root.get_node_or_null(NodePath(String(node_id))) as Node3D
		var parent := &""
		for source in plan.links:
			if (plan.links[source] as Array).has(node_id): parent = source
		var trace: Array[Dictionary] = []
		for entry in dungeon.assembly_trace:
			if entry.get("id", &"") == node_id: trace.append(entry)
		var definition: ModuleDefinitionResource = plan.module_definitions.get(node_id, null)
		print("6K.4B FALLBACK DIAG sector=%s semantic=%s node=%s parent=%s actual_definition=%s footprint=%s bounds=%s transform=%s variants=%s trace=%s" % [dungeon.sector_run.get_sector(dungeon.current_sector_index).sector_id, location.definition.semantic_id, node_id, parent, definition.stable_id if definition != null else "NONE", module.get_meta("footprint_size", Vector2.ZERO), dungeon._world_bounds(module), module.global_transform, plan.module_definition_variants.get(node_id, []), trace])
	print("6K.4B RUNTIME COUNTS %s" % dungeon.get_runtime_counts())
	get_tree().quit(0)

func _await_result(dungeon: Node3D) -> void:
	for _frame in 800:
		if dungeon.nav_ready or not dungeon.assembly_error.is_empty(): return
		await get_tree().physics_frame
