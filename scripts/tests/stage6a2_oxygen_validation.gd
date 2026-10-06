extends Node3D

## Validación de integración 6A.2: usa MainFortress6A real y verifica la
## fuente única RunState, movimiento real del Player, evento real de combate
## y el pickup de la escena.


func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: Node3D = main.get_node("Player")
	var failures: Array[String] = []
	RunState.reset_run()
	await get_tree().physics_frame

	# A/B. Inicial y quieto: caída vertical no cuenta como exploración.
	var initial_o2 := RunState.oxygen_current
	await get_tree().create_timer(0.35).timeout
	print("O2 initial/idle | %.2f -> %.2f | distance %.3f" % [initial_o2, RunState.oxygen_current, RunState.exploration_distance_travelled_m])
	if not is_equal_approx(initial_o2, 100.0):
		failures.append("O2 inicial no es 100")
	if not is_equal_approx(RunState.oxygen_current, initial_o2):
		failures.append("el Player quieto consumió O2")

	# C. Input real durante medio segundo; el gasto se compara con la distancia
	# horizontal que Player reportó luego de move_and_slide().
	Input.action_press("move_forward")
	await get_tree().create_timer(0.50).timeout
	Input.action_release("move_forward")
	await get_tree().physics_frame
	var travelled := RunState.exploration_distance_travelled_m
	var expected_move_cost := travelled * GameBalance.oxygen_cost_per_meter
	print("O2 movement | distance %.3f | cost %.3f | expected %.3f" % [travelled, RunState.oxygen_movement_spent, expected_move_cost])
	if travelled <= 0.10 or absf(RunState.oxygen_movement_spent - expected_move_cost) > 0.02:
		failures.append("el coste de movimiento no coincide con distancia real")

	# D. El evento de COMBAT real es el único punto de coste. Un enemigo.
	RunState.reset_oxygen()
	var enemy_a: Enemy = fortress.get_node("InitialMelee")
	EventBus.combat_ready.emit(player, [enemy_a])
	await get_tree().physics_frame
	print("O2 single combat | cost %.2f | current %.2f" % [RunState.oxygen_combat_spent, RunState.oxygen_current])
	if not is_equal_approx(RunState.oxygen_combat_spent, GameBalance.normal_combat_oxygen_cost):
		failures.append("combate individual no consumió 3 una sola vez")
	CombatManager.reset_after_defeat()
	player.call("unfreeze_after_combat")

	# E. Dos combatientes siguen siendo un solo encuentro/evento.
	RunState.reset_oxygen()
	var enemy_b: Enemy = fortress.get_node("StorageRogue")
	EventBus.combat_ready.emit(player, [enemy_a, enemy_b])
	await get_tree().physics_frame
	print("O2 double combat | cost %.2f | current %.2f" % [RunState.oxygen_combat_spent, RunState.oxygen_current])
	if not is_equal_approx(RunState.oxygen_combat_spent, GameBalance.normal_combat_oxygen_cost):
		failures.append("combate doble consumió más de una vez")
	CombatManager.reset_after_defeat()
	player.call("unfreeze_after_combat")

	# F. Sin EventBus.combat_ready (escape antes de COMBAT), coste de combate 0.
	RunState.reset_oxygen()
	await get_tree().create_timer(0.15).timeout
	if not is_zero_approx(RunState.oxygen_combat_spent):
		failures.append("escape sin COMBAT consumió O2 de combate")

	# G/H. Cache real de la rama opcional: restaura hasta máximo y desaparece.
	RunState.consume_oxygen(15.0)
	var cache: Area3D = fortress.get_node("StorageOxygenCache")
	player.global_position = cache.global_position
	player.set("velocity", Vector3.ZERO)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("O2 cache | current %.2f | cache valid %s" % [RunState.oxygen_current, is_instance_valid(cache)])
	if not is_equal_approx(RunState.oxygen_current, 95.0):
		failures.append("cache no restauró +10 hasta máximo")
	if is_instance_valid(cache):
		failures.append("cache pudo quedar disponible tras primer uso")

	# I. Reset de run restituye O2 y telemetría a cero. La escena real se
	# reconstruye con el botón de WellTrigger; el cache es una instancia nueva
	# en cada carga, no estado persistente.
	RunState.reset_run()
	print("O2 reset | current %.2f | distance %.2f | move %.2f | combat %.2f" % [RunState.oxygen_current, RunState.exploration_distance_travelled_m, RunState.oxygen_movement_spent, RunState.oxygen_combat_spent])
	if not is_equal_approx(RunState.oxygen_current, RunState.oxygen_max) or not is_zero_approx(RunState.exploration_distance_travelled_m) or not is_zero_approx(RunState.oxygen_movement_spent) or not is_zero_approx(RunState.oxygen_combat_spent):
		failures.append("reset no restauró estado de O2")

	if failures.is_empty():
		print("Stage6A2 oxygen validation: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("Stage6A2 oxygen validation: %s" % failure)
		get_tree().quit(1)
