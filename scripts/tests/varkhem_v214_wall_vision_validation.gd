extends Node

func _ready() -> void:
	var stage := load("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate() as Node3D
	add_child(stage)
	var errors: Array[String] = []
	var reproduced := 0
	var checked := 0
	CombatEncounterManager.combat_transition_enabled = false
	for run_seed in [65001,65003,65005,65006]:
		await stage.regenerate(run_seed)
		for frame in 1200:
			await get_tree().physics_frame
			if stage.nav_ready and stage.assembly_valid: break
		var player: Node3D = stage.get_node("Player")
		player.set_physics_process(false)
		var enemy: Enemy = stage.get_node("RuntimeContent").get_child(0)
		for guard: Enemy in stage.get_node("RuntimeContent").get_children():
			guard.set_physics_process(false)
			guard.perception_timer.stop()
		# A real generated solid wall, not a mocked LOS result. Body centers at
		# their real spawn height; both eye endpoints must remain inside bodies.
		var fixture := _supported_wall(stage,enemy,&"CORRIDOR" if run_seed in [65001,65005] else &"JUNCTION")
		if fixture.is_empty():
			errors.append("no real generated wall with two supported capsule positions")
			break
		var wall: CSGBox3D = fixture.wall
		var normal: Vector3 = wall.global_basis.x if wall.size.x < wall.size.z else wall.global_basis.z
		normal.y = 0
		normal = normal.normalized()
		enemy.global_position = fixture.a
		player.global_position = fixture.b
		enemy.look_at(player.global_position,Vector3.UP)
		await get_tree().physics_frame
		var legacy_from := enemy.global_position+Vector3.UP*1.5
		var legacy_to := player.global_position+Vector3.UP
		var body_from := enemy.global_position+Vector3.UP*0.5
		var body_to: Vector3 = player.get_node("Head/Camera3D").global_position
		var space := stage.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(body_from,body_to,1))
		var visual := enemy._passes_vision_baseline(player)
		var legacy_clear := enemy._has_clear_line(legacy_from,legacy_to)
		if visual and not hit.is_empty(): reproduced += 1
		var row := {"seed":run_seed,"wall":str(wall.get_path()),"wall_size":wall.size,"wall_top_y":wall.global_position.y+wall.size.y/2,"body_from":body_from,"body_to":body_to,"legacy_from":legacy_from,"legacy_to":legacy_to,"legacy_clear":legacy_clear,"solid_wall_hit":not hit.is_empty(),"visual":visual}
		print("V214_WALL=%s" % JSON.stringify(row))
		if hit.is_empty(): errors.append("invalid wall fixture: body-height ray unblocked")
		if not OS.get_cmdline_user_args().has("--control") and visual: errors.append("vision crosses solid real wall")
		if not OS.get_cmdline_user_args().has("--control"):
			enemy._on_perception_tick()
			if enemy.get_debug_last_known_source() == "VISION": errors.append("wall created visual stimulus")
			EventBus.player_noise_emitted.emit(player.global_position,4,1)
			enemy._on_perception_tick()
			if enemy.get_debug_last_known_source() != "SOUND" or enemy._last_vision_result != enemy.VISION_NONE: errors.append("noise behind wall became vision")
			player.global_position = enemy.global_position-normal*1.2
			if not enemy._passes_vision_baseline(player):
				enemy.look_at(player.global_position,Vector3.UP)
			if not enemy._passes_vision_baseline(player): errors.append("open/reappearing target not visible")
			enemy._on_perception_tick()
			if enemy.get_debug_last_known_source() != "VISION": errors.append("reappearance did not renew real vision")
		checked += 1
		player.global_position = Vector3(-500,1,-500)
		CombatEncounterManager.reset()
	if OS.get_cmdline_user_args().has("--control"):
		print("V214_WALL_CONTROL=%s" % JSON.stringify({"reproduced":reproduced,"checked":checked,"errors":errors}))
	else:
		print("V214_WALL_RESULT=%s" % JSON.stringify({"valid":errors.is_empty(),"checked":checked,"errors":errors}))
	await stage.regenerate(stage.seed)
	get_tree().quit(0 if errors.is_empty() and (reproduced > 0 or not OS.get_cmdline_user_args().has("--control")) else 1)

func _supported_wall(stage: Node3D, enemy: Enemy, role: StringName) -> Dictionary:
	var map: RID = stage.nav_region.get_navigation_map()
	var space := stage.get_world_3d().direct_space_state
	var capsule := PhysicsShapeQueryParameters3D.new()
	capsule.shape = enemy.collision_shape.shape
	capsule.collision_mask = 1
	for module in stage.get_node("AssembledModules").get_children():
		if stage.current_plan.module_types.get(StringName(module.name)) != role: continue
		for wall in module.get_children():
			if not wall is CSGBox3D or not (wall.name.begins_with("Wall_") or wall.name.begins_with("DoorFrame_")): continue
			var normal: Vector3 = wall.global_basis.x if wall.size.x < wall.size.z else wall.global_basis.z
			var tangent: Vector3 = wall.global_basis.z if wall.size.x < wall.size.z else wall.global_basis.x
			var length: float = maxf(wall.size.x,wall.size.z)
			for fraction in [-0.3,0.0,0.3]:
				var center: Vector3 = wall.global_position+tangent*length*fraction
				center.y = stage.start_point.y
				var a := center-normal*1.2
				var b := center+normal*1.2
				var valid := true
				for point in [a,b]:
					var closest := NavigationServer3D.map_get_closest_point(map,point)
					if Vector2(closest.x-point.x,closest.z-point.z).length() > 0.12: valid = false
					capsule.transform = Transform3D(Basis(),point+Vector3.UP*0.04)
					if not space.intersect_shape(capsule).is_empty(): valid = false
				if valid: return {"wall":wall,"a":a,"b":b}
	return {}
