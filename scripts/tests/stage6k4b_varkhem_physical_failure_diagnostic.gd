extends Node

const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")

func _ready() -> void:
	var dungeon: Node3D = STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65015
	add_child(dungeon)
	await _await_result(dungeon)
	print("6K.4B FAIL DIAG GROUND valid=%s error=%s sector=%s semantics=%s" % [dungeon.assembly_valid, dungeon.assembly_error, dungeon.sector_run.get_sector(dungeon.current_sector_index).sector_id, _semantics(dungeon.current_plan)])
	await dungeon.advance_sector_from_debug()
	await _await_result(dungeon)
	print("6K.4B FAIL DIAG BASEMENT valid=%s error=%s sector=%s counts=%s" % [dungeon.assembly_valid, dungeon.assembly_error, dungeon.sector_run.get_sector(dungeon.current_sector_index).sector_id, dungeon.get_runtime_counts()])
	print("6K.4B FAIL DIAG PLAN nodes=%s links=%s semantics=%s" % [dungeon.current_plan.module_types, dungeon.current_plan.links, _semantics(dungeon.current_plan)])
	for entry in dungeon.assembly_trace:
		if entry.get("id", &"") in [&"NODE_3", &"NODE_4"] or entry.get("parent", &"") in [&"NODE_3", &"NODE_4"]:
			print("6K.4B FAIL DIAG TRACE %s" % entry)
	get_tree().quit(0)


func _await_result(dungeon: Node3D) -> void:
	for _frame in 900:
		if dungeon.nav_ready or not dungeon.assembly_error.is_empty(): return
		await get_tree().physics_frame


func _semantics(plan: DungeonPlan) -> Array[String]:
	var result: Array[String] = []
	if plan == null: return result
	for location in plan.semantic_locations:
		result.append("%s@%s" % [location.definition.semantic_id, location.node_id])
	return result
