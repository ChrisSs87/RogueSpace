extends "res://scripts/tests/varkhem_v2_1_1_validation.gd"

var kinds := {}
var distribution := {"circulation":0,"rooms":0,"enemies":0,"hub_pairs":0}

func _inspection_scene_path() -> String:
	return "res://scenes/tests/VarkhemV212ExperienceTest.tscn"

func _additional_inspection_check(stage: Node3D) -> bool:
	var inspector := stage.get_node("Inspection")
	var player: Node3D = stage.get_node("Player")
	var transform := player.global_transform
	inspector._toggle_infiltration()
	var valid: bool = inspector.infiltration and inspector.details.visible and DebugConfig.perception_debug_enabled and player.global_transform == transform
	inspector._toggle_infiltration()
	return valid and not inspector.details.visible and not inspector.routes.visible and not stage.get_node("CombatUI").visible

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--main-route"):
		await _main_route()
		return
	if OS.get_cmdline_user_args().has("--behavior") or OS.get_cmdline_user_args().has("--contact"):
		await _behavior()
		return
	await super._ready()

func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	var report: Dictionary = dungeon.get_runtime_content_metrics()
	if not report.patrol_rejected.is_empty(): errors.append("rejected patrol %s" % report.patrol_rejected)
	var count: int = report.spawned.size()
	var profile: ContentPlacementProfileResource = dungeon.current_content_profile
	if count < profile.min_slots or count > profile.max_slots: errors.append("population outside configured budget")
	var circulation := 0
	var rooms := 0
	var hub := 0
	for slot: DungeonContentSlot in dungeon.current_content_plan.selected_slots:
		if slot.tags.has(&"CIRCULATION"): circulation += 1
		if slot.tags.has(&"ROOM"): rooms += 1
		if slot.definition.selection_group == &"hub_pair": hub += 1
	if circulation < 1 or rooms < 1: errors.append("missing room/circulation coverage")
	if hub not in [0,2]: errors.append("incomplete hub pair")
	for route in report.patrol_routes:
		kinds[route.kind] = int(kinds.get(route.kind,0))+1
	distribution.circulation += circulation
	distribution.rooms += rooms
	distribution.enemies += count
	distribution.hub_pairs += hub/2
	for enemy: Enemy in dungeon.get_node("RuntimeContent").get_children():
		if not enemy.enemy_resource.can_patrol or enemy.patrol_points.size() < 2: errors.append("no valid patrol")
		if enemy.global_position.distance_to(dungeon.start_point) < enemy.get_debug_fov_range_m(): errors.append("spawn inside START visual range")
	return errors

func _additional_physical_metrics(dungeon: Node3D) -> Dictionary:
	var result := super._additional_physical_metrics(dungeon)
	result["patrol_kinds_cumulative"] = kinds.duplicate()
	result["distribution_cumulative"] = distribution.duplicate()
	return result

