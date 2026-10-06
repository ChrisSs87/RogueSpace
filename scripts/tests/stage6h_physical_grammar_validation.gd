extends Node3D

## Recorre representativos de ambos templates con la cápsula física real. No
## usa NavigationAgent, teleport ni stuck recovery.
func _ready() -> void:
	var dungeon: Node3D = $Stage6GProceduralPrototype
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	var valid := true
	var layouts := 0
	for seed in [61001, 61003]:
		dungeon.test_template_index = 0
		await dungeon.regenerate(seed)
		valid = valid and await _validate_layout(dungeon, false)
		layouts += 1
	for seed in [62001, 62002, 62003]:
		dungeon.test_template_index = 1
		await dungeon.regenerate(seed)
		valid = valid and await _validate_layout(dungeon, true)
		layouts += 1
	print("6H physical layouts=%d valid=%s" % [layouts, valid])
	if valid:
		print("Stage6H physical grammar: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6H physical grammar: FAIL")
		get_tree().quit(1)


func _validate_layout(dungeon: Node3D, requires_branch: bool) -> bool:
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var exit := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	var forward := await _walk(NavigationServer3D.map_get_path(map, start, exit, true), start, exit)
	var reverse := await _walk(NavigationServer3D.map_get_path(map, exit, start, true), exit, start)
	var branches_ok := true
	for branch in dungeon.get_branch_points():
		var branch_nav := NavigationServer3D.map_get_closest_point(map, branch)
		branches_ok = branches_ok and await _walk(NavigationServer3D.map_get_path(map, start, branch_nav, true), start, branch_nav)
	var has_corridor: bool = dungeon.current_plan.get_nodes_by_role(&"CORRIDOR").size() > 0
	var has_room: bool = dungeon.current_plan.get_nodes_by_role(&"ROOM").size() > 0
	var has_turn: bool = dungeon.current_plan.get_nodes_by_role(&"TURN_LEFT").size() + dungeon.current_plan.get_nodes_by_role(&"TURN_RIGHT").size() > 0
	var physical_vocabulary: bool = has_corridor or has_room or has_turn
	var branch_required_ok: bool = not requires_branch or (dungeon.get_branch_points().size() > 0 and branches_ok)
	var result: bool = dungeon.assembly_valid and dungeon.nav_ready and forward and reverse and branches_ok and branch_required_ok and physical_vocabulary
	print("6H physical template=%s seed=%d forward=%s reverse=%s branches=%s corridor=%s room=%s turn=%s valid=%s" % [dungeon.get_active_template_id(), dungeon.seed, forward, reverse, branches_ok, has_corridor, has_room, has_turn, result])
	return result


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
