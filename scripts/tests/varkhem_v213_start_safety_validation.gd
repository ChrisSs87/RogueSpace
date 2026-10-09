extends "res://scripts/tests/varkhem_v2_1_3_validation.gd"

func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	if not _interior_segment_case(dungeon): errors.append("interior segment / rotated safety regression")
	if not _coverage_conflict_case(dungeon): errors.append("START safety silently removed required coverage")
	if Vector2(dungeon.start_point.x,dungeon.start_point.z).distance_to(Vector2(dungeon.current_plan.assembly_transforms[&"START"].origin.x,dungeon.current_plan.assembly_transforms[&"START"].origin.z)) > 0.001:
		errors.append("START marker/root XZ contract changed")
	for slot: DungeonContentSlot in dungeon.current_content_plan.selected_slots:
		if not ContentPlacementDirector.patrol_start_exposure(slot,dungeon.current_plan,dungeon.current_content_profile).is_empty():
			errors.append("selected unsafe START patrol %s" % slot.unique_id)
	return errors

func _additional_physical_metrics(dungeon: Node3D) -> Dictionary:
	var result := super._additional_physical_metrics(dungeon)
	result["start_safety_rejections"] = dungeon.current_content_plan.start_safety_rejections
	return result

func _coverage_conflict_case(dungeon: Node3D) -> bool:
	# Isolated negative fixture: an oversized cloned range invalidates every
	# post. The selector must report the conflict, not return reduced coverage.
	var profile: ContentPlacementProfileResource = dungeon.current_content_profile.duplicate(true)
	for mapping in profile.runtime_category_pools:
		for entry in mapping.pool.entries:
			entry.payload = entry.payload.duplicate(true)
			(entry.payload as EnemyResource).vision_range_tiles = 100000.0
	var size_id: StringName = dungeon.sector_run.sector_size_profiles[dungeon.current_sector_index].size_id
	var result := ContentPlacementDirector.build(dungeon.current_plan,profile,dungeon.current_content_plan.seed,size_id)
	if result.is_valid() or result.generation_error.is_empty(): return false
	if not _hub_nodes(dungeon.current_plan).is_empty():
		return result.generation_error == "START safety conflicts with required coverage HUB_GUARD"
	return result.generation_error == "no slot group for required coverage ROUTE_GUARD"

func _interior_segment_case(dungeon: Node3D) -> bool:
	# Math-only adversarial route, NOT a navigation fixture: spawn and both
	# endpoints are outside range, but the segment crosses START. Actual pool
	# resources are used. Rotation/mirroring must not change the result.
	var plan: DungeonPlan = dungeon.current_plan.duplicate_for_assembly_probe()
	var slot := DungeonContentSlot.new()
	slot.category = &"ENCOUNTER"
	slot.node_id = &"NODE_0"
	slot.definition = load("res://resources/run/test_content_slots/varkhem_guard_corridor.tres").duplicate(true)
	slot.definition.patrol.footprint_points = [Vector2(-2,0),Vector2(2,0)]
	for angle in [0.0,PI/2,PI,-PI/2]:
		plan.assembly_transforms[&"NODE_0"] = Transform3D(Basis(Vector3.UP,angle),Vector3(11,0,0).rotated(Vector3.UP,angle))
		slot.global_transform = plan.assembly_transforms[&"NODE_0"]
		var points := ContentPatrolRoutes.planned_points(slot,plan)
		if points[0].length() <= 9 or points[1].length() <= 9: return false
		var result := ContentPlacementDirector.patrol_start_exposure(slot,plan,dungeon.current_content_profile)
		if result.is_empty() or float(result.minimum_distance_m) > 0.001: return false
	return true

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--dynamic-start"):
		await _dynamic_start()
		return
	await super._ready()

