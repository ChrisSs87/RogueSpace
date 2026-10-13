extends "res://scripts/tests/stage6b_ambush_negatives_runtime.gd"

func _case_prior_contact() -> bool:
	# Exact original setup and deadline; diagnostic sampling only.
	var enemy := await _spawn("PriorContact")
	enemy.global_position = Vector3(12.0,1.0,-0.7)
	await get_tree().physics_frame
	var forward := -enemy.global_transform.basis.z.normalized()
	player.global_position = enemy.global_position+forward*1.0
	player.look_at(player.global_position+forward,Vector3.UP)
	var vision_confirmed := false
	for index in 180:
		await get_tree().physics_frame
		if index % 10 == 0:
			var eye := enemy.get_vision_origin()
			var target: Vector3 = player.get_node("Head").global_position
			var ray := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target,Enemy.WORLD_COLLISION_MASK,[enemy.get_rid()]))
			print("P0_AMBUSH_FIXTURE_TRACE="+JSON.stringify({"frame":index,"player":player.global_position,"enemy":enemy.global_position,"heading":-enemy.global_basis.z,"perception":enemy.get_cover_perception_debug(),"exposure":enemy._sight_timer,"vision":enemy._last_vision_result,"contact":enemy._current_contact_kind,"first_collider":str(ray.collider.get_path()) if not ray.is_empty() else "NONE","floor":player.is_on_floor(),"suspended":ExplorationState.is_suspended()}))
		if enemy._current_contact_kind == "VISION":
			vision_confirmed = true
			break
	if not vision_confirmed:
		print("P0_AMBUSH_FIXTURE_CLASSIFICATION=INCOMPLETE_PRIOR_CONTACT_ACQUISITION")
		await _dispose(enemy)
		return false
	player.global_position = enemy.global_position-forward*1.55
	player.look_at(player.global_position+forward,Vector3.UP)
	Input.action_press("stealth")
	Input.action_press("move_forward")
	var entered_zone := false
	for _i in 30:
		await get_tree().physics_frame
		if enemy.get_debug_ambush_conditions(player).in_zone:
			entered_zone = true
			break
	Input.action_release("move_forward")
	var result := vision_confirmed and entered_zone and not enemy.get_debug_ambush_candidate_registered()
	await _dispose(enemy)
	return result
