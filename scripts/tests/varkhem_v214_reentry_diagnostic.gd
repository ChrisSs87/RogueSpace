extends "res://scripts/tests/stage5g_drop_integration.gd"

## Diagnostic observer only. Reuses the proven DROP fixture and low cage.
## Never sets reentry/AI flags or calls perception/registration internally.
var actor: Enemy
var subject: Node3D
var errors: Array[String] = []

func _evidence(label: String) -> Dictionary:
	var reason := "ELIGIBLE_LOCAL"
	if ExplorationState.is_suspended(): reason = "EXPLORATION_SUSPENDED"
	elif actor._excluded_from_active_encounter and CombatEncounterManager.is_encounter_active(): reason = "EXCLUDED_ACTIVE_ENCOUNTER"
	elif actor._must_lose_contact_before_reentry: reason = "MUST_LOSE_CONTACT_BEFORE_REENTRY"
	elif actor._has_requested_encounter: reason = "ALREADY_REQUESTED"
	elif actor._encounter_join_closed: reason = "JOIN_CLOSED"
	var eye := actor.get_vision_origin()
	var ray := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,subject.global_position,Enemy.WORLD_COLLISION_MASK))
	var row := {"phase":label,"ms":Time.get_ticks_msec(),"state":actor.get_debug_state_name(),"owner":actor.get_debug_ai_owner(),"actor":str(actor.global_position),"player":str(subject.global_position),"distance":actor.global_position.distance_to(subject.global_position),"vision":actor._last_vision_result,"sound_recent":actor._has_recent_sound_contact(),"contact":actor._current_contact_kind,"must_lose":actor._must_lose_contact_before_reentry,"excluded":actor._excluded_from_active_encounter,"join_closed":actor._encounter_join_closed,"requested":actor._has_requested_encounter,"reason":reason,"manager_active":CombatEncounterManager.is_encounter_active(),"pending":CombatEncounterManager.get_debug_pending_count(),"combatants":CombatManager.get_combatant_count(),"suspended":ExplorationState.is_suspended(),"ready":actor.is_combat_position_valid(subject,CombatEncounterManager.combat_distance_tolerance_m),"los":ray.is_empty(),"collider":str(ray.collider.get_path()) if not ray.is_empty() else "NONE"}
	var heading := -actor.global_basis.z
	heading.y = 0
	var toward := subject.global_position-actor.global_position
	toward.y = 0
	var angle := rad_to_deg(heading.normalized().angle_to(toward.normalized()))
	row["heading"] = str(heading)
	row["toward_player"] = str(toward)
	row["fov_angle_to_player"] = angle
	row["fov_valid"] = angle <= actor.get_debug_fov_angle_deg()/2
	print("V214_REENTRY_TRACE="+JSON.stringify(row))
	return row

func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if predicate.call(): return true
	return false

