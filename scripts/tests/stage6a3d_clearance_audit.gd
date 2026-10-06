extends Node3D

## Auditoría física de la NavigationMesh existente. Cada caso usa la cápsula
## real y move_and_slide(), no sólo map_get_path. Las rutas cubren todas las
## entradas de corredor de Fortress6A en ambos sentidos y con aproximaciones
## diagonales repetidas. No invoca stuck recovery: una ruta normal debe pasar
## por sí misma.
const SPEED_MPS := 2.0
const MAX_TICKS := 900
const ARRIVAL_M := 0.35


func _ready() -> void:
	var fortress: Node3D = $MainFortress6A/Fortress6A
	var enemy: Enemy = fortress.get_node("InitialMelee")
	CombatEncounterManager.combat_transition_enabled = false
	await get_tree().create_timer(0.5).timeout
	print("6A3D CLEARANCE CONFIG | capsule_radius=0.40 capsule_diameter=0.80 agent_radius=%.2f path_desired=%.2f target_desired=%.2f avoidance=%s" % [enemy.navigation_agent.radius, enemy.navigation_agent.path_desired_distance, enemy.navigation_agent.target_desired_distance, enemy.navigation_agent.avoidance_enabled])
	enemy.set_physics_process(false)
	var cases := [
		{"name": "ENTRY_EAST", "start": Vector3(7.0, 1.0, 0.0), "target": Vector3(20.0, 1.0, 0.0)},
		{"name": "ENTRY_WEST_DIAG", "start": Vector3(20.0, 1.0, 0.65), "target": Vector3(7.0, 1.0, -0.65)},
		{"name": "STORAGE_TO_CONVERGENCE", "start": Vector3(30.0, 1.0, 6.0), "target": Vector3(45.0, 1.0, 0.0)},
		{"name": "CONVERGENCE_TO_STORAGE_DIAG", "start": Vector3(45.0, 1.0, 1.2), "target": Vector3(30.0, 1.0, 6.6)},
		{"name": "BARRACKS_TO_CONVERGENCE", "start": Vector3(30.0, 1.0, -6.0), "target": Vector3(45.0, 1.0, 0.0)},
		{"name": "CONVERGENCE_TO_BARRACKS_DIAG", "start": Vector3(45.0, 1.0, -1.2), "target": Vector3(30.0, 1.0, -6.6)},
		{"name": "FINAL_EAST", "start": Vector3(45.0, 1.0, 0.0), "target": Vector3(62.0, 1.0, 0.0)},
		{"name": "FINAL_WEST_DIAG", "start": Vector3(62.0, 1.0, 1.1), "target": Vector3(45.0, 1.0, -1.1)},
		# Matriz determinista de corners: entradas cerca de pared, ambos sentidos
		# y diagonales que obligan a doblar 90 grados. Estos casos complementan
		# las ocho rutas limpias; todos usan la cápsula física y move_and_slide.
		{"name": "ENTRY_NORTH_EDGE_EAST", "start": Vector3(7.2, 1.0, 0.88), "target": Vector3(20.0, 1.0, 0.82)},
		{"name": "ENTRY_SOUTH_EDGE_EAST", "start": Vector3(7.2, 1.0, -0.88), "target": Vector3(20.0, 1.0, -0.82)},
		{"name": "ENTRY_NORTH_EDGE_WEST", "start": Vector3(20.0, 1.0, 0.82), "target": Vector3(7.2, 1.0, 0.88)},
		{"name": "ENTRY_SOUTH_EDGE_WEST", "start": Vector3(20.0, 1.0, -0.82), "target": Vector3(7.2, 1.0, -0.88)},
		# Reproducción Android: aproximaciones diagonales a la boca x=9/z=-0.8.
		# El helper se ejecuta sin _physics_process, por lo que stuck recovery
		# queda neutralizado: sólo puede aprobar si la cápsula cruza por ruta
		# física normal y continúa varios metros al otro lado.
		{"name": "ENTRY_REPRO_7_NEG3P2", "start": Vector3(7.0, 1.0, -3.20), "target": Vector3(15.0, 1.0, -0.45)},
		{"name": "ENTRY_REPRO_8_NEG3", "start": Vector3(8.0, 1.0, -3.00), "target": Vector3(15.0, 1.0, -0.45)},
		{"name": "ENTRY_REPRO_8P5_NEG2", "start": Vector3(8.5, 1.0, -2.00), "target": Vector3(15.0, 1.0, -0.45)},
		{"name": "ENTRY_REPRO_SHORT_8P5_NEG2", "start": Vector3(8.5, 1.0, -2.00), "target": Vector3(10.0, 1.0, -0.70)},
		{"name": "ENTRY_CONTROL_5_NEG3", "start": Vector3(5.0, 1.0, -3.00), "target": Vector3(15.0, 1.0, -0.45)},
		{"name": "ENTRY_REPRO_REVERSE_7_NEG3P2", "start": Vector3(15.0, 1.0, -0.45), "target": Vector3(7.0, 1.0, -3.20)},
		{"name": "ENTRY_REPRO_REVERSE_8_NEG3", "start": Vector3(15.0, 1.0, -0.45), "target": Vector3(8.0, 1.0, -3.00)},
		{"name": "ENTRY_REPRO_REVERSE_8P5_NEG2", "start": Vector3(15.0, 1.0, -0.45), "target": Vector3(8.5, 1.0, -2.00)},
		{"name": "ENTRY_CONTROL_REVERSE_5_NEG3", "start": Vector3(15.0, 1.0, -0.45), "target": Vector3(5.0, 1.0, -3.00)},
		{"name": "NORTH_CHOKE_WEST_DIAG", "start": Vector3(44.5, 1.0, 3.28), "target": Vector3(31.0, 1.0, 6.35)},
		{"name": "NORTH_CHOKE_EAST_DIAG", "start": Vector3(31.0, 1.0, 6.35), "target": Vector3(44.5, 1.0, 3.28)},
		{"name": "NORTH_CHOKE_LOW_EDGE", "start": Vector3(35.9, 1.0, 2.63), "target": Vector3(40.3, 1.0, 3.35)},
		{"name": "NORTH_CHOKE_HIGH_EDGE", "start": Vector3(40.3, 1.0, 3.35), "target": Vector3(35.9, 1.0, 2.63)},
		{"name": "SOUTH_CHOKE_WEST_DIAG", "start": Vector3(44.5, 1.0, -3.28), "target": Vector3(31.0, 1.0, -6.35)},
		{"name": "SOUTH_CHOKE_EAST_DIAG", "start": Vector3(31.0, 1.0, -6.35), "target": Vector3(44.5, 1.0, -3.28)},
		{"name": "SOUTH_CHOKE_HIGH_EDGE", "start": Vector3(35.9, 1.0, -2.63), "target": Vector3(40.3, 1.0, -3.35)},
		{"name": "SOUTH_CHOKE_LOW_EDGE", "start": Vector3(40.3, 1.0, -3.35), "target": Vector3(35.9, 1.0, -2.63)},
	]
	var route_filter := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--clearance-filter="):
			route_filter = argument.trim_prefix("--clearance-filter=")
	var passed := true
	for route in cases:
		if not route_filter.is_empty() and not String(route["name"]).contains(route_filter):
			continue
		# Las rutas base se repiten tres veces; la matriz añade offsets/ángulos
		# físicos distintos y se ejecuta una vez cada uno para mantener el test
		# determinista y con diagnóstico individual.
		var repetitions := 3 if not String(route["name"]).contains("EDGE") and not String(route["name"]).contains("CHOKE") else 1
		for repetition in range(repetitions):
			var result := await _run_route(enemy, fortress, route, repetition + 1)
			passed = passed and result
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = true
	if passed:
		print("Stage6A3D physical clearance audit: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3D physical clearance audit: FAIL")
		get_tree().quit(1)


