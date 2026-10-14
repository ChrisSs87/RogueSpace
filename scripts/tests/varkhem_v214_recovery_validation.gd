extends Node3D

## Independent contracts, real bodies/timers, no sensory or AI doubles.
@export_enum("SOUND", "VISION") var contract := "SOUND"
const PLAYER := preload("res://scenes/player/Player.tscn")
const ENEMY := preload("res://scenes/enemies/Enemy.tscn")
const RESOURCE := preload("res://resources/enemies/orco_melee.tres")
var player: CharacterBody3D
var enemy: Enemy
var errors: Array[String] = []
var starts := 0
var endings := 0
var rewards := 0
var noise_events := 0
var classification := "PASS"
var _last_progress := ""

func _check(ok: bool, message: String, category: String = "FAIL_PRODUCTION") -> void:
	if not ok:
		errors.append(message)
		if classification == "PASS": classification = category
		elif classification != category: classification = "INCONCLUSIVE"

func _navigation_evidence(target: Vector3) -> Dictionary:
	var map := enemy.get_world_3d().get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map,enemy.global_position)
	var end := NavigationServer3D.map_get_closest_point(map,target)
	var path := NavigationServer3D.map_get_path(map,start,end,true)
	var start_error := Vector2(start.x-enemy.global_position.x,start.z-enemy.global_position.z).length()
	var end_error := Vector2(end.x-target.x,end.z-target.z).length()
	return {"iteration":NavigationServer3D.map_get_iteration_id(map),"regions":NavigationServer3D.map_get_regions(map).size(),"path_points":path.size(),"projected_start":str(start),"projected_end":str(end),"start_error":start_error,"end_error":end_error,"reachable":path.size() >= 2 and start_error < 0.05 and end_error < 0.05,"agent_map_same":enemy.navigation_agent.get_navigation_map() == map,"nav_state":enemy._debug_nav_str,"nav_target":enemy._debug_nav_target_str,"state":enemy.get_debug_state_name(),"position":str(enemy.global_position),"target":str(target),"searching":enemy._searching_at_last_known}

func _wait_until(predicate: Callable, timeout: float) -> bool:
	# A deadline is a failure bound derived from the contract, not a delay to
	# make a test green. Stop waiting as soon as the actual condition occurs.
	var deadline := Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if is_instance_valid(enemy):
			var progress := "%s/%s/%s" % [enemy.get_debug_state_name(),enemy._debug_nav_str,enemy._current_contact_kind]
			if progress != _last_progress:
				_last_progress = progress
				print("V214_RECOVERY_PROGRESS="+JSON.stringify({"ms":Time.get_ticks_msec(),"status":progress,"position":str(enemy.global_position),"last_known":str(enemy.get_debug_last_known_position()),"requested":enemy._has_requested_encounter,"pending":CombatEncounterManager.get_debug_pending_count()}))
		if predicate.call(): return true
	return false

func _spawn_enemy(at: Vector3) -> Enemy:
	var actor: Enemy = ENEMY.instantiate()
	actor.enemy_resource = RESOURCE
	actor.position = at
	add_child(actor)
	return actor

func _visual_fixture_evidence(actor: Enemy) -> Dictionary:
	var eye := actor.get_vision_origin()
	var target: Vector3 = player.get_node("Head").global_position
	var delta := target-eye
	delta.y = 0
	var forward := -actor.global_basis.z
	forward.y = 0
	var angle := rad_to_deg(forward.normalized().angle_to(delta.normalized()))
	var ray := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target,Enemy.WORLD_COLLISION_MASK))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.get_node("CollisionShape3D").shape
	query.transform = player.global_transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var clear := get_world_3d().direct_space_state.intersect_shape(query).is_empty()
	var range_ok := delta.length() > 0.001 and delta.length() <= actor.get_debug_fov_range_m()
	var fov_ok := angle <= actor.get_debug_fov_angle_deg()/2
	return {"valid":not ExplorationState.is_suspended() and range_ok and fov_ok and ray.is_empty() and clear and player.is_on_floor() and actor.is_on_floor(),"range_ok":range_ok,"distance":delta.length(),"fov_ok":fov_ok,"angle":angle,"los_clear":ray.is_empty(),"first_collider":str(ray.collider.get_path()) if not ray.is_empty() else "NONE","capsule_clear":clear,"player_floor":player.is_on_floor(),"enemy_floor":actor.is_on_floor(),"suspended":ExplorationState.is_suspended(),"noise_events":noise_events,"light":LightingManager.get_light_level_at(player.global_position),"player":str(player.global_position),"enemy":str(actor.global_position)}

