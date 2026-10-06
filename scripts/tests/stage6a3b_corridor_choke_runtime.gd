extends Node3D

## Regresión física del choke point inicial de Fortress6A. Desactiva sólo el
## proceso de IA del sujeto de prueba para que cada tick use el mismo helper de
## navegación productivo y move_and_slide() real, sin atravesar geometría ni
## sustituir el CharacterBody3D por un punto matemático.
const MOVE_SPEED_MPS := 2.0
const CROSS_X := 17.4
const MAX_SECONDS := 10.0


func _ready() -> void:
	var fortress: Node3D = $MainFortress6A/Fortress6A
	var enemy: Enemy = fortress.get_node("InitialMelee")
	CombatEncounterManager.combat_transition_enabled = false
	await get_tree().create_timer(0.5).timeout
	enemy.set_physics_process(false)
	var cases := [
		{"name": "CENTER", "start": Vector3(7.0, 1.0, 0.0), "target": Vector3(20.0, 1.0, 0.0)},
		{"name": "DIAGONAL_LEFT", "start": Vector3(7.0, 1.0, 2.3), "target": Vector3(20.0, 1.0, 0.0)},
		{"name": "DIAGONAL_RIGHT", "start": Vector3(7.0, 1.0, -2.3), "target": Vector3(20.0, 1.0, 0.0)},
		{"name": "WALL_GLANCING", "start": Vector3(7.0, 1.0, 0.8), "target": Vector3(20.0, 1.0, -0.2)},
		{"name": "CORNER_ENTRY", "start": Vector3(8.0, 1.0, 2.8), "target": Vector3(20.0, 1.0, 0.0)},
	]
	var passed := true
	for test_case in cases:
		if not await _cross_initial_choke(enemy, test_case):
			passed = false
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = true
	if passed:
		print("Stage6A3B corridor choke runtime: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3B corridor choke runtime: FAIL")
		get_tree().quit(1)


func _cross_initial_choke(enemy: Enemy, test_case: Dictionary) -> bool:
	var case_name: String = test_case["name"]
	var start: Vector3 = test_case["start"]
	var target: Vector3 = test_case["target"]
	enemy.velocity = Vector3.ZERO
	enemy.global_position = start
	enemy._navigation_target = Vector3.INF
	enemy._fallback_next_path_position = Vector3.INF
	await get_tree().physics_frame
	var crossed := false
	var blocked_elapsed := 0.0
	var max_collision_count := 0
	var last_position := enemy.global_position
	for tick in range(int(MAX_SECONDS * 60.0)):
		var reached := enemy._move_toward_point(target, MOVE_SPEED_MPS, 1.0 / 60.0)
		var requested_speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
		enemy.move_and_slide()
		var actual_displacement := enemy.global_position.distance_to(last_position)
		last_position = enemy.global_position
		var collisions := enemy.get_slide_collision_count()
		max_collision_count = maxi(max_collision_count, collisions)
		var physical_block := enemy._debug_nav_str == "OK" and requested_speed > 0.05 and actual_displacement < 0.001 and collisions > 0
		blocked_elapsed = blocked_elapsed + (1.0 / 60.0) if physical_block else 0.0
		if enemy.global_position.x >= CROSS_X:
			crossed = true
			print("6A3B CHOKE %s | crossed tick=%d pos=%s target=%s next=%.3f req=%.2f displacement=%.3f collisions=%d nav=%s" % [case_name, tick + 1, enemy.global_position, target, enemy._debug_next_path_distance_m, requested_speed, actual_displacement, collisions, enemy._debug_nav_str])
			break
		if blocked_elapsed >= 1.0:
			print("6A3B CHOKE %s | PHYSICAL BLOCKED pos=%s target=%s next=%.3f req=%.2f displacement=%.3f collisions=%d nav=%s" % [case_name, enemy.global_position, target, enemy._debug_next_path_distance_m, requested_speed, actual_displacement, collisions, enemy._debug_nav_str])
			break
		if reached:
			break
		await get_tree().physics_frame
	var final_distance := enemy.global_position.distance_to(target)
	print("6A3B CHOKE %s | result crossed=%s pos=%s target=%s final_dist=%.2f max_collisions=%d nav=%s" % [case_name, crossed, enemy.global_position, target, final_distance, max_collision_count, enemy._debug_nav_str])
	return crossed and blocked_elapsed < 1.0
