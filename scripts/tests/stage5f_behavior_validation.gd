extends Node3D

## Integración 5F: ejercicio real de física para patrulla y pérdida de
## contacto. No modifica recursos ni depende de entradas del jugador.

const PATROLLERS: Array[String] = ["OrcoMelee1", "OrcoMelee2", "OrcoPicaro1", "OrcoMelee3", "OrcoPicaro2"]


func _ready() -> void:
	var sandbox: Node3D = $DungeonSandbox
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var starts: Dictionary = {}
	for enemy_name in PATROLLERS:
		var enemy: Enemy = sandbox.get_node(enemy_name)
		starts[enemy_name] = enemy.global_position

	await get_tree().create_timer(5.0).timeout
	var failures: Array[String] = []
	for enemy_name in PATROLLERS:
		var enemy: Enemy = sandbox.get_node(enemy_name)
		var moved: float = enemy.global_position.distance_to(starts[enemy_name])
		print("PATROL MOTION %s | %.2f m" % [enemy_name, moved])
		if moved < 0.5:
			failures.append("%s no se desplazó significativamente" % enemy_name)

	# B/C/E: el jugador estaba en A, se movió fuera de percepción a B. El
	# Xeno conserva A, navega allí y deja CHASE al llegar; can_lose_interest
	# no puede dejarlo detenido en CHASE.
	var player := Node3D.new()
	player.name = "ValidationPlayer"
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector3(100.0, 1.0, 0.0) # B: fuera de percepción.
	var xeno: Enemy = sandbox.get_node("Xenomorfo1")
	var known_a := Vector3(29.0, 1.0, -3.0)
	var unseen_b := player.global_position
	CombatEncounterManager.reset()
	xeno._on_player_seen(known_a, true)
	xeno._encounter_contact_valid = false
	await get_tree().create_timer(1.2).timeout
	var known_after: Vector3 = xeno.get_debug_last_known_position()
	var distance_to_a: float = xeno.global_position.distance_to(known_a)
	print("LAST KNOWN | saved %s | player unseen B %s | xeno %s | distance to A %.2f | state %s" % [known_after, unseen_b, xeno.global_position, distance_to_a, xeno.get_debug_state_name()])
	if known_after.distance_to(known_a) > 0.01 or known_after.distance_to(unseen_b) < 1.0:
		failures.append("Xeno no conservó A como última posición conocida")
	if distance_to_a > 0.45:
		failures.append("Xeno no navegó hasta A")
	if xeno.get_debug_state_name() != "ALERT":
		failures.append("Xeno quedó en CHASE en vez de ALERT al llegar a A")

	# D: una nueva señal audible durante ALERT actualiza la posición y aplica
	# el perfil vigente (Horvex investiga ruido; no confundir oído con visión).
	var heard_c := Vector3(28.0, 1.0, -2.0)
	xeno._on_player_heard(heard_c)
	print("RECOVERY | heard %s | saved %s | state %s" % [heard_c, xeno.get_debug_last_known_position(), xeno.get_debug_state_name()])
	if xeno.get_debug_last_known_position().distance_to(heard_c) > 0.01 or xeno.get_debug_state_name() != "ALERT":
		failures.append("ALERT no recuperó una señal audible válida")

	CombatEncounterManager.reset()
	if failures.is_empty():
		print("Stage5F behavior validation: PASS (patrol, last known, arrival, recovery, Xeno persistence).")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("Stage5F behavior validation: %s" % failure)
		get_tree().quit(1)