func _run_route(enemy: Enemy, fortress: Node3D, route: Dictionary, repetition: int) -> bool:
	var start: Vector3 = route["start"]
	var target: Vector3 = route["target"]
	enemy.global_position = start
	enemy.velocity = Vector3.ZERO
	enemy._navigation_target = Vector3.INF
	enemy._semantic_navigation_target = Vector3.INF
	enemy._fallback_next_path_position = Vector3.INF
	await get_tree().physics_frame
	var initial_distance := enemy.global_position.distance_to(target)
	var stationary_elapsed := 0.0
	var max_stationary_elapsed := 0.0
	var recovery_count_before := enemy.get_debug_stuck_recovery_count()
	var max_stationary_turn := 0.0
	var min_wall_clearance := _wall_clearance_at(fortress, enemy.global_position)
	var min_clearance_position := enemy.global_position
	var previous_forward := _flat_forward(enemy)
	var reached := false
	for tick in range(MAX_TICKS):
		var before := enemy.global_position
		var _arrived := enemy._move_toward_point(target, SPEED_MPS, 1.0 / 60.0)
		enemy.move_and_slide()
		var displacement := enemy.global_position.distance_to(before)
		var remaining := enemy.global_position.distance_to(target)
		var forward := _flat_forward(enemy)
		var current_clearance := _wall_clearance_at(fortress, enemy.global_position)
		if current_clearance < min_wall_clearance:
			min_wall_clearance = current_clearance
			min_clearance_position = enemy.global_position
		if displacement < 0.002 and forward.length() > 0.01 and previous_forward.length() > 0.01:
			max_stationary_turn = maxf(max_stationary_turn, rad_to_deg(forward.angle_to(previous_forward)))
		previous_forward = forward
		# En una esquina una ruta válida puede alejarse unos frames del destino
		# euclídeo mientras rodea la pared. El bloqueo físico relevante es pedir
		# velocidad y no desplazar el CharacterBody; la llegada final comprueba
		# que la ruta completa sí progresó hacia el destino.
		if enemy._debug_nav_str == "OK" and Vector2(enemy.velocity.x, enemy.velocity.z).length() > 0.05 and displacement < 0.002:
			stationary_elapsed += 1.0 / 60.0
		else:
			stationary_elapsed = 0.0
		max_stationary_elapsed = maxf(max_stationary_elapsed, stationary_elapsed)
		if remaining <= ARRIVAL_M:
			reached = true
			break
		await get_tree().physics_frame
	var final_distance := enemy.global_position.distance_to(target)
	var recovery_count_after := enemy.get_debug_stuck_recovery_count()
	var passed := reached and final_distance <= ARRIVAL_M and min_wall_clearance >= 0.45 and max_stationary_elapsed < 0.75 and max_stationary_turn < 25.0 and recovery_count_after == recovery_count_before
	print("6A3D CLEARANCE %s #%d | %.2f -> %.2f reached=%s min_wall_clearance=%.3f at=(%.2f,%.2f) max_stationary=%.2f stationary_turn=%.1f recoveries=%d nav=%s" % [route["name"], repetition, initial_distance, final_distance, reached, min_wall_clearance, min_clearance_position.x, min_clearance_position.z, max_stationary_elapsed, max_stationary_turn, recovery_count_after - recovery_count_before, enemy._debug_nav_str])
	return passed


func _flat_forward(enemy: Enemy) -> Vector3:
	var forward := -enemy.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.ZERO


## Clearance horizontal del CENTRO de la cápsula a los CSGBox3D de pared.
## El suelo no pertenece al conjunto Walls. Para r=0.40, el contrato de esta
## etapa exige >=0.45 m en toda la trayectoria, no sólo en sus vértices.
func _wall_clearance_at(fortress: Node3D, position: Vector3) -> float:
	var closest := INF
	var walls := fortress.get_node_or_null("Walls")
	if walls == null:
		return closest
	for node in walls.get_children():
		if node is CSGBox3D:
			var wall := node as CSGBox3D
			var half := wall.size * 0.5
			var local := wall.to_local(position)
			var dx := maxf(absf(local.x) - half.x, 0.0)
			var dz := maxf(absf(local.z) - half.z, 0.0)
			closest = minf(closest, Vector2(dx, dz).length())
	return closest
