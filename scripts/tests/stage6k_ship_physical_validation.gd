extends Node3D

const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")

func _ready() -> void:
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 0
	dungeon.initial_seed = 64001
	add_child(dungeon)
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	var valid := true
	var used: Dictionary = {}
	for wanted in [&"SMALL", &"MEDIUM", &"LARGE"]:
		var seed := _seed_for_size(wanted)
		if seed < 0:
			valid = false
			continue
		await dungeon.regenerate(seed)
		valid = valid and await _validate(dungeon, wanted)
		used[wanted] = seed
	print("6K physical ship seeds=%s valid=%s" % [used, valid])
	if valid:
		print("Stage6K ship physical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K ship physical: FAIL")
		get_tree().quit(1)

func _seed_for_size(wanted: StringName) -> int:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	for seed in range(64001, 64021):
		var run := director.create_sector_run(SHIP, seed)
		if run.sector_size_profiles[0].size_id == wanted:
			return seed
	return -1

func _validate(dungeon: Node3D, wanted: StringName) -> bool:
	if not dungeon.assembly_valid or not dungeon.nav_ready or dungeon.nav_region == null:
		return false
	var cargo: DungeonSemanticLocation = null
	for location in dungeon.current_plan.semantic_locations:
		if location.definition.semantic_id == &"CARGO_HOLD": cargo = location
	if cargo == null:
		return false
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var cargo_point := NavigationServer3D.map_get_closest_point(map, cargo.global_transform.origin)
	var forward := await _walk(NavigationServer3D.map_get_path(map, start, cargo_point, true), start, cargo_point)
	var reverse := await _walk(NavigationServer3D.map_get_path(map, cargo_point, start, true), cargo_point, start)
	var all_accessible := true
	for location in dungeon.current_plan.semantic_locations:
		var point := NavigationServer3D.map_get_closest_point(map, location.global_transform.origin)
		all_accessible = all_accessible and NavigationServer3D.map_get_path(map, start, point, true).size() > 1
	var size_ok: bool = dungeon.sector_run.sector_size_profiles[0].size_id == wanted
	print("6K physical seed=%d size=%s assembly=%s seams=%s cargo_depth=%d forward=%s reverse=%s all_semantic=%s" % [dungeon.seed, wanted, dungeon.assembly_valid, dungeon._seam_results.size(), cargo.depth_from_start, forward, reverse, all_accessible])
	return size_ok and forward and reverse and all_accessible

func _walk(path: PackedVector3Array, start: Vector3, target: Vector3) -> bool:
	if path.size() < 2: return false
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	add_child(body)
	body.global_position = Vector3(start.x, 0.9, start.z)
	var index := 1
	for _tick in 1400:
		while index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[index].x, path[index].z)) < 0.8: index += 1
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
