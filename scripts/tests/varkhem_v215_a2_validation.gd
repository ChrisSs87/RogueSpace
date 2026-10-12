extends "res://scripts/tests/varkhem_v215_cover_validation.gd"

@export var run_probe := true
var live_status: Label
var live_sample_at := 0

func _ready() -> void:
	await super._ready()
	if not run_probe:
		live_status = Label.new()
		live_status.position = Vector2(12,150)
		compact.get_parent().add_child(live_status)
		return
	if OS.get_cmdline_user_args().has("--detection"):
		await _detection_matrix()
	else:
		await _approach_probe()
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	Input.action_release("stealth")
	print("V215_A2_RESULT="+JSON.stringify({"valid":errors.is_empty(),"errors":errors}))
	get_tree().quit(0 if errors.is_empty() else 1)

func _process(delta: float) -> void:
	super._process(delta)
	if run_probe or live_status == null or not is_instance_valid(guard): return
	var row := _evidence()
	live_status.visible = diagnostic_mode != 0
	live_status.text = "VISION:%s | SIGHT:%.2f/%.2f | LIGHT:%s | CAP:%s\nPHYS:%s | APPROACH:%.1fs | ENCOUNTER:%.1f/%.1fs | SLOT:%s | NAV:%s" % [row.reason,row.sight,row.required,row.light,row.capability,"ON" if row.physics_enabled else "OFF (fixed COVER fixture)",row.approach_sec,row.manager_sec,CombatEncounterManager.global_encounter_timeout_sec,row.slot_valid,row.navigation]
	if Time.get_ticks_msec() >= live_sample_at:
		print("A2_MANUAL_TRACE="+JSON.stringify(row))
		live_sample_at = Time.get_ticks_msec()+1000

func _evidence() -> Dictionary:
	var row := guard.get_cover_perception_debug()
	row.merge({"physics_enabled":guard.is_physics_processing(),"position":str(guard.position),"player":str(player.position),"physical_distance":guard.position.distance_to(player.position),"vision":guard._last_vision_result,"sight":guard._sight_timer,"required":GUARD.detection_time_sec,"light":guard._debug_light_str,"capability":guard._debug_capability_str,"approach_sec":guard._approach_elapsed,"manager_sec":CombatEncounterManager._approach_timer,"slot_valid":guard._debug_combat_slot_valid,"slot":str(guard._debug_combat_slot_world),"projected":str(guard._debug_combat_slot_navigation),"navigation":guard._debug_nav_str,"navigation_target":guard._debug_nav_target_str,"contact":guard._current_contact_kind,"encounter":guard.get_debug_encounter_state()})
	var reason := "CONFIRMED" if row.vision == Enemy.VISION_CHASE else "EXPOSURE_PENDING"
	if row.fov != "YES": reason = "RANGE/FOV_NOT_VALID"
	elif row.cover.ends_with(":BLOCK"): reason = "LOGICAL_COVER"
	elif row.los != "YES": reason = "WORLD_OCCLUSION"
	elif row.capability == "0%": reason = "LIGHT_CAPABILITY_ZERO"
	row.reason = reason
	# Defaults del Enemy no prueban que un slot haya sido evaluado: antes del
	# primer tick APPROACH sus coordenadas siguen siendo INF.
	row.slot_evaluated = guard._debug_combat_slot_world.is_finite()
	row.slot_valid = row.slot_evaluated and row.slot_valid
	return row

func _detection_matrix() -> void:
	CombatEncounterManager.combat_transition_enabled = false
	for index in 3:
		for crouch in [false,true]:
			chase_mode = false
			_manual_lane(index)
			if crouch: Input.action_press("stealth")
			else: Input.action_release("stealth")
			await _wait(0.4)
			var expected: bool = index == 2 or (index == 1 and not crouch)
			print("A2_DETECTION_EARLY="+JSON.stringify(_evidence()))
			var capability: float = GUARD.light_detection_curve[LightingManager.get_light_level_at(player.position)]
			_check(capability > 0.0,"FIXTURE_CONFIGURATION: sustained detection needs nonzero light capability")
			if capability <= 0.0: return
			await _wait(GUARD.detection_time_sec/capability+GUARD.perception_interval_sec*2)
			print("A2_DETECTION_FINAL="+JSON.stringify(_evidence()))
			_check(guard._last_vision_result == (Enemy.VISION_CHASE if expected else Enemy.VISION_NONE),"sustained detection category %s posture %s" % [index,crouch])
	CombatEncounterManager.combat_transition_enabled = true

