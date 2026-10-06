extends Node3D

const SCENE := preload("res://scenes/tests/Stage6JArchetypePrototype.tscn")

func _ready() -> void:
	var dungeon := SCENE.instantiate()
	add_child(dungeon)
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	var valid := true
	# Una generación física representativa por archetype, incluyendo el ciclo
	# de sector de Horvex. El recorrido usa cápsula real sin recovery.
	for archetype_index in [0, 1, 2]:
		dungeon.test_archetype_index = archetype_index
		await dungeon.regenerate(63001 + archetype_index)
		valid = valid and await _validate_navigation(dungeon)
		print("6J physical archetype=%s sectors=%d nav=%s modules=%d" % [dungeon.active_archetype.archetype_id, dungeon.sector_run.sector_count(), dungeon.nav_ready, dungeon.module_count])
	# Preservación deliberada de RunState a través de una transición real.
	dungeon.test_archetype_index = 2
	await dungeon.regenerate(63021)
	var hp := RunState.player_health
	var oxygen := RunState.oxygen_current
	var stats := RunState.character_stats.get_value(&"damage")
	if dungeon.sector_run.sector_count() > 1:
		await dungeon.advance_sector_from_debug()
		valid = valid and dungeon.current_sector_index == 1 and RunState.player_health == hp and is_equal_approx(RunState.oxygen_current, oxygen) and RunState.character_stats.get_value(&"damage") == stats
		valid = valid and await _validate_navigation(dungeon)
	var counts: Dictionary = dungeon.get_runtime_counts()
	valid = valid and int(counts.modules) == dungeon.module_count and int(counts.proxies) == dungeon.proxies and int(counts.regions) == 1
	print("6J transition preserve hp=%d o2=%.2f stats=%d counts=%s" % [RunState.player_health, RunState.oxygen_current, RunState.character_stats.get_value(&"damage"), counts])
	if valid:
		print("Stage6J physical sectors: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6J physical sectors: FAIL")
		get_tree().quit(1)

func _validate_navigation(dungeon: Node3D) -> bool:
	if not dungeon.assembly_valid or not dungeon.nav_ready or dungeon.nav_region == null:
		return false
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var finish := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	return await _walk(NavigationServer3D.map_get_path(map, start, finish, true), start, finish) and await _walk(NavigationServer3D.map_get_path(map, finish, start, true), finish, start)

func _walk(path: PackedVector3Array, start: Vector3, target: Vector3) -> bool:
	if path.size() < 2:
		return false
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
	for _tick in 1000:
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
