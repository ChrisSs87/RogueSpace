extends Node3D

const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")


func _ready() -> void:
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65005
	add_child(dungeon)
	while dungeon.nav_sync_state == "SYNCING" or dungeon.nav_sync_state == "IDLE":
		await get_tree().physics_frame
	var topology: String = dungeon.current_plan.get_topology_signature()
	var semantics: String = _semantic_signature(dungeon.current_plan)
	var definitions: Dictionary = dungeon.get_selected_module_definitions()
	var counts: Dictionary = dungeon.get_runtime_counts()
	var used_standard := false
	for definition_id in definitions.values():
		used_standard = used_standard or definition_id == &"base_room"
	await dungeon.regenerate(65005)
	var second_counts: Dictionary = dungeon.get_runtime_counts()
	var deterministic: bool = topology == dungeon.current_plan.get_topology_signature() and semantics == _semantic_signature(dungeon.current_plan) and definitions == dungeon.get_selected_module_definitions()
	# base_room is the normal physical variant. compact remains available as a
	# geometry fallback and is deliberately not required by this seed.
	var compact_available: bool = dungeon.current_plan.module_definition_variants.has(&"NODE_1") or dungeon.current_plan.module_definition_variants.size() > 0
	var valid: bool = dungeon.assembly_valid and dungeon.nav_ready and used_standard and compact_available and deterministic
	valid = valid and int(counts.modules) == dungeon.module_count and int(counts.proxies) > 0 and int(counts.regions) == 1
	valid = valid and int(second_counts.modules) == dungeon.module_count and int(second_counts.proxies) > 0 and int(second_counts.regions) == 1
	print("6K.2 variants seed=65005 standard=%s compact_available=%s deterministic=%s modules=%d proxies=%d residual_regions=%d valid=%s" % [used_standard, compact_available, deterministic, int(second_counts.modules), int(second_counts.proxies), int(second_counts.regions), valid])
	if valid:
		print("Stage6K.2 module variants: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.2 module variants: FAIL")
		get_tree().quit(1)


func _semantic_signature(plan: DungeonPlan) -> String:
	var parts: Array[String] = []
	for location in plan.semantic_locations:
		parts.append("%s:%s:%d" % [location.definition.semantic_id, location.node_id, location.depth_from_start])
	parts.sort()
	return "|".join(parts)