func _ready() -> void:
	CombatManager.combat_started.connect(func(): starts += 1)
	CombatManager.combat_ended.connect(func(): endings += 1)
	RewardManager.reward_sequence_started.connect(func(): rewards += 1)
	EventBus.player_noise_emitted.connect(func(_p,_r,_i): noise_events += 1)
	# Test-owned empty floor and matching navigation polygon. No production
	# scene, collider, NavigationServer setting or perception Resource changes.
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,0.2,40)
	collision.shape = shape
	floor_body.add_child(collision)
	add_child(floor_body)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-19,0,-19),Vector3(-19,0,19),Vector3(19,0,19),Vector3(19,0,-19)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	add_child(region)
	player = PLAYER.instantiate()
	player.position = Vector3(15,0.86,15)
	add_child(player)
	enemy = _spawn_enemy(Vector3(0,0.91,0))
	var synced := await _wait_until(func():
		if not player.is_on_floor() or not enemy.is_on_floor(): return false
		var route := _navigation_evidence(enemy.global_position+Vector3(0,0,2))
		return route.iteration > 0 and route.regions > 0 and route.agent_map_same and (contract != "SOUND" or route.reachable)
	, RESOURCE.perception_interval_sec*10)
	if contract == "SOUND": print("V214_SOUND_READY="+JSON.stringify(_navigation_evidence(enemy.global_position+Vector3(0,0,2))))
	_check(synced,"FIXTURE_CONFIGURATION: floor/navigation not ready","FAIL_FIXTURE")
	if errors.is_empty():
		if contract == "SOUND": await _sound_contract()
		else: await _vision_contract()
	print("V214_RECOVERY_%s=%s" % [contract,JSON.stringify({"classification":classification,"valid":errors.is_empty(),"errors":errors,"starts":starts,"endings":endings,"rewards":rewards,"noise_events":noise_events})])
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	player.unfreeze_after_combat()
	get_tree().quit(0 if errors.is_empty() else 1)

func _sound_contract() -> void:
	var initial := enemy.global_position
	var source := initial+Vector3(0,0,2)
	var route := _navigation_evidence(source)
	print("V214_SOUND_PREFLIGHT="+JSON.stringify(route))
	_check(route.reachable and route.agent_map_same,"FIXTURE_CONFIGURATION: noise origin has no verified navigation route","FAIL_FIXTURE")
	if not errors.is_empty(): return
	EventBus.player_noise_emitted.emit(source,4.0,1.0)
	_check(enemy._current_contact_kind == "SOUND" and enemy.get_debug_last_known_source() == "SOUND","sound not received")
	_check(enemy._has_requested_encounter and CombatEncounterManager.get_debug_pending_count() == 1,"auditory candidate missing")
	var expired := await _wait_until(func(): return not enemy._has_recent_sound_contact() and enemy._current_contact_kind == "NONE" and not enemy._has_requested_encounter and CombatEncounterManager.get_debug_pending_count() == 0,Enemy.SOUND_CONTACT_MEMORY_SEC+RESOURCE.perception_interval_sec*2)
	_check(expired,"auditory candidate did not expire after memory and normal ticks")
	var reached := await _wait_until(func(): return enemy._searching_at_last_known and enemy.global_position.distance_to(source) < 0.5, source.distance_to(initial)/GameBalance.get_speed(RESOURCE.patrol_speed_tier)+RESOURCE.perception_interval_sec*4)
	print("V214_SOUND_ROUTE_AFTER="+JSON.stringify(_navigation_evidence(source)))
	_check(reached,"did not investigate noise origin")
	_check(enemy.global_position.distance_to(source) < 0.5,"investigation did not reach origin")
	_check(enemy.global_position.distance_to(initial) > 1.0,"no physical investigation movement")
	_check(enemy._last_vision_result == Enemy.VISION_NONE,"noise became artificial vision")
	_check(not enemy._has_recent_sound_contact() and not enemy._has_requested_encounter and CombatEncounterManager.get_debug_pending_count() == 0,"auditory candidate did not expire")
	var returned := await _wait_until(func(): return enemy.get_debug_state_name() == "PATROL",RESOURCE.lose_target_timeout_sec+RESOURCE.perception_interval_sec*2)
	_check(returned and not enemy._searching_at_last_known,"no return after search")
	_check(starts == 0 and endings == 0 and rewards == 0 and noise_events == 1,"unexpected combat/reward/noise duplication")
	print("V214_SOUND_EVIDENCE="+JSON.stringify({"origin":str(source),"enemy":str(enemy.global_position),"investigated":reached,"returned":returned,"vision":enemy._last_vision_result,"pending":CombatEncounterManager.get_debug_pending_count()}))

