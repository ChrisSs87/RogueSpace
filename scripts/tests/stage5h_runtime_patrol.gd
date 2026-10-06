extends Node3D

## Prueba de runtime 5H. Instancia MainSandbox sin modificar su NavigationMap,
## sus enemigos, su Player ni sus timers: es el mismo árbol que abre Android.
const PATROLLERS: Array[String] = ["OrcoMelee1", "OrcoMelee2", "OrcoPicaro1", "OrcoMelee3", "OrcoPicaro2"]


func _ready() -> void:
	var sandbox: Node3D = $MainSandbox/DungeonSandbox
	# Sincronización normal; no se toca NavigationServer ni se reposiciona nada.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var samples: Dictionary = {}
	var indices: Dictionary = {}
	var states: Dictionary = {}
	var max_stalls: Dictionary = {}
	for enemy_name in PATROLLERS:
		samples[enemy_name] = []
		indices[enemy_name] = []
		states[enemy_name] = []
		max_stalls[enemy_name] = 0.0

	for second in range(11):
		for enemy_name in PATROLLERS:
			var enemy: Enemy = sandbox.get_node(enemy_name)
			var runtime: Dictionary = enemy.get_patrol_runtime_debug()
			samples[enemy_name].append(enemy.global_position)
			indices[enemy_name].append(runtime["patrol_index"])
			states[enemy_name].append(enemy.get_debug_state_name())
			max_stalls[enemy_name] = maxf(max_stalls[enemy_name], runtime["stall_elapsed_sec"])
		if second < 10:
			await get_tree().create_timer(1.0).timeout

	var report_lines: Array[String] = ["Stage5H DungeonSandbox runtime patrol report", "Enemy | t0 | t1 | t2 | t3 | t4 | t5 | t6 | t7 | t8 | t9 | t10 | total | index changed | max stall | states"]
	var failures: Array[String] = []
	for enemy_name in PATROLLERS:
		var enemy: Enemy = sandbox.get_node(enemy_name)
		var positions: Array = samples[enemy_name]
		var total_distance := 0.0
		for index in range(1, positions.size()):
			total_distance += positions[index - 1].distance_to(positions[index])
		var index_changed := false
		for index in range(1, indices[enemy_name].size()):
			index_changed = index_changed or indices[enemy_name][index] != indices[enemy_name][index - 1]
		var formatted_positions: Array[String] = []
		for position in positions:
			formatted_positions.append("(%.2f,%.2f)" % [position.x, position.z])
		var patrol_samples: int = 0
		for state_name in states[enemy_name]:
			if state_name == "PATROL":
				patrol_samples += 1
		var line := "%s | %s | %.2f | %s | %.2f | %s" % [enemy_name, " | ".join(formatted_positions), total_distance, index_changed, max_stalls[enemy_name], ",".join(states[enemy_name])]
		report_lines.append(line)
		if total_distance < 0.5 and patrol_samples >= 3:
			failures.append("%s no se desplazó en MainSandbox" % enemy_name)
		# Si el Player real hace que el orco abandone PATROL antes de completar
		# un tramo, no se le exige alternar A/B. Eso es una diferencia válida
		# respecto del test viejo, que no tenía Player durante los 5 segundos.
		if not index_changed and patrol_samples >= 9:
			failures.append("%s no cambió patrol_index en 10 s" % enemy_name)
		if max_stalls[enemy_name] > 2.0:
			failures.append("%s quedó PATROL STALLED %.2f s" % [enemy_name, max_stalls[enemy_name]])
		print("RUNTIME PATROL %s | total %.2f m | index changed %s | patrol samples %d | max stall %.2f | final %s" % [enemy_name, total_distance, index_changed, patrol_samples, max_stalls[enemy_name], enemy.get_patrol_runtime_debug()])

	var report := "\n".join(report_lines)
	print(report)
	var output := FileAccess.open("user://patrol_runtime_report.txt", FileAccess.WRITE)
	if output != null:
		output.store_string(report + "\n")
		output.close()
		print("Stage5H runtime report: user://patrol_runtime_report.txt")
	else:
		push_warning("Stage5H: no se pudo escribir patrol_runtime_report.txt")

	if failures.is_empty():
		print("Stage5H DungeonSandbox runtime patrol: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("Stage5H runtime patrol: %s" % failure)
		get_tree().quit(1)