func _behavior() -> void:
	var stage := load("res://scenes/tests/VarkhemV212ExperienceTest.tscn").instantiate() as Node3D
	add_child(stage)
	await _await_sector(stage)
	var errors: Array = []
	if not _invalid_route_rejected(stage): errors.append("invalid route spawned an Enemy")
	var player: Node3D = stage.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-500,1,-500)
	var coverage := {}
	var motion: Array = []
	# Multiple seeds, real live Enemy navigation/physics/timers, no manual AI tick.
	var motion_seeds := [65001,65002,65003,65004,65005,65015,65020]
	if OS.get_cmdline_user_args().has("--contact"): motion_seeds = []
	for run_seed in motion_seeds:
		await stage.regenerate(run_seed)
		await _await_sector(stage)
		player.global_position = Vector3(-500,1,-500)
		var samples := {}
		for enemy: Enemy in stage.get_node("RuntimeContent").get_children():
			samples[enemy.get_instance_id()] = {"position":enemy.global_position,"distance":0.0,"paused":false,"indices":{},"max_stall":0.0}
		for frame in 840:
			await get_tree().physics_frame
			for enemy: Enemy in stage.get_node("RuntimeContent").get_children():
				var row: Dictionary = samples[enemy.get_instance_id()]
				row.distance += enemy.global_position.distance_to(row.position)
				row.position = enemy.global_position
				var debug := enemy.get_patrol_runtime_debug()
				row.paused = row.paused or debug.pause_remaining_sec > 0
				row.indices[debug.patrol_index] = true
				row.max_stall = maxf(row.max_stall,debug.stall_elapsed_sec)
		for enemy: Enemy in stage.get_node("RuntimeContent").get_children():
			var row: Dictionary = samples[enemy.get_instance_id()]
			var kind: StringName = enemy.get_meta("patrol_kind")
			coverage[kind] = true
			motion.append({"seed":run_seed,"kind":kind,"distance":row.distance,"paused":row.paused,"indices":row.indices.size(),"stall":row.max_stall})
			if row.distance < 1 or not row.paused or row.indices.size() < 2 or row.max_stall > 2: errors.append("patrol failed %s" % motion.back())
	for kind in ([&"CORRIDOR",&"HUB",&"ACCESS"] if not motion_seeds.is_empty() else []):
		if not coverage.has(kind): errors.append("kind not exercised %s" % kind)
	# Controlled sensory inputs on a REAL generated guard. Separate from normal
	# patrol motion above. No balance overrides, real LOS and existing light.
	var enemy: Enemy = stage.get_node("RuntimeContent").get_child(0)
	enemy.set_physics_process(false)
	enemy.perception_timer.stop()
	var forward := -enemy.global_basis.z
	player.global_position = enemy.global_position + forward*2.0
	await get_tree().physics_frame
	var front := enemy._passes_vision_baseline(player)
	player.global_position = enemy.global_position - forward*2.0
	await get_tree().physics_frame
	var rear := enemy._passes_vision_baseline(player)
	var side := forward.rotated(Vector3.UP, PI/2)
	player.global_position = enemy.global_position + side*2.0
	await get_tree().physics_frame
	var lateral := enemy._passes_vision_baseline(player)
	var walk_heard := enemy._can_hear_noise_event(enemy.global_position+forward*3.5,3.0)
	var run_heard := enemy._can_hear_noise_event(enemy.global_position+forward*3.5,5.0)
	if not front or rear or lateral or walk_heard or not run_heard: errors.append("front/rear/lateral/noise mismatch")
	player.global_position = Vector3(-500,1,-500)
	enemy._on_player_noise_emitted(enemy.global_position,3.0,1.0)
	var investigate := enemy.get_debug_state_name() == "ALERT"
	CombatEncounterManager.reset()
	enemy.set_physics_process(true)
	enemy.perception_timer.start()
	await get_tree().create_timer(enemy.enemy_resource.lose_target_timeout_sec+1.0).timeout
	var returned := enemy.get_debug_state_name() == "PATROL"
	if not investigate or not returned: errors.append("investigate/return failed state=%s searching=%s timer=%s timeout=%s last=%s pos=%s" % [enemy.get_debug_state_name(),enemy._searching_at_last_known,enemy._time_since_detection,enemy.enemy_resource.lose_target_timeout_sec,enemy.get_debug_last_known_position(),enemy.global_position])
	var contact := await _contact_lifecycle(stage, player)
	if not contact.errors.is_empty(): errors.append_array(contact.errors)
	var occlusion := await _contact_lifecycle(stage, player, true)
	if not occlusion.errors.is_empty(): errors.append_array(occlusion.errors)
	await stage.regenerate(65001)
	await _await_sector(stage)
	if CombatManager.get_combatant_count() > 0 or CombatEncounterManager.is_encounter_active() or player.is_frozen: errors.append("reset retained combat ownership")
	print("V212_BEHAVIOR=%s" % JSON.stringify({"motion":motion,"front":front,"rear":rear,"lateral":lateral,"walk_heard":walk_heard,"run_heard":run_heard,"investigate":investigate,"returned":returned,"contact":contact,"occlusion":occlusion,"errors":errors}))
	print("V212 behavior: %s" % ("PASS" if errors.is_empty() else "FAIL"))
	get_tree().quit(0 if errors.is_empty() else 1)


