extends Node3D

## El obstáculo temporal fuerza una ruta que NavigationAgent considera válida
## pero bloquea físicamente al CharacterBody. Registra cada physics frame:
## sin desplazamiento real no puede haber grandes saltos de orientación.
const LARGE_UNJUSTIFIED_TURN_DEG := 25.0


func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var enemy: Enemy = fortress.get_node("InitialMelee")
	CombatEncounterManager.combat_transition_enabled = false
	player.global_position = Vector3(100.0, 1.0, 100.0)
	enemy.global_position = Vector3(7.0, 1.0, 0.0)
	enemy.rotation.y = -PI / 2.0
	enemy.velocity = Vector3.ZERO
	enemy._navigation_target = Vector3.INF
	enemy._semantic_navigation_target = Vector3.INF
	await get_tree().create_timer(0.5).timeout
	# Evento real de ruido: ALERT persigue el objetivo a través de una entrada
	# oblicua. La barrera no entra en la NavigationMesh a propósito.
	var target := Vector3(10.0, 1.0, -0.7)
	EventBus.player_noise_emitted.emit(target, 5.0, 5.0)
	await get_tree().physics_frame
	var barrier := _add_glancing_barrier(fortress)
	var previous_position := enemy.global_position
	var previous_forward := _flat_forward(enemy)
	var unjustified_turns := 0
	var max_unjustified_turn := 0.0
	var recovery_seen := false
	for tick in range(240):
		await get_tree().physics_frame
		var displacement := enemy.global_position.distance_to(previous_position)
		var forward := _flat_forward(enemy)
		if displacement < 0.002 and forward.length() > 0.01 and previous_forward.length() > 0.01:
			var turn := rad_to_deg(forward.angle_to(previous_forward))
			max_unjustified_turn = maxf(max_unjustified_turn, turn)
			if turn > LARGE_UNJUSTIFIED_TURN_DEG:
				unjustified_turns += 1
		previous_position = enemy.global_position
		previous_forward = forward
		recovery_seen = recovery_seen or enemy.get_debug_stuck_recovery_count() > 0
		if tick % 60 == 59:
			print("6A3C ORIENTATION t=%.1f pos=%s state=%s source=%s nav=%s waypoint=%s physical=%s rotation=%s turn_max=%.1f" % [(tick + 1) / 60.0, enemy.global_position, enemy.get_debug_state_name(), enemy.get_debug_movement_source(), enemy._debug_nav_target_str, enemy.get_debug_navigation_waypoint(), enemy.get_debug_physical_movement_state(), enemy.get_debug_rotation_owner(), max_unjustified_turn])
	barrier.queue_free()
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = true
	var passed := recovery_seen and unjustified_turns == 0
	print("6A3C ORIENTATION result | recovery=%s unjustified_turns=%d max_turn=%.1f" % [recovery_seen, unjustified_turns, max_unjustified_turn])
	if passed:
		print("Stage6A3C orientation stability runtime: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3C orientation stability runtime: FAIL")
		get_tree().quit(1)


func _flat_forward(enemy: Enemy) -> Vector3:
	var forward := -enemy.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.ZERO


func _add_glancing_barrier(parent: Node3D) -> StaticBody3D:
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 1
	barrier.collision_mask = 4
	barrier.position = Vector3(8.2, 1.0, -0.35)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 2.0, 3.0)
	collision.shape = shape
	barrier.add_child(collision)
	parent.add_child(barrier)
	return barrier
