extends Node3D
const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const BASE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")

func _ready() -> void:
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true; dungeon.test_archetype_index = 1; dungeon.initial_seed = 65001
	add_child(dungeon)
	while not dungeon.nav_ready: await get_tree().physics_frame
	var valid := true
	for path_id in [&"GROUND_ONLY", &"GROUND_BASEMENT", &"GROUND_UPPER"]:
		var seed := _seed_for_path(path_id)
		await dungeon.regenerate(seed)
		if not dungeon.assembly_valid:
			print("6K Base physical assembly failure path=%s seed=%d error=%s trace=%s" % [path_id, seed, dungeon.assembly_error, dungeon.assembly_trace])
			valid = false
			continue
		var ground_required: Array[StringName] = [&"CENTRAL_HUB"]
		if path_id == &"GROUND_ONLY":
			ground_required.append(&"COMMAND_ROOM")
		valid = valid and await _validate_sector(dungeon, ground_required)
		if dungeon.sector_run.sector_count() > 1:
			var hp: int = RunState.player_health; var oxygen: float = RunState.oxygen_current; var counts: Dictionary = dungeon.get_runtime_counts()
			await dungeon.advance_sector_from_debug()
			valid = valid and RunState.player_health == hp and is_equal_approx(RunState.oxygen_current, oxygen)
			valid = valid and int(dungeon.get_runtime_counts().regions) == 1 and int(counts.regions) == 1
			var second_required: Array[StringName] = []
			if path_id == &"GROUND_UPPER": second_required.append(&"COMMAND_ROOM")
			else: second_required.append(&"PRISON")
			valid = valid and await _validate_sector(dungeon, second_required)
		print("6K Base physical path=%s seed=%d valid=%s sector=%d/%d" % [path_id, seed, valid, dungeon.current_sector_index + 1, dungeon.sector_run.sector_count()])
	if valid: print("Stage6K Varkhem physical: PASS"); get_tree().quit(0)
	else: push_error("Stage6K Varkhem physical: FAIL"); get_tree().quit(1)

func _seed_for_path(wanted: StringName) -> int:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	for seed in range(65001, 65060):
		var run := director.create_sector_run(BASE, seed)
		var label: StringName = &"GROUND_ONLY" if run.sector_count() == 1 else StringName("GROUND_%s" % run.get_sector(1).sector_id.replace("_FLOOR", ""))
		if label == wanted: return seed
	return -1

func _validate_sector(dungeon: Node3D, required: Array[StringName]) -> bool:
	if not dungeon.assembly_valid or not dungeon.nav_ready: return false
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	for semantic_id in required:
		var location: DungeonSemanticLocation = null
		for item in dungeon.current_plan.semantic_locations:
			if item.definition.semantic_id == semantic_id: location = item
		if location == null: return false
		var point := NavigationServer3D.map_get_closest_point(map, location.global_transform.origin)
		if not await _walk(NavigationServer3D.map_get_path(map, start, point, true), start, point): return false
		if not await _walk(NavigationServer3D.map_get_path(map, point, start, true), point, start): return false
	return true

func _walk(path: PackedVector3Array, start: Vector3, target: Vector3) -> bool:
	if path.size() < 2: return false
	var body := CharacterBody3D.new(); var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4; capsule.height = 1.8; shape.shape = capsule; body.add_child(shape); add_child(body); body.global_position = Vector3(start.x, 0.9, start.z)
	var index := 1
	for _tick in 2000:
		while index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[index].x, path[index].z)) < 0.8: index += 1
		var goal: Vector3 = target if index >= path.size() else path[index]
		var direction := goal - body.global_position; direction.y = 0.0; body.velocity = direction.normalized() * 30.0 if direction.length() > 0.01 else Vector3.ZERO; body.move_and_slide()
		if Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) < 0.35: body.queue_free(); return true
		await get_tree().physics_frame
	body.queue_free(); return false