func _slot_candidates() -> void:
	var map := get_world_3d().get_navigation_map()
	var forward := -player.global_basis.z
	for offset: float in [0.0,20.0,-20.0,40.0,-40.0,60.0,-60.0,90.0,-90.0,120.0,-120.0,180.0]:
		var candidate: Vector3 = player.position+forward.rotated(Vector3.UP,deg_to_rad(guard._combat_slot_angle_deg+offset))*GUARD.combat_distance_tiles*GameBalance.tile_size_m
		candidate.y = guard.position.y
		var projected := NavigationServer3D.map_get_closest_point(map,candidate)
		var path := NavigationServer3D.map_get_path(map,NavigationServer3D.map_get_closest_point(map,guard.position),projected,true)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = guard.collision_shape.shape
		query.transform = Transform3D(guard.global_basis,candidate)
		query.collision_mask = Enemy.WORLD_COLLISION_MASK
		query.exclude = [guard.get_rid()]
		var hits: Array = []
		for hit in get_world_3d().direct_space_state.intersect_shape(query,16): hits.append({"node":str(hit.collider.get_path()),"class":hit.collider.get_class(),"position":str(hit.collider.global_position)})
		var los := guard._has_clear_line(candidate+Vector3.UP,player.position+Vector3.UP)
		var clearance := guard._has_capsule_clearance(candidate)
		var reason := "VALID"
		if Vector2(candidate.x-projected.x,candidate.z-projected.z).length() > 0.12: reason = "NAV_PROJECTION"
		elif path.size() < 2: reason = "NO_PATH"
		elif candidate.distance_to(player.position) < CombatEncounterManager.combat_min_distance_m or candidate.distance_to(player.position) > CombatEncounterManager.combat_max_distance_m: reason = "COMBAT_BAND"
		elif not los: reason = "SLOT_LOS"
		elif not clearance: reason = "CAPSULE_OCCUPIED"
		print("A2_SLOT_CANDIDATE="+JSON.stringify({"offset":offset,"candidate":str(candidate),"projected":str(projected),"path_points":path.size(),"los":los,"clearance":clearance,"colliders":hits,"reason":reason}))

func _approach_probe() -> void:
	var stationary := OS.get_cmdline_user_args().has("--stationary")
	chase_mode = not stationary
	_manual_lane(2)
	if stationary: player.position.z = -7.4
	if OS.get_cmdline_user_args().has("--near-cover"):
		player.position.z = -5.1
		guard.position.z = 2.3
	var deadline := Time.get_ticks_msec()+int((GUARD.detection_time_sec/0.15+CombatEncounterManager.global_encounter_timeout_sec*2+2)*1000)
	var previous := ""
	var next_sample := 0
	var traced := false
	var combat := false
	var cancelled := false
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		var state := guard.get_debug_state_name()+"/"+guard.get_debug_encounter_state()
		if state != previous or Time.get_ticks_msec() >= next_sample:
			print("A2_APPROACH_TRACE="+JSON.stringify(_evidence()))
			previous = state
			next_sample = Time.get_ticks_msec()+1000
		if guard.get_debug_state_name() == "APPROACH" and not traced:
			_slot_candidates()
			traced = true
		if CombatManager.get_combatant_count() > 0:
			combat = true
			break
		if traced and guard.get_debug_encounter_state() == "DROPPED":
			cancelled = true
			break
	_check(traced,"normal perception reaches APPROACH")
	_check(combat or cancelled,"APPROACH resolves through combat or clean cancellation")
	if stationary: _check(cancelled and not CombatEncounterManager.is_encounter_active(),"immobile fixture cancels by existing global timeout")
	print("A2_APPROACH_SUMMARY="+JSON.stringify({"combat":combat,"cancelled":cancelled,"trace":traced}))