func _contact_lifecycle(stage: Node3D, player: Node3D, occluded := false) -> Dictionary:
	# Existing exploration-only switch isolates CHASE/search from APPROACH.
	# No perception, speed, timeout or light parameters are overridden.
	var result := {"seed":65001,"errors":[],"states":[],"loss":"WALL" if occluded else "RANGE"}
	await stage.regenerate(65001)
	await _await_sector(stage)
	player.global_position = Vector3(-500,1,-500)
	var enemy: Enemy = null
	for guard: Enemy in stage.get_node("RuntimeContent").get_children():
		if guard.get_meta("patrol_kind") == &"CORRIDOR": enemy = guard
	if enemy == null:
		result.errors.append("controlled seed has no corridor guard")
		return result
	var points: Array = enemy.get_meta("patrol_world_points")
	enemy.set_physics_process(false)
	enemy.perception_timer.stop()
	enemy.global_position = points[0]
	enemy.look_at(points[1],Vector3.UP)
	player.global_position = enemy.global_position - enemy.global_basis.z*1.2
	await get_tree().physics_frame
	var map: RID = stage.nav_region.get_navigation_map()
	var projected := NavigationServer3D.map_get_closest_point(map,player.global_position)
	var safe_input: bool = Vector2(projected.x-player.global_position.x,projected.z-player.global_position.z).length() < 0.12 and enemy._passes_vision_baseline(player)
	result.safe_input = safe_input
	if not safe_input:
		result.errors.append("visual stimulus is not navigable/visible")
		return result
	CombatEncounterManager.combat_transition_enabled = false
	enemy._on_perception_tick()
	result.single_tick_state = enemy.get_debug_state_name()
	result.single_tick_sight = enemy._sight_timer
	enemy.perception_timer.start()
	await get_tree().create_timer(enemy.enemy_resource.detection_time_sec+enemy.enemy_resource.perception_interval_sec*2).timeout
	result.chased = enemy.get_debug_state_name() == "CHASE"
	var known := player.global_position
	player.global_position = Vector3(-500,1,-500)
	if occluded:
		var hidden := _occluded_walkable_point(stage, enemy, player)
		if hidden == Vector3.INF:
			result.errors.append("no safe wall-occluded stimulus found")
			CombatEncounterManager.combat_transition_enabled = true
			return result
		player.global_position = hidden
		result.hidden_point = hidden
		result.hidden_distance = hidden.distance_to(enemy.global_position)
		result.wall_blocks_los = not enemy._has_clear_line(enemy.global_position+Vector3.UP*1.5, hidden+Vector3.UP)
		await get_tree().physics_frame
		enemy._on_perception_tick()
		result.wall_contact_lost = not enemy.is_encounter_contact_valid()
		if not result.wall_blocks_los or not result.wall_contact_lost: result.errors.append("wall did not break visual contact")
		# Player then leaves range, preventing accidental reacquisition as the
		# guard approaches the saved point. The wall-loss tick is real above.
		player.global_position = Vector3(-500,1,-500)
	enemy.set_physics_process(true)
	var last_state := ""
	var reached_search := false
	for frame in 720:
		await get_tree().physics_frame
		var state := enemy.get_debug_state_name()
		if state != last_state:
			result.states.append(state)
			last_state = state
		if state == "ALERT" and enemy._searching_at_last_known: reached_search = true
		if reached_search and state == "PATROL": break
	result.last_known_preserved = enemy.get_debug_last_known_position().distance_to(known) < 0.01
	result.searched = reached_search
	result.returned = enemy.get_debug_state_name() == "PATROL" and not CombatEncounterManager.is_encounter_active()
	var start := enemy.global_position
	await get_tree().create_timer(2.5).timeout
	result.resumed_distance = start.distance_to(enemy.global_position)
	if not result.chased or not result.searched or not result.returned or not result.last_known_preserved or result.resumed_distance < 0.1:
		result.errors.append("real CHASE/last-known/search/patrol failed")
	CombatEncounterManager.combat_transition_enabled = true
	# Fresh real guard, supported point and normal encounter enabled.
	await stage.regenerate(65001)
	await _await_sector(stage)
	for guard: Enemy in stage.get_node("RuntimeContent").get_children():
		if guard.get_meta("patrol_kind") == &"CORRIDOR": enemy = guard
	points = enemy.get_meta("patrol_world_points")
	enemy.global_position = points[0]
	enemy.look_at(points[1],Vector3.UP)
	player.global_position = enemy.global_position - enemy.global_basis.z*2.7
	result.combat = false
	var capability := enemy._get_light_detection_capability(LightingManager.get_light_level_at(player.global_position))
	if enemy._is_within_proximity_override(player): capability = 1.0
	if capability <= 0.0:
		result.errors.append("FIXTURE_CONFIGURATION: light cannot confirm visual contact")
		return result
	var interval := enemy.enemy_resource.perception_interval_sec
	var confirmation_bound := ceili(enemy.enemy_resource.detection_time_sec/(interval*capability))*interval
	var combat_bound := confirmation_bound+CombatEncounterManager.join_window_sec+CombatEncounterManager.global_encounter_timeout_sec+interval*3
	print("V212_CONTACT_TIMING="+JSON.stringify({"light":LightingManager.get_light_level_at(player.global_position),"capability":capability,"confirmation_bound":confirmation_bound,"combat_bound":combat_bound}))
	var combat_deadline := Time.get_ticks_msec()+int(combat_bound*1000)
	while Time.get_ticks_msec() < combat_deadline:
		await get_tree().physics_frame
		if CombatManager.get_combatant_count() > 0:
			result.combat = true
			break
	if not result.combat:
		print("V212_CONTACT_FAILURE="+JSON.stringify({"state":enemy.get_debug_state_name(),"contact":enemy._current_contact_kind,"vision":enemy._last_vision_result,"sight":enemy._sight_timer,"light":LightingManager.get_light_level_at(player.global_position),"capability":enemy._get_light_detection_capability(LightingManager.get_light_level_at(player.global_position)),"distance":enemy.global_position.distance_to(player.global_position),"ready":enemy.is_combat_position_valid(player,CombatEncounterManager.combat_distance_tolerance_m),"pending":CombatEncounterManager.get_debug_pending_count(),"window_remaining":CombatEncounterManager.get_debug_join_window_remaining(),"owner":enemy.get_debug_ai_owner(),"admission":enemy.get_debug_encounter_admission_reason(),"position":enemy.global_position,"player":player.global_position}))
		result.errors.append("real perception to combat failed")
	print("V212_CONTACT=%s" % JSON.stringify(result))
	return result


