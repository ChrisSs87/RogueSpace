extends Node3D

const PLAYER := preload("res://scenes/player/Player.tscn")
const ACTOR := preload("res://scenes/enemies/Enemy.tscn")
const VARKHEN := preload("res://resources/enemies/orco_melee.tres")
const HORVEX := preload("res://resources/enemies/xenomorfo.tres")
const RAPTOR := preload("res://resources/enemies/orco_picaro.tres")
var player: CharacterBody3D
var actors: Array[Enemy] = []
var region: NavigationRegion3D
var mode := "close"
var probe := false
var starts := 0
var start_rows: Array = []
var errors: Array = []
var events: Array = []
var started_msec := 0
var barrier: StaticBody3D
var setup_ok := false
var floor_body: CSGBox3D
var minimum_distance := INF
var external_position := Vector3.INF

func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.position = position
	body.add_child(collision)
	add_child(body)
	return body

func _nav_rect(minimum: Vector2, maximum: Vector2) -> void:
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(minimum.x,0,minimum.y),Vector3(minimum.x,0,maximum.y),Vector3(maximum.x,0,maximum.y),Vector3(maximum.x,0,minimum.y)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh

func _actor(position: Vector3, resource: EnemyResource, route: Array[NodePath] = []) -> Enemy:
	var actor: Enemy = ACTOR.instantiate()
	actor.enemy_resource = resource
	actor.position = position
	actor.patrol_points = route
	add_child(actor)
	actor.look_at(Vector3(player.global_position.x,actor.global_position.y,player.global_position.z))
	actors.append(actor)
	return actor

func _snapshot(label: String) -> Dictionary:
	var rows: Array = []
	for actor in actors:
		if not is_instance_valid(actor): continue
		var map := region.get_navigation_map()
		var projected := NavigationServer3D.map_get_closest_point(map,player.global_position)
		var from := NavigationServer3D.map_get_closest_point(map,actor.global_position)
		var contact := actor.refresh_encounter_contact_valid()
		rows.append({"name":String(actor.name),"position":actor.global_position,"player":player.global_position,"distance":actor.global_position.distance_to(player.global_position),"state":actor.get_debug_state_name(),"owner":actor.get_debug_ai_owner(),"encounter":actor.get_debug_encounter_state(),"contact":contact,"kind":actor._current_contact_kind,"fov":actor._debug_fov_str,"los":actor._has_clear_vision_line(actor.get_vision_origin(),player.get_node("Head").global_position,player),"exposure":actor._sight_timer,"clearance":actor._has_capsule_clearance(actor.global_position),"target":actor._debug_combat_slot_world,"target_valid":actor._debug_combat_slot_valid,"nav":actor._debug_nav_str,"path_points":NavigationServer3D.map_get_path(map,from,projected,true).size(),"player_projection_xz":Vector2(projected.x-player.global_position.x,projected.z-player.global_position.z).length(),"ready":actor.is_combat_position_valid(player,CombatEncounterManager.combat_distance_tolerance_m),"requested":actor._has_requested_encounter,"join_closed":actor._encounter_join_closed,"excluded":actor._excluded_from_active_encounter,"must_lose":actor._must_lose_contact_before_reentry,"total_cancel_reentry":actor._cancelled_approach_reentry_pending,"pending_member":actor in CombatEncounterManager._pending_enemies,"ready_member":actor in CombatEncounterManager._enemies_in_position})
	var result := {"phase":label,"ms":Time.get_ticks_msec()-started_msec,"active":CombatEncounterManager.is_encounter_active(),"window":CombatEncounterManager.get_debug_join_window_remaining(),"pending":CombatEncounterManager.get_debug_pending_count(),"starts":starts,"actors":rows,"suspended":ExplorationState.is_suspended(),"player_frozen":player.is_frozen}
	if CombatEncounterManager.has_method("get_debug_encounter_diagnostic"): result["resolution"] = CombatEncounterManager.get_debug_encounter_diagnostic()
	for index in rows.size():
		rows[index]["admission_reason"] = actors[index].call("get_debug_encounter_admission_reason") if actors[index].has_method("get_debug_encounter_admission_reason") else "BASE_FLAGS_ONLY"
	print("P0R2_TRACE="+JSON.stringify(result))
	return result

