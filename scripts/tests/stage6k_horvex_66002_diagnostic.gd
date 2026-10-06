extends Node3D

const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")


func _ready() -> void:
	var seed := _requested_seed()
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 2
	dungeon.initial_seed = seed
	add_child(dungeon)
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	print("6K Horvex %d sector0 plan=%s definitions=%s" % [seed, dungeon.current_plan.get_topology_signature(), dungeon.get_selected_module_definitions()])
	await dungeon.advance_sector_from_debug()
	print("6K Horvex %d sector1 valid=%s error=%s stats=%s" % [seed, dungeon.assembly_valid, dungeon.assembly_error, dungeon.placement_stats])
	print("6K Horvex %d sector1 plan=%s" % [seed, _plan_report(dungeon.current_plan)])
	for entry in dungeon.assembly_trace:
		print("6K Horvex %d trace=%s" % [seed, entry])
	get_tree().quit(0)


func _requested_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return 66002


func _plan_report(plan: DungeonPlan) -> String:
	if plan == null:
		return "null"
	var rows: Array[String] = []
	for node_id_variant in plan.module_ids:
		var node_id: StringName = node_id_variant
		rows.append("%s[%s]->%s def=%s" % [node_id, plan.module_types.get(node_id, &""), plan.links.get(node_id, []), plan.module_definitions.get(node_id, null).stable_id if plan.module_definitions.get(node_id, null) != null else &""])
	return " | ".join(rows)