func _occluded_walkable_point(stage: Node3D, enemy: Enemy, player: Node3D) -> Vector3:
	var map: RID = stage.nav_region.get_navigation_map()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.get_node("CollisionShape3D").shape
	query.collision_mask = 1
	var space := stage.get_world_3d().direct_space_state
	# Diagnostic search for an actual supported point behind actual geometry;
	# deliberately not an invented perception result or player inside a wall.
	for x in range(-16,17):
		for z in range(-16,17):
			var point := enemy.global_position+Vector3(x*0.5,0,z*0.5)
			var distance := point.distance_to(enemy.global_position)
			if distance < 2 or distance > enemy.get_debug_fov_range_m(): continue
			var nav := NavigationServer3D.map_get_closest_point(map,point)
			if Vector2(nav.x-point.x,nav.z-point.z).length() > 0.12: continue
			query.transform = Transform3D(Basis(),point+Vector3.UP*0.04)
			if not space.intersect_shape(query).is_empty(): continue
			if not enemy._has_clear_line(enemy.global_position+Vector3.UP*1.5,point+Vector3.UP): return point
	return Vector3.INF


func _invalid_route_rejected(stage: Node3D) -> bool:
	var source: DungeonContentSlot = stage.current_content_plan.selected_slots[0]
	var slot := DungeonContentSlot.new()
	slot.unique_id = &"invalid:patrol"
	slot.category = &"ENCOUNTER"
	slot.node_id = source.node_id
	slot.global_transform = source.global_transform
	slot.definition = source.definition.duplicate(true)
	slot.definition.patrol.footprint_points = [Vector2(10,10),Vector2(20,20)]
	var plan := ContentPlacementPlan.new()
	plan.seed = stage.seed
	plan.selected_slots.append(slot)
	var root := Node3D.new()
	add_child(root)
	var report := ContentPlacementRuntimeConsumer.consume(plan,stage.current_content_profile,root,stage.current_plan,stage.nav_region.get_navigation_map())
	var valid: bool = report.patrol_rejected.size() == 1 and root.get_child_count() == 0
	root.free()
	return valid


