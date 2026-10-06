extends Node3D

func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var enemy: Enemy = fortress.get_node("InitialMelee")
	await get_tree().create_timer(0.4).timeout
	# Exposición real dentro de FOV; esperar confirmación por perception timer.
	player.global_position = Vector3(9.0, 1.0, -0.7)
	player.rotation.y = PI / 2.0
	await get_tree().create_timer(1.15).timeout
	# Sale por la rama norte, fuera de FOV y de hearing; no se emite ruido.
	player.global_position = Vector3(29.0, 1.0, 8.0)
	player.velocity = Vector3.ZERO
	var last_dist := INF
	var moved_while_pending := false
	var reached_search := false
	var stalled := false
	for second in range(12):
		var before := enemy.global_position
		await get_tree().create_timer(1.0).timeout
		var displacement := enemy.global_position.distance_to(before)
		var known_dist := enemy.global_position.distance_to(enemy.get_debug_last_known_position())
		print("6A3B RUNAWAY t=%d state=%s owner=%s source=%s contact=%s known=%s known_dist=%.2f nav=%s req=%.2f displacement=%.2f encounter=%s stalled=%s" % [second + 1, enemy.get_debug_state_name(), enemy.get_debug_ai_owner(), enemy.get_debug_movement_source(), enemy.is_encounter_contact_valid(), enemy.get_debug_last_known_source(), known_dist, enemy._debug_nav_target_str, enemy._debug_requested_speed_mps, displacement, enemy._encounter_debug_state, enemy.get_debug_ai_stalled()])
		if displacement > 0.05 and enemy.get_debug_movement_source() in ["LAST KNOWN", "SEARCH"]:
			moved_while_pending = true
		if enemy.get_debug_ai_stalled(): stalled = true
		if enemy.get_debug_state_name() == "ALERT" and enemy.get_debug_movement_source() == "SEARCH":
			reached_search = true
			break
		last_dist = known_dist
	var passed := moved_while_pending and reached_search and not stalled
	CombatEncounterManager.reset()
	if passed:
		print("Stage6A3B runaway runtime: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3B runaway runtime: FAIL")
		get_tree().quit(1)
