extends Node3D

const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")


func _ready() -> void:
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65001
	add_child(dungeon)
	while dungeon.nav_sync_state == "SYNCING" or dungeon.nav_sync_state == "IDLE":
		await get_tree().physics_frame
	var valid: bool = true
	var logical_plans := 0
	var assemblies := 0
	var compact_seeds: Dictionary = {}
	var definitions: Dictionary = {}
	var total_backtracks := 0
	var max_backtracks := 0
	var failures: Array[String] = []
	for seed in range(65001, 65021):
		await dungeon.regenerate(seed)
		var seed_valid: bool = true
		for sector_index in range(dungeon.sector_run.sector_count()):
			logical_plans += 1
			var sector_valid: bool = dungeon.current_plan != null and dungeon.current_plan.is_valid() and dungeon.assembly_valid and dungeon.nav_ready
			var counts: Dictionary = dungeon.get_runtime_counts()
			total_backtracks += int(counts.placement_backtracks)
			max_backtracks = maxi(max_backtracks, int(counts.placement_backtracks))
			for definition_id in dungeon.get_selected_module_definitions().values():
				definitions[definition_id] = int(definitions.get(definition_id, 0)) + 1
				if definition_id == &"base_room_compact":
					compact_seeds[seed] = true
			if not sector_valid:
				seed_valid = false
				failures.append("seed=%d sector=%d error=%s" % [seed, sector_index, dungeon.assembly_error])
			if sector_index < dungeon.sector_run.sector_count() - 1:
				await dungeon.advance_sector_from_debug()
		assemblies += 1 if seed_valid else 0
		valid = valid and seed_valid
	print("6K.2 Varkhem sample plans=%d assemblies=%d/20 compact_seed_count=%d definitions=%s backtracks_total=%d backtracks_max=%d failures=%s" % [logical_plans, assemblies, compact_seeds.size(), definitions, total_backtracks, max_backtracks, failures])
	if valid:
		print("Stage6K.2 Varkhem assembly sample: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.2 Varkhem assembly sample: FAIL")
		get_tree().quit(1)