func _until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if condition.call(): return true
	return false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
		if arg == "--probe": probe = true
	var resource := HORVEX if OS.get_cmdline_user_args().has("--horvex") else VARKHEN
	if mode == "chase_raptor": resource = RAPTOR
	LightingManager.set_ambient_light_level(3)
	floor_body = CSGBox3D.new()
	floor_body.size = Vector3(30,0.2,30)
	floor_body.position.y = -0.1
	floor_body.use_collision = true
	add_child(floor_body)
	region = NavigationRegion3D.new()
	add_child(region)
	_nav_rect(Vector2(-14,-14),Vector2(14,14))
	player = PLAYER.instantiate()
	player.position = Vector3(0,0.86,0)
	add_child(player)
	if mode in ["wall_close","corner"]:
		_box(Vector3(1.1,1.5,0),Vector3(0.2,3,10))
		player.position.x = 0.59 # .41 from wall, .4 player capsule fits.
		_nav_rect(Vector2(-14,-14),Vector2(0.45,14))
	if mode == "corner":
		_box(Vector3(0,1.5,-0.6),Vector3(30,3,0.2))
		_box(Vector3(0,1.5,1.7),Vector3(30,3,0.2))
		_box(Vector3(-1.1,1.5,0),Vector3(0.2,3,10))
		player.position.z = -0.09
		_nav_rect(Vector2(-0.45,0.05),Vector2(0.45,1.05))
	var at := Vector3(0,0.91,1.1)
	if mode == "corner": at = Vector3(0.1,0.91,0.95)
	if mode in ["pair","reject","lost","withdraw_lock","full_recovery","ready_drop","renew_window","moderate"]: at.z = 2.4
	if mode in ["chase_close","reset_approach","blink_cancel","closed_recovery","impossible","positioning_suspend"]: at.z = 5.0
	if mode == "chase_raptor": at.z = 3.0
	if mode == "ambush_withdraw":
		at.z = 1.0
		Input.action_press("stealth")
		player.movement_state = player.MovementState.STEALTH
	var first := _actor(at,resource)
	first.set_physics_process(mode in ["chase_close","chase_raptor","ambush_withdraw"])
	if mode == "ambush_withdraw": first.rotation.y = PI
	if mode == "positioning_suspend":
		var marker_a := Marker3D.new()
		var marker_b := Marker3D.new()
		add_child(marker_a)
		add_child(marker_b)
		marker_a.position = Vector3(4,0,6)
		marker_b.position = Vector3(4,0,8)
		var route: Array[NodePath] = [marker_a.get_path(),marker_b.get_path()]
		var external := _actor(Vector3(4,0.91,8),resource,route)
		# Isolate real public patrol configuration from independent detection.
		# Additional CHASE bystanders remain covered by suspension regression.
		external.perception_timer.stop()
		external.rotation.y = PI
	if mode in ["pair","reject","full_recovery","withdraw_lock","closed_recovery","ready_drop","renew_window"]:
		var second := _actor(Vector3(-1.7,0.91,5.0 if mode == "ready_drop" else 1.8),resource)
		second.set_physics_process(false)
		if mode in ["reject","closed_recovery","renew_window"]: second.perception_timer.stop()
		if mode == "full_recovery":
			var third := _actor(Vector3(1.7,0.91,1.8),resource)
			third.set_physics_process(false)
	CombatManager.combat_started.connect(func(): starts += 1; start_rows.append(_snapshot("COMBAT_STARTED")))
	started_msec = Time.get_ticks_msec()
	setup_ok = await _until(func(): return player.is_on_floor() and NavigationServer3D.map_get_iteration_id(region.get_navigation_map()) > 0 and NavigationServer3D.map_get_path(region.get_navigation_map(),first.global_position,player.global_position,true).size() >= 2,3.0)
	_snapshot("PREFLIGHT")
	if not setup_ok:
		errors.append("FAIL_FIXTURE: missing floor/map/path")
		_finish()
		return
	var actor_query := PhysicsShapeQueryParameters3D.new()
	actor_query.shape = player.get_node("CollisionShape3D").shape
	actor_query.transform = player.get_node("CollisionShape3D").global_transform
	actor_query.exclude = [player.get_rid()]
	actor_query.collision_mask = 1|4
	actor_query.margin = 0.0
	for overlap in get_world_3d().direct_space_state.intersect_shape(actor_query):
		if overlap.collider != floor_body: errors.append("FAIL_FIXTURE: Player overlaps wall/actor: "+str(overlap.collider))
	if player.global_position.y < 0.849: errors.append("FAIL_FIXTURE: Player penetrates floor")
	var deadline := Time.get_ticks_msec()+int((CombatEncounterManager.global_encounter_timeout_sec+CombatEncounterManager.join_window_sec+5)*1000)
	var altered := false
	var last := ""
	var next_sample := 0
	while errors.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		minimum_distance = minf(minimum_distance,first.global_position.distance_to(player.global_position))
		var key := str([first.get_debug_state_name(),CombatEncounterManager.get_debug_pending_count(),first._has_requested_encounter])
		if key != last or Time.get_ticks_msec() >= next_sample:
			_snapshot("TICK")
			last = key
			next_sample = Time.get_ticks_msec()+500
		if mode == "withdraw_lock" and first._has_requested_encounter and not altered:
			# Stop sensory callbacks only between valid admission and lock to
			# reproduce a stale candidacy; the manager must revalidate/release.
			first.perception_timer.stop()
			first.rotation.y += PI
			altered = true
		if mode == "full_recovery" and actors[2]._encounter_join_closed and not altered:
			# Legitimate capacity rejection before lock, then another candidate
			# withdraws. The rejected guard must not become permanently closed.
			first.perception_timer.stop()
			CombatEncounterManager.withdraw_encounter_candidate(first)
			altered = true
		if mode == "renew_window" and first._has_requested_encounter and CombatEncounterManager.get_debug_join_window_remaining() < 0.2 and not altered:
			first.perception_timer.stop()
			CombatEncounterManager.withdraw_encounter_candidate(first)
			actors[1].perception_timer.start()
			altered = true
		if mode == "renew_window" and actors[1]._has_requested_encounter:
			if CombatEncounterManager.get_debug_join_window_remaining() < CombatEncounterManager.join_window_sec-0.1: errors.append("FAIL_PRODUCTION: replacement inherited expired window")
			break
		if mode == "ready_drop" and first in CombatEncounterManager._enemies_in_position and not altered:
			actors[1].perception_timer.stop()
			actors[1].rotation.y += PI
			actors[1].refresh_encounter_contact_valid()
			altered = true
			var dropped_msec := Time.get_ticks_msec()
			await _until(func(): return starts > 0,resource.perception_interval_sec*2)
			_snapshot("READY_AFTER_DROP")
			if starts != 1: errors.append("FAIL_PRODUCTION: retained READY waits for global timeout after other participant drops")
			print("P0R2_READY_DROP_LATENCY="+str(Time.get_ticks_msec()-dropped_msec))
			break
		if mode in ["withdraw_last","ambush_withdraw"] and first._has_requested_encounter:
			CombatEncounterManager.withdraw_encounter_candidate(first)
			altered = true
			if CombatEncounterManager.get_debug_join_window_remaining() > 0: errors.append("FAIL_PRODUCTION: last withdrawal left window timer running")
			if first._ambush_candidate_registered or first in CombatEncounterManager._ambush_candidates: errors.append("FAIL_PRODUCTION: withdrawn ambush keeps admission exemption")
			_snapshot("WITHDRAWN")
			if mode == "ambush_withdraw" and CombatManager._ambush_enemy == first: errors.append("FAIL_PRODUCTION: withdrawn ambush keeps pending bonus intent")
			break
		if actors.any(func(actor): return actor.get_debug_state_name() == "APPROACH"):
			for actor in actors:
				if mode != "ready_drop" or actor == first: actor.set_physics_process(true)
			if mode == "positioning_suspend":
				if not altered:
					external_position = actors[1].global_position
					if Vector2(external_position.x-4,external_position.z-8).length() < 0.1: errors.append("FAIL_FIXTURE: bystander was not moving before preparation")
					altered = true
				if ExplorationState.is_suspended() or player.is_frozen: errors.append("FAIL_PRODUCTION: preparation suspended exploration before effective combat")
			if mode == "closed_recovery":
				if not altered:
					# Reservation closes membership, not exploration. Exercise the
					# closed API separately, without manufacturing sight.
					if CombatEncounterManager.request_encounter_candidate(actors[1]) != CombatEncounterManager.REJECTED_CLOSED: errors.append("FAIL_PRODUCTION: closed positioning accepts extra request")
					altered = true
			if mode == "reset_approach" and not altered:
				CombatEncounterManager.reset()
				altered = true
				if first.get_debug_ai_owner() != "EXPLORATION" or first.get_debug_state_name() == "APPROACH": errors.append("FAIL_PRODUCTION: reset leaves actor owned by encounter")
				_snapshot("RESET_APPROACH")
				break
			if mode in ["blink_cancel","impossible"] and not altered:
				barrier = _box(Vector3(0,1.5,2.4),Vector3(28,3,0.2))
				altered = true
			if mode == "lost" and not altered:
				barrier = _box(Vector3(0,1.5,1.2),Vector3(28,3,0.2))
				altered = true
		if starts > 0: break
		if mode == "blink_cancel" and altered and is_instance_valid(barrier) and not CombatEncounterManager.is_encounter_active():
			_snapshot("TOTAL_CONTACT_CANCEL")
			barrier.free()
		if mode == "withdraw_lock" and altered and CombatEncounterManager.get_debug_join_window_remaining() <= 0 and not CombatEncounterManager.is_encounter_active(): break
		if mode == "lost" and altered and not CombatEncounterManager.is_encounter_active(): break
		if mode == "impossible" and altered and not CombatEncounterManager.is_encounter_active(): break
	var final := _snapshot("FINAL")
	if mode == "positioning_suspend" and starts == 1:
		if actors[1].global_position.distance_to(external_position) < 0.1: errors.append("FAIL_PRODUCTION: external patrol did not advance during preparation")
		var combat_transform := actors[1].global_transform
		for tick in 24: await get_tree().physics_frame
		if not ExplorationState.is_suspended() or not player.is_frozen or actors[1].global_transform != combat_transform: errors.append("FAIL_PRODUCTION: effective combat did not suspend external actor and Player")
	if mode == "closed_recovery":
		if starts != 1 or actors[1]._has_requested_encounter or CombatManager.get_combatant_count() != 1: errors.append("FAIL_FIXTURE_OR_PRODUCTION: suspended bystander entered encounter")
		_snapshot("LEGITIMATE_CLOSED_REJECTION")
		CombatManager.reset_after_defeat()
		CombatEncounterManager.reset()
		ExplorationState.reset_for_regeneration()
		player.unfreeze_after_combat()
		actors[1].perception_timer.start()
		var recovered := await _until(func(): return starts == 2,CombatEncounterManager.join_window_sec+3)
		_snapshot("REJECTED_GUARD_RECOVERED")
		if not recovered or CombatManager.get_combatant_count() != 1 or CombatManager.get_combatant_node(0) != actors[1]: errors.append("FAIL_PRODUCTION: closed rejection did not recover independently")
	if mode == "reset_combat" and starts == 1:
		CombatManager.reset_after_defeat()
		CombatEncounterManager.reset()
		ExplorationState.reset_for_regeneration()
		player.unfreeze_after_combat()
		var extra := await _until(func(): return starts > 1,actors[0].enemy_resource.perception_interval_sec*4)
		_snapshot("AFTER_COMBAT_RESET")
		if extra or actors[0].get_debug_ai_owner() != "EXPLORATION": errors.append("FAIL_PRODUCTION: combat reset queued prior participant or left ownership")
	if mode == "impossible":
		if not altered: errors.append("FAIL_FIXTURE: no positioning attempt")
		if starts != 0 or CombatEncounterManager.is_encounter_active() or ExplorationState.is_suspended() or player.is_frozen or first.has_combat_positioning(): errors.append("FAIL_PRODUCTION: unsafe positioning did not cancel/release cleanly")
	elif mode in ["reset_approach","withdraw_last","ambush_withdraw","closed_recovery","renew_window","ready_drop"]:
		if not altered: errors.append("FAIL_FIXTURE: lifecycle scenario not reached")
	elif mode == "withdraw_lock":
		if not altered: errors.append("FAIL_FIXTURE: candidate not acquired")
		if first._has_requested_encounter: errors.append("FAIL_PRODUCTION: discarded lock candidate retained request")
	elif mode == "lost":
		if not altered: errors.append("FAIL_FIXTURE: APPROACH not reached")
		for row in start_rows:
			if not row.actors[0].los: errors.append("FAIL_PRODUCTION: combat through wall")
	elif mode == "full_recovery":
		if not altered: errors.append("FAIL_FIXTURE: capacity rejection not observed")
		if CombatManager.get_combatant_count() != 2 or CombatManager.get_combatant_node(1) != actors[2]: errors.append("FAIL_PRODUCTION: rejected capacity guard cannot fill reopened window")
	else:
		if starts != 1: errors.append("FAIL_PRODUCTION: valid combat did not start exactly once")
		if mode == "pair" and CombatManager.get_combatant_count() != 2: errors.append("FAIL_PRODUCTION: valid pair not admitted")
		if mode == "reject" and CombatManager.get_combatant_count() != 1: errors.append("FAIL_PRODUCTION: non-detecting bystander admitted")
		if mode in ["close","wall_close","corner"] and not start_rows.is_empty() and start_rows[0].actors[0].distance > at.distance_to(player.global_position)+0.15: errors.append("FAIL_PRODUCTION: close encounter requires physical retreat")
		if mode == "chase_raptor" and minimum_distance < CombatEncounterManager.combat_min_distance_m-0.15: errors.append("FAIL_PRODUCTION: visual investigation runs into Player before confirmation")
		if mode == "positioning_suspend" and (not altered or CombatManager.get_combatant_count() != 1): errors.append("FAIL_FIXTURE_OR_PRODUCTION: independent external actor scenario unavailable")
	_finish()

func _finish() -> void:
	Input.action_release("stealth")
	print("P0R2_RESULT="+JSON.stringify({"case":mode,"probe":probe,"setup":setup_ok,"starts":starts,"minimum_distance":minimum_distance,"valid":errors.is_empty(),"errors":errors,"combatants":CombatManager.get_combatant_count(),"time_msec":Time.get_ticks_msec()-started_msec}))
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	ExplorationState.reset_for_regeneration()
	get_tree().quit(0 if probe or errors.is_empty() else 1)
