extends Node3D

const PLAYER := preload("res://scenes/player/Player.tscn")
const ACTOR := preload("res://scenes/enemies/Enemy.tscn")
const VARKHEN := preload("res://resources/enemies/orco_melee.tres")
const HORVEX := preload("res://resources/enemies/xenomorfo.tres")
var player: CharacterBody3D
var enemy: Enemy
var second: Enemy
var region: NavigationRegion3D
var barrier: Node3D
var mode := "open"
var probe := false
var resource: EnemyResource
var combat_rows: Array = []
var transitions: Array = []
var errors: Array[String] = []
var last_state := ""

func _box(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)

func _add_barrier() -> void:
	barrier = LogicalCover.new() if mode == "high" else StaticBody3D.new()
	barrier.position = Vector3(0,0,1.25 if mode != "break" else 4)
	add_child(barrier)
	# HIGH deliberately has a short model: its gameplay volume must still
	# block READY even when a physical eye-height ray clears the box.
	var height := 1.1 if mode == "high" else 3.0
	_box(barrier,Vector3(1 if mode == "late_drop" else 24,height,0.3),Vector3(0,height*0.5,0))
	if barrier is LogicalCover:
		barrier.category = LogicalCover.Category.HIGH
		barrier.visibility_volume = AABB(Vector3(-12,0,-0.15),Vector3(24,3,0.3))
	_bake_fixture()

func _bake_fixture() -> void:
	var mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	for z in 57:
		for x in 57: vertices.append(Vector3(-14+x*0.5,0,-14+z*0.5))
	mesh.vertices = vertices
	for z in 56:
		for x in 56:
			var center := Vector3(-13.75+x*0.5,0,-13.75+z*0.5)
			var half_width := 0.5 if mode == "late_drop" else 12.0
			if barrier != null and absf(center.x) < half_width+0.55 and absf(center.z-barrier.position.z) < 0.7: continue
			var a := z*57+x
			mesh.add_polygon(PackedInt32Array([a,a+57,a+58,a+1]))
	region.navigation_mesh = mesh
	NavigationServer3D.map_force_update(region.get_navigation_map())

func _geometry_los() -> bool:
	return enemy._has_clear_vision_line(enemy.get_vision_origin(),player.get_node("Head").global_position,player)

