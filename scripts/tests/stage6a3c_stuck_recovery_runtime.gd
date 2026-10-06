extends Node3D

## Inserta una obstrucción física estrecha que no forma parte de la malla.
## El NavigationAgent mantiene NAV: OK, pero el CharacterBody debe detectar
## la falta de desplazamiento, recuperar lateralmente y seguir hacia el mismo
## patrol target sin teletransporte.
func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var enemy: Enemy = fortress.get_node("InitialMelee")
	CombatEncounterManager.combat_transition_enabled = false
	player.global_position = Vector3(100.0, 1.0, 100.0)
	player.velocity = Vector3.ZERO
	enemy.global_position = Vector3(7.0, 1.0, 0.0)
	enemy.rotation.y = -PI / 2.0
	enemy.velocity = Vector3.ZERO
	enemy._navigation_target = Vector3.INF
	await get_tree().create_timer(0.5).timeout
	# Entrada sensorial real del sistema: ALERT debe investigar este LAST KNOWN
	# aun después del desbloqueo físico; nunca se inyecta el estado de IA.
	var last_known_target := Vector3(10.0, 1.0, -0.7)
	EventBus.player_noise_emitted.emit(last_known_target, 5.0, 5.0)
	await get_tree().physics_frame
	var barrier := _add_glancing_barrier(fortress)
	var recovery_seen := false
	var barrier_released := false
	var crossed_barrier := false
	var target_distance_start := enemy.global_position.distance_to(last_known_target)
	var max_stationary_turn_deg := 0.0
	var previous_forward := -enemy.global_transform.basis.z
	var previous_position := enemy.global_position
	for second in range(8):
		await get_tree().create_timer(1.0).timeout
		var displacement := enemy.global_position.distance_to(previous_position)
		var current_forward := -enemy.global_transform.basis.z
		current_forward.y = 0.0
		previous_forward.y = 0.0
		if displacement < 0.01 and current_forward.length() > 0.01 and previous_forward.length() > 0.01:
			max_stationary_turn_deg = maxf(max_stationary_turn_deg, rad_to_deg(current_forward.normalized().angle_to(previous_forward.normalized())))
		previous_forward = current_forward
		previous_position = enemy.global_position
		# La recuperación puede completar su sonda entre dos muestras de un
		# segundo. El contador debug conserva el evento real sin exigir que el
		# texto transitorio siga visible al momento de imprimir.
		recovery_seen = recovery_seen or enemy.get_debug_stuck_recovery_count() > 0
		if recovery_seen and not barrier_released:
			barrier.queue_free()
			barrier_released = true
		crossed_barrier = crossed_barrier or enemy.global_position.x > 8.7
		print("6A3C STUCK t=%d state=%s source=%s nav=%s physical=%s pos=%s target=%s next=%.2f req=%.2f move=%.2f collisions=%d last_known_dist=%.2f" % [second + 1, enemy.get_debug_state_name(), enemy.get_debug_last_known_source(), enemy._debug_nav_str, enemy.get_debug_physical_movement_state(), enemy.global_position, enemy._debug_nav_target_str, enemy._debug_next_path_distance_m, enemy._debug_requested_speed_mps, displacement, enemy.get_slide_collision_count(), enemy.global_position.distance_to(last_known_target)])
		if recovery_seen and crossed_barrier:
			break
	if not barrier_released:
		barrier.queue_free()
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = true
	var target_distance_end := enemy.global_position.distance_to(last_known_target)
	var passed := recovery_seen and crossed_barrier and target_distance_end < target_distance_start and enemy.get_debug_last_known_source() == "SOUND" and max_stationary_turn_deg < 25.0
	print("6A3C STUCK result | recovery=%s crossed=%s target %.2f -> %.2f stationary_turn=%.1f" % [recovery_seen, crossed_barrier, target_distance_start, target_distance_end, max_stationary_turn_deg])
	if passed:
		print("Stage6A3C stuck recovery runtime: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3C stuck recovery runtime: FAIL")
		get_tree().quit(1)


func _add_glancing_barrier(parent: Node3D) -> StaticBody3D:
	var barrier := StaticBody3D.new()
	barrier.name = "StuckRecoveryBarrier"
	barrier.collision_layer = 1
	barrier.collision_mask = 4
	barrier.position = Vector3(8.2, 1.0, -0.35)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Bloqueo temporal de la sección: NAV sigue dando ruta porque la barrera no
	# forma parte de la NavigationMesh, pero el cuerpo no puede avanzar hasta
	# que la recuperación invalida esa ruta. Se retira inmediatamente después.
	shape.size = Vector3(0.35, 2.0, 3.0)
	collision.shape = shape
	barrier.add_child(collision)
	parent.add_child(barrier)
	return barrier