func _dynamic_start() -> void:
	var seeds: Array[int] = [65001,65002,65003,65004,65005,65006,65007,65008,65009,65010,65020]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--start-seeds="):
			seeds.clear()
			for value in argument.trim_prefix("--start-seeds=").split(","): seeds.append(int(value))
	var stage := load("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate() as Node3D
	stage.initial_seed = seeds[0]
	add_child(stage)
	await _await_sector(stage)
	var player: Node3D = stage.get_node("Player")
	player.set_physics_process(false)
	var rows: Array = []
	for run_seed in seeds:
		await stage.regenerate(run_seed)
		await _await_sector(stage)
		while true:
			var errors := _additional_physical_errors(stage)
			var row := {"seed":run_seed,"sector":stage.current_sector_index,"sector_id":stage.sector_run.sector_definitions[stage.current_sector_index].sector_id,"population":_additional_physical_metrics(stage).population,"rejections":stage.current_content_plan.start_safety_rejections,"errors":errors,"guards":[],"duration_sec":0.0,"limit_sec":0.0,"complete_cycles":false}
			var guards := {}
			var limit := 0.0
			for enemy: Enemy in stage.get_node("RuntimeContent").get_children():
				var points: Array = enemy.get_meta("patrol_world_points")
				var span := 0.0
				for index in range(1,points.size()): span += points[index-1].distance_to(points[index])
				# Two complete round trips AFTER first arrival, with real pauses and
				# enough time for full endpoint rotations. No accelerated time/AI.
				var speed: float = enemy._current_speed_mps()
				limit = maxf(limit,(enemy.global_position.distance_to(points[0])+4.0*span)/speed + 6.0*enemy.patrol_pause_sec + 6.0*360.0/enemy.patrol_turn_speed_deg)
				guards[enemy.get_instance_id()] = {"slot":str(enemy.get_meta("content_slot_id")),"kind":str(enemy.get_meta("patrol_kind")),"index":enemy.get_patrol_runtime_debug().patrol_index,"index_changes":0,"min_distance_m":INF,"sight":false,"max_stall_sec":0.0,"worst_forward_dot":1.0,"previous":enemy.global_position}
			row.limit_sec = limit
			var elapsed := 0.0
			while errors.is_empty() and elapsed < limit:
				await get_tree().physics_frame
				elapsed += get_physics_process_delta_time()
				var complete := true
				for enemy: Enemy in stage.get_node("RuntimeContent").get_children():
					var guard: Dictionary = guards[enemy.get_instance_id()]
					var debug := enemy.get_patrol_runtime_debug()
					if debug.patrol_index != guard.index:
						guard.index = debug.patrol_index
						guard.index_changes += 1
					complete = complete and guard.index_changes >= 5
					guard.min_distance_m = minf(guard.min_distance_m,enemy.global_position.distance_to(player.global_position))
					guard.sight = guard.sight or enemy._passes_vision_baseline(player)
					guard.max_stall_sec = maxf(guard.max_stall_sec,debug.stall_elapsed_sec)
					var motion: Vector3 = enemy.global_position-guard.previous
					motion.y = 0.0
					guard.previous = enemy.global_position
					if motion.length() > 0.001: guard.worst_forward_dot = minf(guard.worst_forward_dot,(-enemy.global_basis.z).dot(motion.normalized()))
					if guard.sight or enemy.get_debug_state_name() != "PATROL": errors.append("START sensory contact %s state=%s" % [guard.slot,enemy.get_debug_state_name()])
					if debug.stall_elapsed_sec > 2.0: errors.append("stalled patrol %s" % guard.slot)
				if player.is_frozen or CombatEncounterManager.is_encounter_active() or CombatManager.get_combatant_count() > 0: errors.append("START encounter/combat ownership")
				if complete:
					row.complete_cycles = true
					break
			if not row.complete_cycles: errors.append("did not observe two full patrol round trips")
			for guard in guards.values():
				guard.erase("previous")
				row.guards.append(guard)
			row.duration_sec = elapsed
			row.errors = errors
			rows.append(row)
			print("V213_START_CYCLES=%s" % JSON.stringify(row))
			if not errors.is_empty():
				print("V213_START_CYCLES_RESULT=%s" % JSON.stringify({"valid":false,"rows":rows.size(),"failure":row}))
				get_tree().quit(1)
				return
			if stage.current_sector_index == stage.sector_run.sector_count()-1: break
			await stage.advance_sector_from_debug()
			await _await_sector(stage)
	print("V213_START_CYCLES_RESULT=%s" % JSON.stringify({"valid":true,"runs":seeds.size(),"sectors":rows.size()}))
	get_tree().quit(0)