func _ready() -> void:
	CombatManager.combat_started.connect(func(): combat_starts += 1)
	CombatManager.combat_ended.connect(func(): combat_endings += 1)
	RewardManager.reward_sequence_started.connect(func(): reward_starts += 1)
	var sandbox: Node3D = $DungeonSandbox
	await get_tree().physics_frame
	await get_tree().physics_frame
	for child in sandbox.get_children():
		if child is Enemy:
			# Disabled processing does not disconnect public noise signals.
			# Remove unrelated fixture inhabitants before emitting any stimulus.
			child.queue_free()
	await get_tree().physics_frame
	subject = TestPlayer.new()
	subject.add_to_group("player")
	add_child(subject)
	subject.global_position = Vector3(15,1,-3)
	actor = ENEMY_SCENE.instantiate()
	actor.enemy_resource = ORC_RESOURCE
	sandbox.add_child(actor)
	actor.global_position = Vector3(13.23,1,-1.23)
	if not await _until(func(): return actor._has_requested_encounter,5.0):
		_finish("FIXTURE_CONFIGURATION: natural candidate unavailable")
		return
	_evidence("NATURAL_CANDIDATE")
	actor.global_position = Vector3(12.6,1,-0.8)
	actor.look_at(Vector3(subject.global_position.x,actor.global_position.y,subject.global_position.z))
	# The original DROP fixture holds movement during the join window only.
	actor.set_physics_process(false)
	if not await _until(func(): return actor.get_debug_state_name() == "APPROACH",CombatEncounterManager.join_window_sec+1.0):
		_finish("FIXTURE_CONFIGURATION: APPROACH unavailable")
		return
	_evidence("APPROACH")
	_add_low_approach_cage(sandbox,actor.global_position)
	actor.set_physics_process(true)
	if not await _until(func(): return actor._must_lose_contact_before_reentry and not CombatEncounterManager.is_encounter_active(),CombatEncounterManager.global_encounter_timeout_sec+actor.enemy_resource.perception_interval_sec*3):
		_finish("timeout cancellation not observed")
		return
	_evidence("TIMEOUT_CANCELLED")
	var held := true
	# More than the existing loss/search timeout, sampled via ordinary ticks.
	var deadline := Time.get_ticks_msec()+int((actor.enemy_resource.lose_target_timeout_sec+actor.enemy_resource.perception_interval_sec*2)*1000)
	var next_log := Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		held = held and actor.is_encounter_contact_valid() and actor._must_lose_contact_before_reentry and CombatEncounterManager.get_debug_pending_count() == 0
		if Time.get_ticks_msec() >= next_log:
			_evidence("CONTINUOUS_VISION")
			next_log += int(actor.enemy_resource.perception_interval_sec*1000)
	if not held: errors.append("continuous-vision premise or predicted block did not hold")
	if OS.get_cmdline_user_args().has("--sound-stream"):
		# Independent auditory contract: keep the physical approach obstacle.
		# No assertion that restoring a fixed player position gives valid FOV
		# after investigation. Visual recovery is exercised by the default run.
		subject.global_position = Vector3(100,1,0)
		EventBus.player_noise_emitted.emit(actor.global_position+Vector3(0.5,0,0),5.0,1.0)
		_evidence("SINGLE_SOUND")
		var stream_end := Time.get_ticks_msec()+int(actor.enemy_resource.lose_target_timeout_sec*1000)
		var next_sound := Time.get_ticks_msec()+int(Enemy.SOUND_CONTACT_MEMORY_SEC*500)
		var held_sound := true
		while Time.get_ticks_msec() < stream_end:
			await get_tree().physics_frame
			if Time.get_ticks_msec() >= next_sound:
				EventBus.player_noise_emitted.emit(actor.global_position+Vector3(0.5,0,0),5.0,1.0)
				_evidence("RENEWED_SOUND")
				next_sound = Time.get_ticks_msec()+int(Enemy.SOUND_CONTACT_MEMORY_SEC*500)
			held_sound = held_sound and actor._must_lose_contact_before_reentry and CombatEncounterManager.get_debug_pending_count() == 0
		if not held_sound: errors.append("renewed-sound block premise did not hold")
		var lost := await _until(func(): return not actor._must_lose_contact_before_reentry and not actor.is_encounter_contact_valid(),Enemy.SOUND_CONTACT_MEMORY_SEC+actor.enemy_resource.perception_interval_sec*3)
		_evidence("SINGLE_SOUND_EXPIRED")
		if not lost: errors.append("sound did not release reentry after expiration")
		if CombatEncounterManager.get_debug_pending_count() != 0 or combat_starts != 0: errors.append("auditory expiration created an unsolicited encounter")
		_finish("")
		return
	# Original reproduction: preserve continuous vision while removing only
	# the approach obstacle. The new normal perception tick must reopen once.
	for wall in get_tree().get_nodes_in_group("stage5g_drop_cage"): wall.queue_free()
	var physically_ready := await _until(func(): return actor.is_combat_position_valid(subject,CombatEncounterManager.combat_distance_tolerance_m),actor.enemy_resource.combat_approach_timeout_sec)
	var ready_row := _evidence("OBSTACLE_REMOVED_READY")
	if not physically_ready or not ready_row.los or not actor.is_encounter_contact_valid(): errors.append("valid combat band and continuous contact not demonstrated")
	var combat := await _until(func(): return CombatManager.get_combatant_count() == 1,CombatEncounterManager.join_window_sec+actor.enemy_resource.combat_approach_timeout_sec)
	_evidence("NEW_COMBAT")
	if not combat or combat_starts != 1 or actor._must_lose_contact_before_reentry: errors.append("single real combat after total cancellation not demonstrated")
	var observe_until := Time.get_ticks_msec()+int(actor.enemy_resource.perception_interval_sec*2*1000)
	while Time.get_ticks_msec() < observe_until:
		await get_tree().physics_frame
		if combat_starts != 1 or CombatManager.get_combatant_count() != 1: errors.append("duplicate or unstable combat after reentry")
	_finish("")

func _finish(error: String) -> void:
	if not error.is_empty(): errors.append(error)
	print("V214_REENTRY_DIAGNOSTIC="+JSON.stringify({"valid":errors.is_empty(),"errors":errors,"combat_starts":combat_starts,"interpretation":"diagnostic confirms current behavior, not approval of proposed fix"}))
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	if subject != null: subject.unfreeze_after_combat()
	get_tree().quit(0 if errors.is_empty() else 1)
