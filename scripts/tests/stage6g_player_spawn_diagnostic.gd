extends Node3D

func _ready() -> void:
	var dungeon: Node3D = $Stage6GProceduralPrototype
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	var player: CharacterBody3D = dungeon.get_node("Player")
	var passed := true
	for test_seed in [61001, 61002, 61003]:
		await dungeon.regenerate(test_seed)
		for tick in 3:
			await get_tree().physics_frame
		var spawn := player.global_position
		var floor: bool = player.is_on_floor()
		var frozen: bool = player.is_frozen
		var map: RID = dungeon.nav_region.get_navigation_map()
		var nav_point := NavigationServer3D.map_get_closest_point(map, player.global_position)
		var nav_gap := player.global_position.distance_to(nav_point)
		var overlaps := _count_non_floor_overlaps(player)
		var forward_path := NavigationServer3D.map_get_path(map, nav_point, NavigationServer3D.map_get_closest_point(map, dungeon.exit_point), true)
		var reverse_path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, dungeon.exit_point), nav_point, true)
		Input.action_press("move_forward")
		for tick in 90:
			await get_tree().physics_frame
		Input.action_release("move_forward")
		var moved := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(spawn.x, spawn.z))
		var valid: bool = not frozen and overlaps == 0 and moved > 0.5 and forward_path.size() > 1 and reverse_path.size() > 1
		print("6G PLAYER SPAWN seed=%d | pos=%s start=%s floor=%s frozen=%s nav=%s gap=%.3f overlaps=%d forward=%d reverse=%d input=move_forward moved=%.3f velocity=%s touch=%s valid=%s" % [test_seed, player.global_position, dungeon.start_point, floor, frozen, nav_point, nav_gap, overlaps, forward_path.size(), reverse_path.size(), moved, player.velocity, player.touch_controls != null, valid])
		passed = passed and valid
	if passed:
		print("Stage6G player spawn diagnostic: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6G player spawn diagnostic: FAIL")
		get_tree().quit(1)


func _count_non_floor_overlaps(player: CharacterBody3D) -> int:
	var collision := player.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = player.global_transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var count := 0
	for hit in player.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider: Object = hit.get("collider") as Object
		if collider is CSGBox3D and (collider as CSGBox3D).size.y <= 0.5:
			continue
		count += 1
	return count
