extends "res://scripts/tests/core_p0r2_encounter_validation.gd"

## Real actors/input/nav; no synthetic contact, candidacy, READY or combat.
func _ready() -> void:
	mode = "escape"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
	LightingManager.set_ambient_light_level(3)
	floor_body = CSGBox3D.new()
	floor_body.size = Vector3(50,0.2,50)
	floor_body.position.y = -0.1
	floor_body.use_collision = true
	add_child(floor_body)
	region = NavigationRegion3D.new()
	add_child(region)
	_nav_rect(Vector2(-24,-24),Vector2(24,24))
	player = PLAYER.instantiate()
	player.position = Vector3(0,0.86,0)
	add_child(player)
	var guard := _actor(Vector3(0,0.91,7),VARKHEN)
	# Hold movement, not perception, until reservation; separates distance
	# from fast physical pursuit during visual confirmation/join window.
	guard.set_physics_process(false)
	CombatManager.combat_started.connect(func(): starts += 1; start_rows.append(_snapshot("COMBAT_STARTED")))
	started_msec = Time.get_ticks_msec()
	setup_ok = await _until(func(): return player.is_on_floor() and NavigationServer3D.map_get_path(region.get_navigation_map(),guard.global_position,player.global_position,true).size() >= 2,3.0)
	if not setup_ok:
		errors.append("FAIL_FIXTURE: floor/navigation")
		_finish()
		return
	if not await _until(func(): return CombatEncounterManager.is_encounter_active(),CombatEncounterManager.join_window_sec+VARKHEN.detection_time_sec/0.8+VARKHEN.perception_interval_sec*3):
		errors.append("FAIL_FIXTURE: confirmed visual reservation not reached")
		_finish()
		return
	_snapshot("RESERVED_AT_DISTANCE")
	if player.is_frozen or ExplorationState.is_suspended() or starts != 0:
		errors.append("FAIL_PRODUCTION: preparation blocked Player before COMBAT at %.3fm" % guard.global_position.distance_to(player.global_position))
		_finish()
		return
	var from := player.global_position
	if mode == "cancel":
		CombatEncounterManager.reset()
		if guard.has_combat_positioning(): errors.append("cancel retained actor ownership")
	if mode == "los":
		barrier = _box(Vector3(0,1.5,3.5),Vector3(30,3,0.2))
	guard.set_physics_process(mode != "cancel")
	Input.action_press("move_forward")
	var sample_seconds := VARKHEN.perception_interval_sec*3
	var deadline := Time.get_ticks_msec()+int(sample_seconds*1000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if starts == 0 and (player.is_frozen or ExplorationState.is_suspended()): errors.append("precombat suspension during escape")
	Input.action_release("move_forward")
	var progress := from.distance_to(player.global_position)
	print("C1_INPUT="+JSON.stringify({"case":mode,"progress":progress,"expected_m":player.get_current_speed_mps()*sample_seconds,"distance":guard.global_position.distance_to(player.global_position),"starts":starts}))
	if progress < player.get_current_speed_mps()*sample_seconds*0.7: errors.append("real Player input did not produce progress")
	_snapshot("AFTER_INPUT")
	if mode == "catch":
		if not await _until(func(): return starts > 0,CombatEncounterManager.global_encounter_timeout_sec+VARKHEN.perception_interval_sec): errors.append("valid approach did not start combat")
		if starts != 1 or not player.is_frozen or not ExplorationState.is_suspended(): errors.append("effective combat did not suspend exactly once")
		if not start_rows.is_empty() and (not start_rows[0].actors[0].ready or start_rows[0].actors[0].distance > CombatEncounterManager.combat_max_distance_m): errors.append("combat admitted before current position valid")
	elif mode == "los":
		await _until(func(): return not CombatEncounterManager.is_encounter_active(),CombatEncounterManager.global_encounter_timeout_sec+VARKHEN.perception_interval_sec*2)
		if starts != 0 or player.is_frozen or ExplorationState.is_suspended() or CombatEncounterManager.is_encounter_active(): errors.append("LOS loss failed to cancel without combat/blocking")
	elif mode == "escape":
		# Continue real retreat through several normal sensory ticks. Relative
		# progress is measured, not inferred from is_frozen alone.
		Input.action_press("move_forward")
		from = player.global_position
		await _until(func(): return starts > 0,1.0)
		Input.action_release("move_forward")
		if starts != 0 or player.global_position.distance_to(from) < player.get_current_speed_mps()*0.7: errors.append("ongoing pursuit prevented retreat")
	_snapshot("FINAL_CONTROL")
	_finish()

func _finish() -> void:
	Input.action_release("move_forward")
	super._finish()