func _visual_confirmation_bound(actor: Enemy) -> float:
	var capability := actor._get_light_detection_capability(LightingManager.get_light_level_at(player.global_position))
	if actor._is_within_proximity_override(player): capability = 1.0
	if capability <= 0.0:
		_check(false,"FIXTURE_CONFIGURATION: configured light cannot confirm vision","FAIL_FIXTURE")
		return 0.0
	# Normal visual ticks accumulate interval * effective light capability.
	# Do not rely on ALERT moving into proximity override to shorten the test.
	var interval := actor.enemy_resource.perception_interval_sec
	return ceili(actor.enemy_resource.detection_time_sec/(interval*capability))*interval


func _vision_contract() -> void:
	# A separate real participant starts combat through ordinary perception,
	# admission and approach. The observer is out of range, facing empty space.
	player.position = Vector3(10,0.86,-2)
	var participant := _spawn_enemy(Vector3(10,0.91,0))
	var fixture_ready := await _wait_until(func(): return _visual_fixture_evidence(participant).valid,RESOURCE.perception_interval_sec*2)
	print("V214_VISION_PARTICIPANT_PREFLIGHT="+JSON.stringify(_visual_fixture_evidence(participant)))
	_check(fixture_ready,"FIXTURE_CONFIGURATION: participant visual conditions unavailable","FAIL_FIXTURE")
	if not fixture_ready: return
	var confirmation_bound := _visual_confirmation_bound(participant)
	if not errors.is_empty(): return
	var started := await _wait_until(func(): return CombatManager.get_combatant_count() == 1 and ExplorationState.is_suspended(),CombatEncounterManager.join_window_sec+RESOURCE.combat_approach_timeout_sec+confirmation_bound)
	_check(started and CombatManager.get_combatant_node(0) == participant,"natural combat did not start")
	if not started: return
	var suspended_transform := enemy.global_transform
	var body_space := PhysicsServer3D.body_get_space(enemy.get_rid())
	var frozen_timer := enemy.perception_timer.time_left
	var frames := ceili(RESOURCE.perception_interval_sec*Engine.physics_ticks_per_second*2)
	for frame in frames: await get_tree().physics_frame
	_check(enemy.global_transform == suspended_transform and enemy.perception_timer.time_left == frozen_timer,"observer updated during combat")
	_check(body_space.is_valid() and PhysicsServer3D.body_get_space(enemy.get_rid()) == body_space,"observer body unregistered")
	_check(enemy._last_vision_result == Enemy.VISION_NONE,"observer detected during combat")
	# Existing public lifecycle reset, no fake combat-ended signal or AI state.
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	player.unfreeze_after_combat()
	participant.queue_free()
	player.position = Vector3(0,0.86,-2)
	var conditions_valid := true
	var detected := false
	confirmation_bound = _visual_confirmation_bound(enemy)
	if not errors.is_empty(): return
	print("V214_VISION_TIMING="+JSON.stringify({"confirmation_bound":confirmation_bound,"light":LightingManager.get_light_level_at(player.global_position),"interval":RESOURCE.perception_interval_sec,"detection_threshold":RESOURCE.detection_time_sec}))
	var deadline := Time.get_ticks_msec()+int((confirmation_bound+RESOURCE.perception_interval_sec*3)*1000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		var evidence := _visual_fixture_evidence(enemy)
		if not evidence.valid or detected or enemy._sight_timer == 0.0: print("V214_VISION_PREFLIGHT="+JSON.stringify(evidence))
		conditions_valid = conditions_valid and evidence.valid
		if not conditions_valid: break
		if enemy._last_vision_result == Enemy.VISION_CHASE and enemy._has_requested_encounter:
			detected = true
			break
	_check(conditions_valid,"FIXTURE_CONFIGURATION: visual preconditions not sustained","FAIL_FIXTURE")
	if conditions_valid: _check(detected and enemy._current_contact_kind == "VISION" and CombatEncounterManager.get_debug_pending_count() == 1,"VISUAL_REACQUISITION: normal ticks did not reacquire")
	_check(not enemy._has_recent_sound_contact() and noise_events == 0,"residual auditory stimulus")
	_check(starts == 1 and endings == 1 and rewards == 0,"duplicate encounters/endings/rewards")
	print("V214_VISION_EVIDENCE="+JSON.stringify({"conditions_valid":conditions_valid,"detected":detected,"vision":enemy._last_vision_result,"sight_timer":enemy._sight_timer,"pending":CombatEncounterManager.get_debug_pending_count(),"enemy":str(enemy.global_position),"player":str(player.global_position)}))
