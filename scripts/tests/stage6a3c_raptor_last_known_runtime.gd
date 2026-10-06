extends Node3D

const BakeUtil = preload("res://scripts/tests/navigation_bake_test_util.gd")

## Reproduce el caso Android con un Varkhen Raptor real: confirma visión,
## obtiene una última posición visible, el Player rompe geometría y el Raptor
## debe reducir físicamente esa distancia hasta iniciar SEARCH. No se inyectan
## estados ni handlers de percepción.
const ESCAPE_POSITION := Vector3(29.0, 1.0, 8.0)


func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var raptor: Enemy = fortress.get_node("StorageRogue")
	var use_bc_height := "--nav-bc-height" in OS.get_cmdline_user_args()
	if use_bc_height:
		await BakeUtil.activate_bc_only(fortress, &"test_bc_last_known_source")
	CombatEncounterManager.combat_transition_enabled = false
	player.global_position = Vector3(100.0, 1.0, 100.0)
	raptor.global_position = Vector3(7.0, 1.0, 0.0)
	raptor.rotation.y = -PI / 2.0
	raptor.velocity = Vector3.ZERO
	raptor._navigation_target = Vector3.INF
	raptor._semantic_navigation_target = Vector3.INF
	# Se inmoviliza solamente la patrulla de este sujeto de prueba para que el
	# FOV de la adquisición no sea sustituido por un waypoint antes del primer
	# tick de percepción. La máquina, raycast, Timer y estados siguen reales.
	raptor._patrol_targets.clear()
	if use_bc_height:
		BakeUtil.align_agent_to_navigation_plane(raptor)
	await get_tree().create_timer(0.5).timeout

	# Adquisición real por visión y confirmación de CHASE.
	var acquired := false
	for _tick in range(120):
		var acquisition_forward := -raptor.global_transform.basis.z
		acquisition_forward.y = 0.0
		player.global_position = raptor.global_position + acquisition_forward.normalized() * 1.4
		await get_tree().physics_frame
		acquired = raptor.get_debug_state_name() == "CHASE" and raptor.get_debug_last_known_source() == "VISION"
		if acquired:
			break

	# La última visión válida ocurre todavía dentro del corredor; luego el
	# Player sale detrás de la geometría y fuera de hearing sin emitir ruido.
	var visible_forward := -raptor.global_transform.basis.z
	visible_forward.y = 0.0
	var last_visible_position := raptor.global_position + visible_forward.normalized() * 3.0
	player.global_position = last_visible_position
	await get_tree().create_timer(0.55).timeout
	player.global_position = ESCAPE_POSITION
	player.velocity = Vector3.ZERO

	var start_distance := raptor.global_position.distance_to(last_visible_position)
	var previous_distance := start_distance
	var reduced_distance := false
	var moved_physically := false
	var reached_search := false
	var stalled := false
	var physical_heading_ok := true
	for second in range(12):
		var before := raptor.global_position
		await get_tree().create_timer(1.0).timeout
		var displacement := raptor.global_position.distance_to(before)
		var known_distance := raptor.global_position.distance_to(raptor.get_debug_last_known_position())
		var forward := -raptor.global_transform.basis.z
		forward.y = 0.0
		var physical_heading := raptor.get_debug_physical_heading()
		if displacement > 0.05 and forward.length() > 0.01 and physical_heading.length() > 0.01:
			physical_heading_ok = physical_heading_ok and rad_to_deg(forward.normalized().angle_to(physical_heading.normalized())) < 8.0
		if known_distance < previous_distance - 0.05:
			reduced_distance = true
		if displacement > 0.05 and raptor.get_debug_movement_source() in ["LAST KNOWN", "SEARCH"]:
			moved_physically = true
		stalled = stalled or raptor.get_debug_ai_stalled()
		print("6A3C RAPTOR LAST KNOWN t=%d state=%s owner=%s source=%s contact=%s known_source=%s known_dist=%.2f nav_target=%s waypoint=%s req=%.2f displacement=%.2f rotation=%s stalled=%s" % [second + 1, raptor.get_debug_state_name(), raptor.get_debug_ai_owner(), raptor.get_debug_movement_source(), raptor._current_contact_kind, raptor.get_debug_last_known_source(), known_distance, raptor._debug_nav_target_str, raptor.get_debug_navigation_waypoint(), raptor._debug_requested_speed_mps, displacement, raptor.get_debug_rotation_owner(), raptor.get_debug_ai_stalled()])
		previous_distance = known_distance
		if raptor.get_debug_state_name() == "ALERT" and raptor.get_debug_movement_source() == "SEARCH":
			reached_search = true
			break
	var returned_to_patrol := true
	if use_bc_height and reached_search:
		await get_tree().create_timer(5.4).timeout
		returned_to_patrol = raptor.get_debug_state_name() == "PATROL"
		print("6A3C RAPTOR SEARCH RETURN state=%s source=%s stalled=%s" % [raptor.get_debug_state_name(), raptor.get_debug_movement_source(), raptor.get_debug_ai_stalled()])
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = true
	var final_distance := raptor.global_position.distance_to(raptor.get_debug_last_known_position())
	var passed := acquired and raptor.get_debug_last_known_source() == "VISION" and reduced_distance and moved_physically and reached_search and final_distance <= 0.4 and physical_heading_ok and not stalled and returned_to_patrol
	print("6A3C RAPTOR LAST KNOWN result | acquired=%s distance %.2f -> %.2f reduced=%s moved=%s search=%s heading=%s stalled=%s" % [acquired, start_distance, final_distance, reduced_distance, moved_physically, reached_search, physical_heading_ok, stalled])
	if passed:
		print("Stage6A3C Raptor LAST KNOWN runtime: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3C Raptor LAST KNOWN runtime: FAIL")
		get_tree().quit(1)
