extends "res://scripts/tests/varkhem_v215_cover_validation.gd"

func _ready() -> void:
	await super._ready()
	CombatEncounterManager.combat_transition_enabled = false
	_manual_lane(3)
	var old_light: int = LightingManager.ambient_light_level
	LightingManager.set_ambient_light_level(0)
	await _wait(GUARD.perception_interval_sec*3)
	_check(guard._debug_fov_str == "YES" and guard._debug_los_str == "YES" and guard._last_vision_result == Enemy.VISION_NONE,"extreme darkness has geometry LOS but no visual suspicion")
	_check(guard.get_debug_state_name() == "PATROL" and not CombatEncounterManager.is_encounter_active(),"darkness does not open encounter")
	LightingManager.set_ambient_light_level(1)
	await _wait(GUARD.perception_interval_sec*2)
	_check(guard._last_vision_result == Enemy.VISION_ALERT and guard.get_debug_state_name() == "ALERT","partial exposure enters existing ALERT")
	_check(not CombatEncounterManager.is_encounter_active() and not guard._has_requested_encounter,"uncertain vision cannot open encounter")
	var observed := guard.get_debug_last_known_position()
	player.position = Vector3(-12,0.86,12)
	await _wait(GUARD.perception_interval_sec*3)
	_check(guard.get_debug_last_known_position() == observed,"hidden player never updates observed position")
	# New guard, same real physics/perception contracts, brighter functional room.
	_manual_lane(3)
	LightingManager.set_ambient_light_level(3)
	await _wait(GUARD.perception_interval_sec*2)
	_check(guard._last_vision_result == Enemy.VISION_ALERT,"light 3 preserves progressive acquisition")
	var deadline := Time.get_ticks_msec()+int((GUARD.detection_time_sec/GUARD.light_detection_curve[3]+GUARD.perception_interval_sec*3)*1000)
	while guard._last_vision_result != Enemy.VISION_CHASE and Time.get_ticks_msec() < deadline: await get_tree().physics_frame
	_check(guard._last_vision_result == Enemy.VISION_CHASE and guard._sight_timer >= GUARD.detection_time_sec,"functional light confirms through normal Timer")
	# Isolate prolonged uncertainty using a cloned configurable threshold;
	# actual production balance was checked above, no internal AI state forced.
	_manual_lane(3)
	guard.enemy_resource = GUARD.duplicate()
	guard.enemy_resource.detection_time_sec = 100.0
	guard.set_physics_process(true)
	LightingManager.set_ambient_light_level(1)
	var states: Array[String] = []
	var until := Time.get_ticks_msec()+int((GUARD.lose_target_timeout_sec+1.0)*1000)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		var state := guard.get_debug_state_name()
		if states.is_empty() or states.back() != state: states.append(state)
	_check(states == ["PATROL","ALERT"] or states == ["ALERT"],"sustained uncertainty does not oscillate states")
	_check(not CombatEncounterManager.is_encounter_active(),"sustained uncertainty never starts combat")
	observed = guard.get_debug_last_known_position()
	player.position = Vector3(-12,0.86,12)
	var search_seen := false
	until = Time.get_ticks_msec()+int((8.0/GameBalance.get_speed(GUARD.patrol_speed_tier)+GUARD.lose_target_timeout_sec+2.0)*1000)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		search_seen = search_seen or (guard.get_debug_state_name() == "ALERT" and guard._searching_at_last_known)
		if search_seen and guard.get_debug_state_name() == "PATROL": break
	_check(search_seen and guard.get_debug_state_name() == "PATROL","lost uncertain observation investigates and returns normally")
	_check(guard.get_debug_last_known_position() == observed,"search retains observed position, not hidden current Player")
	print("B_SUSPICION_STATES="+JSON.stringify(states))
	LightingManager.set_ambient_light_level(old_light)
	CombatEncounterManager.combat_transition_enabled = true
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	print("V215_B_PERCEPTION="+JSON.stringify({"valid":errors.is_empty(),"errors":errors}))
	get_tree().quit(0 if errors.is_empty() else 1)
