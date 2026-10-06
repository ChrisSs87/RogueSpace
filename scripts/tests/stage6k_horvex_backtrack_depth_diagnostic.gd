extends Node3D

## Instrumentación temporal: cambia el presupuesto sólo en memoria para
## medir la profundidad mínima requerida por el mismo DungeonPlan de 66005.
const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const ARCHETYPE_DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")


func _ready() -> void:
	var depth := _requested_depth()
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 2
	dungeon.initial_seed = 66005
	add_child(dungeon)
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	var archetype_director: DungeonArchetypeDirector = ARCHETYPE_DIRECTOR.new()
	var target_template: DungeonTemplateResource = archetype_director.get_sector_template(dungeon.sector_run, 1)
	var original_depth: int = target_template.max_spatial_backtrack_depth
	target_template.max_spatial_backtrack_depth = depth
	await dungeon.advance_sector_from_debug()
	var plan_signature: String = dungeon.current_plan.get_topology_signature() if dungeon.current_plan != null else ""
	var semantic_signature: String = _semantic_signature(dungeon.current_plan)
	print("6K Horvex depth diagnostic depth=%d original=%d valid=%s nav=%s error=%s plan=%s semantics=%s stats=%s selected=%s" % [depth, original_depth, dungeon.assembly_valid, dungeon.nav_ready, dungeon.assembly_error, plan_signature, semantic_signature, dungeon.placement_stats, dungeon.get_selected_module_definitions()])
	for entry in dungeon.assembly_trace:
		if entry.status == "BACKTRACKED" or entry.status == "CANDIDATE":
			print("6K Horvex depth=%d decision=%s" % [depth, entry])
	target_template.max_spatial_backtrack_depth = original_depth
	get_tree().quit(0 if dungeon.assembly_valid and dungeon.nav_ready else 1)


func _requested_depth() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--depth="):
			return clampi(int(arg.trim_prefix("--depth=")), 0, 4)
	return 3


func _semantic_signature(plan: DungeonPlan) -> String:
	if plan == null:
		return ""
	var parts: Array[String] = []
	for location in plan.semantic_locations:
		parts.append("%s@%s" % [location.definition.semantic_id, location.node_id])
	parts.sort()
	return "|".join(parts)
