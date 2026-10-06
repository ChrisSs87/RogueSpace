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
	var valid: bool = dungeon.assembly_valid and dungeon.nav_ready and dungeon.sector_run.sector_count() == 2
	valid = valid and dungeon.sector_run.get_sector(1).sector_id == &"UPPER_FLOOR"
	var ground_signature: String = dungeon.current_plan.get_topology_signature()
	# COMMAND_ROOM está preferentemente en UPPER_FLOOR; la planta baja sólo
	# debe garantizar el hub y la transición que conduce al objetivo.
	valid = valid and await _validate_required(dungeon, [&"CENTRAL_HUB"])
	var ground_counts: Dictionary = dungeon.get_runtime_counts()
	var hp: int = RunState.player_health
	var oxygen: float = RunState.oxygen_current
	if valid:
		await dungeon.advance_sector_from_debug()
		valid = valid and dungeon.assembly_valid and dungeon.nav_ready
		valid = valid and RunState.player_health == hp and is_equal_approx(RunState.oxygen_current, oxygen)
		valid = valid and await _validate_required(dungeon, [&"COMMAND_ROOM"])
		valid = valid and int(dungeon.get_runtime_counts().regions) == 1
	print("6K.2 seed=65005 plan=%s ground_defs=%s candidates=%d backtracks=%d nodes=%s valid=%s" % [ground_signature, dungeon.get_selected_module_definitions(), int(ground_counts.placement_candidates), int(ground_counts.placement_backtracks), ground_counts.placement_backtrack_nodes, valid])
	if valid:
		print("Stage6K.2 Varkhem 65005: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.2 Varkhem 65005: FAIL")
		get_tree().quit(1)


func _validate_required(dungeon: Node3D, required: Array[StringName]) -> bool:
	if not dungeon.assembly_valid or not dungeon.nav_ready:
		return false
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	for semantic_id in required:
		var location: DungeonSemanticLocation = null
		for item in dungeon.current_plan.semantic_locations:
			if item.definition.semantic_id == semantic_id:
				location = item
		if location == null:
			return false
		var target := NavigationServer3D.map_get_closest_point(map, location.global_transform.origin)
		if not await _walk(NavigationServer3D.map_get_path(map, start, target, true), start, target):
			return false
		if not await _walk(NavigationServer3D.map_get_path(map, target, start, true), target, start):
			return false
	return true


func _walk(path: PackedVector3Array, start: Vector3, target: Vector3) -> bool:
	if path.size() < 2:
		return false
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	add_child(body)
	body.global_position = Vector3(start.x, 0.9, start.z)
	var index := 1
	for _tick in 2000:
		while index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[index].x, path[index].z)) < 0.8:
			index += 1
		var goal: Vector3 = target if index >= path.size() else path[index]
		var direction := goal - body.global_position
		direction.y = 0.0
		body.velocity = direction.normalized() * 30.0 if direction.length() > 0.01 else Vector3.ZERO
		body.move_and_slide()
		if Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) < 0.35:
			body.queue_free()
			return true
		await get_tree().physics_frame
	body.queue_free()
	return false
