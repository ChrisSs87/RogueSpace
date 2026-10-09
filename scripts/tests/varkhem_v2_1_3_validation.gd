extends "res://scripts/tests/varkhem_v2_1_2_validation.gd"

func _inspection_scene_path() -> String:
	return "res://scenes/tests/VarkhemV213ExperienceTest.tscn"


func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	var size_id: StringName = dungeon.sector_run.sector_size_profiles[dungeon.current_sector_index].size_id
	var profile: ContentPlacementProfileResource = dungeon.current_content_profile
	var bounds: Vector2i = profile.slot_count_ranges_by_size[size_id]
	var enemies := dungeon.get_node("RuntimeContent").get_children()
	if enemies.size() < bounds.x or enemies.size() > bounds.y: errors.append("size-specific population outside range")
	var hub := 0
	var route := 0
	for slot: DungeonContentSlot in dungeon.current_content_plan.selected_slots:
		if slot.tags.has(&"HUB_GUARD"): hub += 1
		if slot.tags.has(&"ROUTE_GUARD") and dungeon.current_plan.main_path_nodes.has(slot.node_id): route += 1
	var hub_nodes := _hub_nodes(dungeon.current_plan)
	if hub != (0 if hub_nodes.is_empty() else 2) or route < 1: errors.append("missing semantic hub pair or main route guard")
	for slot: DungeonContentSlot in dungeon.current_content_plan.selected_slots:
		if slot.tags.has(&"HUB_GUARD") and not hub_nodes.has(slot.node_id): errors.append("hub guard substituted outside semantic hub")
	# Rebuild with the exact real plan/size/seed: coverage must not change the
	# deterministic placement contract or silently lower the requested count.
	var replay := ContentPlacementDirector.build(dungeon.current_plan, profile, dungeon.current_content_plan.seed, size_id)
	if not replay.is_valid() or replay.get_signature() != dungeon.current_content_plan.get_signature(): errors.append("content coverage determinism")
	for a in enemies.size():
		for b in range(a+1,enemies.size()):
			var radius_a: float = enemies[a].get_node("CollisionShape3D").shape.radius
			var radius_b: float = enemies[b].get_node("CollisionShape3D").shape.radius
			if enemies[a].global_position.distance_to(enemies[b].global_position) < radius_a+radius_b: errors.append("initial enemy capsule overlap")
	return errors


func _hub_nodes(plan: DungeonPlan) -> Array[StringName]:
	var nodes: Array[StringName] = []
	for location: DungeonSemanticLocation in plan.semantic_locations:
		if location.definition.semantic_id == &"CENTRAL_HUB": nodes.append(location.node_id)
	return nodes


func _additional_physical_metrics(dungeon: Node3D) -> Dictionary:
	var result := super._additional_physical_metrics(dungeon)
	var roles := {}
	var hub := 0
	var main_guards := 0
	var assignments: Array = []
	for slot: DungeonContentSlot in dungeon.current_content_plan.selected_slots:
		var role: StringName = dungeon.current_plan.module_types[slot.node_id]
		roles[role] = int(roles.get(role,0))+1
		if slot.tags.has(&"HUB_GUARD"): hub += 1
		if dungeon.current_plan.main_path_nodes.has(slot.node_id): main_guards += 1
		assignments.append({"node":slot.node_id,"role":role,"slot":slot.unique_id,"tags":slot.tags,"patrol":slot.definition.patrol.stable_id if slot.definition.patrol != null else &""})
	result["sector_id"] = dungeon.sector_run.sector_definitions[dungeon.current_sector_index].sector_id
	result.population = {"total":dungeon.get_node("RuntimeContent").get_child_count(),"roles":roles,"hub":hub,"main_route":main_guards,"semantic_hubs":_hub_nodes(dungeon.current_plan),"assignments":assignments}
	return result

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--phase-a"):
		await _phase_a()
		return
	await super._ready()


func _phase_a() -> void:
	var stage := load("res://scenes/tests/VarkhemV212ExperienceTest.tscn").instantiate() as Node3D
	add_child(stage)
	await _await_sector(stage)
	var player: Node3D = stage.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-500,1,-500)
	var errors: Array = []
	# Existing real LOS/range/encounter controls, unchanged balance.
	for wall in [false,true]:
		var contact := await _contact_lifecycle(stage,player,wall)
		errors.append_array(contact.errors)
	await stage.regenerate(65001)
	await _await_sector(stage)
	player.global_position = Vector3(-500,1,-500)
	var enemy: Enemy = null
	for guard: Enemy in stage.get_node("RuntimeContent").get_children():
		if guard.get_meta("patrol_kind") == &"CORRIDOR": enemy = guard
	var points: Array = enemy.get_meta("patrol_world_points")
	enemy.set_physics_process(false)
	enemy.perception_timer.stop()
	enemy.global_position = points[0]
	enemy.look_at(points[1],Vector3.UP)
	player.global_position = enemy.global_position-enemy.global_basis.z*1.2
	await get_tree().physics_frame
	if not enemy._passes_vision_baseline(player): errors.append("invalid frontal stimulus")
	CombatEncounterManager.combat_transition_enabled = false
	enemy.perception_timer.start()
	await get_tree().create_timer(1.5).timeout
	var confirmed := enemy.get_debug_state_name() == "CHASE"
	var last_known := player.global_position
	player.global_position = Vector3(-500,1,-500)
	enemy.set_physics_process(true)
	var trace: Array = []
	var state_before := ""
	var arrived := false
	var returned := false
	for frame in 720:
		await get_tree().physics_frame
		var state := enemy.get_debug_state_name()
		if state != state_before:
			trace.append({"state":state,"position":enemy.global_position,"searching":enemy._searching_at_last_known,"last_known":enemy.get_debug_last_known_position()})
			state_before = state
		if state == "ALERT" and enemy._searching_at_last_known:
			arrived = enemy.global_position.distance_to(last_known) <= 0.4
		if arrived and state == "PATROL":
			returned = true
			break
	var samples: Array = []
	var worst := 1.0
	var previous := enemy.global_position
	for frame in 180:
		await get_tree().physics_frame
		var motion := enemy.global_position-previous
		motion.y = 0
		previous = enemy.global_position
		if motion.length() > 0.001:
			var dot := (-enemy.global_basis.z).dot(motion.normalized())
			worst = minf(worst,dot)
			if frame % 10 == 0: samples.append({"position":enemy.global_position,"forward":-enemy.global_basis.z,"motion":motion.normalized(),"dot":dot,"searching":enemy._searching_at_last_known})
	if not confirmed or not arrived or not returned: errors.append("contact/arrival/return failed")
	if enemy._searching_at_last_known: errors.append("PATROL retains SEARCH ownership")
	if worst < 0: errors.append("patrol moves backwards after search")
	print("V213_PHASE_A=%s" % JSON.stringify({"seed":65001,"confirmed":confirmed,"arrived":arrived,"returned":returned,"trace":trace,"orientation_samples":samples,"worst_forward_motion_dot":worst,"errors":errors}))
	CombatEncounterManager.combat_transition_enabled = true
	await stage.regenerate(65001)
	await _await_sector(stage)
	print("V213 phase A: %s" % ("PASS" if errors.is_empty() else "FAIL"))
	get_tree().quit(0 if errors.is_empty() else 1)