func _main_route() -> void:
	var stage := load("res://scenes/tests/VarkhemV212ExperienceTest.tscn").instantiate() as Node3D
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--route-seed="): stage.initial_seed = int(arg.trim_prefix("--route-seed="))
	add_child(stage)
	await _await_sector(stage)
	var player: CharacterBody3D = stage.get_node("Player")
	var map: RID = stage.nav_region.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map,stage.start_point,stage.exit_point,true)
	var visible := {}
	var opportunities := {}
	var rooms_entered := {}
	var target := 1
	var started := Time.get_ticks_msec()
	var reached := false
	var frozen := false
	var oxygen_before: float = RunState.oxygen_current
	Input.action_press("move_forward")
	# Walk the real main-route NavMesh using actual Player input/physics/noise/O2.
	# Intentionally naive traversal, NOT a claim that optimal stealth is possible.
	for frame in 7200:
		await get_tree().physics_frame
		if player.is_frozen:
			frozen = true
			break
		if target >= path.size():
			reached = true
			break
		var offset: Vector3 = path[target]-player.global_position
		offset.y = 0
		if offset.length() < 0.25:
			target += 1
			continue
		player.rotation.y = atan2(-offset.x,-offset.z)
		for id in stage.current_plan.module_ids:
			if stage.current_plan.module_types[id] not in [&"ROOM",&"SIDE_ROOM"]: continue
			var local: Vector3 = stage.current_plan.assembly_transforms[id].affine_inverse()*player.global_position
			var footprint: Vector2 = stage.current_plan.module_definitions[id].footprint_size
			if absf(local.x) < footprint.x*0.5 and absf(local.z) < footprint.y*0.5: rooms_entered[id] = true
		for enemy: Enemy in stage.get_node("RuntimeContent").get_children():
			if enemy.global_position.distance_to(player.global_position) <= enemy.get_debug_fov_range_m() and enemy._has_clear_line(player.global_position+Vector3.UP,enemy.global_position+Vector3.UP):
				visible[enemy.get_meta("content_slot_id")] = true
			if enemy._passes_vision_baseline(player): opportunities[enemy.get_meta("content_slot_id")] = true
	Input.action_release("move_forward")
	if frozen:
		for frame in 480:
			if CombatManager.get_combatant_count() > 0: break
			await get_tree().physics_frame
	print("V212_MAIN_ROUTE=%s" % JSON.stringify({"seed":stage.seed,"visible_enemies":visible.size(),"detection_opportunities":opportunities.size(),"combatants":CombatManager.get_combatant_count(),"player_frozen":frozen,"exit_reached":reached,"oxygen_spent":oxygen_before-RunState.oxygen_current,"oxygen_movement":RunState.oxygen_movement_spent,"oxygen_combat":RunState.oxygen_combat_spent,"distance_m":RunState.exploration_distance_travelled_m,"duration_ms":Time.get_ticks_msec()-started,"optional_rooms_entered":rooms_entered.size(),"careful_avoidance":"MANUAL_REQUIRED"}))
	await stage.regenerate(65001)
	await _await_sector(stage)
	get_tree().quit(0 if reached or frozen else 1)