func _trace(label: String) -> Dictionary:
	var row := {"phase":label,"state":enemy.get_debug_state_name(),"position":enemy.global_position,"player":player.global_position,"distance":enemy.global_position.distance_to(player.global_position),"los":_geometry_los(),"exposure":enemy._sight_timer,"threshold":resource.detection_time_sec,"vision":enemy._last_vision_result,"contact":enemy._current_contact_kind,"pending":CombatEncounterManager.get_debug_pending_count(),"owner":enemy.get_debug_ai_owner(),"ready":enemy.is_combat_position_valid(player,CombatEncounterManager.combat_distance_tolerance_m),"slot_validator":enemy._is_valid_combat_slot(enemy.global_position,player.global_position),"frozen":player.is_frozen}
	print("P0_TRACE="+JSON.stringify(row))
	return row

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
		if arg == "--probe": probe = true
	resource = HORVEX if OS.get_cmdline_user_args().has("--horvex") else VARKHEN
	LightingManager.set_ambient_light_level(0 if resource == HORVEX else 3)
	var floor := CSGBox3D.new()
	floor.size = Vector3(30,0.2,30)
	floor.position.y = -0.1
	floor.use_collision = true
	add_child(floor)
	region = NavigationRegion3D.new()
	add_child(region)
	if mode in ["wall","high"]: _add_barrier()
	else: _bake_fixture()
	player = PLAYER.instantiate()
	player.position = Vector3(0,0.91,0)
	add_child(player)
	enemy = ACTOR.instantiate()
	enemy.enemy_resource = resource
	enemy.position = Vector3(0,0.91,8 if mode in ["chase","break"] else 2.5)
	add_child(enemy)
	if mode == "sound_open": enemy.rotation.y = PI
	if mode == "late_drop":
		second = ACTOR.instantiate()
		second.enemy_resource = resource
		second.position = Vector3(5,0.91,8)
		add_child(second)
		second.look_at(Vector3(0,second.position.y,0),Vector3.UP)
		second.set_physics_process(false)
	# Hold only the pre-lock candidate in place to isolate the near-band
	# reproduction. No sensory state, timer or manager result is forced.
	enemy.set_physics_process(mode == "chase")
	CombatManager.combat_started.connect(func(): combat_rows.append(_trace("COMBAT_STARTED")))
	var map := region.get_navigation_map()
	var preflight := Time.get_ticks_msec()+2000
	while Time.get_ticks_msec() < preflight:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > 0 and player.is_on_floor():
			var path := NavigationServer3D.map_get_path(map,enemy.position,player.position,true)
			if path.size() >= 2: break
	if not player.is_on_floor() or NavigationServer3D.map_get_path(map,enemy.position,player.position,true).size() < 2:
		errors.append("FAIL_FIXTURE: floor/map/path unavailable")
	_trace("PREFLIGHT")
	var deadline := Time.get_ticks_msec()+int((CombatEncounterManager.global_encounter_timeout_sec+CombatEncounterManager.join_window_sec+resource.detection_time_sec/maxf(resource.light_detection_curve[LightingManager.ambient_light_level],0.01)+1)*1000)
	var next_sound := 0
	var barrier_added := false
	var blocked_ready_checked := false
	while errors.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if mode in ["wall","high","sound_open"] and Time.get_ticks_msec() >= next_sound:
			# Public SOUND stream represents repeated audible movement behind an
			# occluder; does not manufacture visual confirmation or CHASE.
			EventBus.player_noise_emitted.emit(player.global_position,resource.hearing_range_tiles,1.0)
			next_sound = Time.get_ticks_msec()+int(resource.perception_interval_sec*1000)
			if not blocked_ready_checked and mode != "sound_open":
				blocked_ready_checked = true
				var blocked := _trace("AUDIBLE_BLOCKED")
				if not probe and (blocked.los or blocked.ready): errors.append("FAIL_PRODUCTION: occluded audible near-band actor is READY")
		var state := enemy.get_debug_state_name()
		if state != last_state:
			last_state = state
			transitions.append(state)
			_trace("STATE")
		if state == "APPROACH":
			if mode == "break" and not barrier_added:
				_add_barrier()
				barrier_added = true
				enemy.perception_timer.start()
			enemy.set_physics_process(true)
		if mode == "late_drop" and state == "COMBAT" and combat_rows.is_empty() and not barrier_added:
			# A reached READY legitimately. Before B arrives, a real wall
			# invalidates A. Final admission must DROP A, not orphan it.
			_add_barrier()
			barrier_added = true
			second.set_physics_process(true)
		if not combat_rows.is_empty(): break
		if mode == "break" and barrier_added and not CombatEncounterManager.is_encounter_active(): break
	if not probe:
		if mode == "sound_open":
			# P0-R2 explicitly separates auditory investigation from confirmed
			# visual admission. Keep real SOUND/contact coverage, not forced sight.
			if not combat_rows.is_empty(): errors.append("FAIL_PRODUCTION: SOUND alone admitted combat")
			if enemy._last_known_source != "SOUND" or not enemy._has_recent_sound_contact(): errors.append("FAIL_PRODUCTION: auditory investigation/contact lost")
			if enemy.get_debug_state_name() not in ["ALERT","CHASE"]: errors.append("FAIL_PRODUCTION: missing species-specific auditory response")
		elif mode == "late_drop":
			var second_only := CombatManager.get_combatant_count() == 1 and CombatManager.get_combatant_node(0) == second
			var released := enemy.get_debug_ai_owner() == "EXPLORATION" and enemy.get_debug_state_name() != "COMBAT" and enemy._encounter_debug_state == "DROPPED"
			print("P0_LATE_DROP="+JSON.stringify({"barrier_added":barrier_added,"starts":combat_rows.size(),"second_only":second_only,"released":released,"state":enemy.get_debug_state_name(),"owner":enemy.get_debug_ai_owner(),"encounter":enemy._encounter_debug_state}))
			if not barrier_added or combat_rows.size() != 1 or not second_only: errors.append("FAIL_FIXTURE_OR_PRODUCTION: two-party late occlusion did not reach final admission")
			if not released: errors.append("FAIL_PRODUCTION: invalidated READY participant orphaned in COMBAT")
		elif mode in ["open","chase"]:
			if combat_rows.size() != 1: errors.append("FAIL_PRODUCTION: valid exposed encounter did not start once")
			elif not combat_rows[0].los or combat_rows[0].exposure < resource.detection_time_sec: errors.append("FAIL_PRODUCTION: combat without clear confirmed contact")
		else:
			# The map intentionally has a valid detour. Faster species may
			# complete it and legitimately fight on the player's side. Inspect
			# the actual combat instant, not mere existence of an earlier wall.
			for row in combat_rows:
				if not row.los or not row.ready: errors.append("FAIL_PRODUCTION: combat through occluder")
			if mode == "break" and not barrier_added: errors.append("FAIL_FIXTURE: no real APPROACH before occlusion")
	_trace("FINAL")
	print("P0_RESULT="+JSON.stringify({"probe":probe,"species":resource.species_id,"case":mode,"valid":errors.is_empty(),"errors":errors,"transitions":transitions,"combat_rows":combat_rows}))
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	ExplorationState.reset_for_regeneration()
	player.unfreeze_after_combat()
	get_tree().quit(0 if errors.is_empty() else 1)
