extends Node3D

## Validación de integración del primer piso: instancia exactamente la escena
## jugable, con Player real, sin alterar recursos ni métodos internos de IA.
const ENEMIES: Array[String] = ["InitialMelee", "StorageRogue", "BarracksMelee", "FinalRogue"]


func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: Node3D = main.get_node("Player")
	# Fortress6A now bakes its sole navigation map at runtime.  Route checks
	# must wait for that map instead of sampling the empty map that exists on
	# the first two physics frames.
	var bake_ready := false
	for _frame in 300:
		await get_tree().physics_frame
		if fortress.has_method("is_navigation_bake_ready") and fortress.is_navigation_bake_ready():
			bake_ready = true
			break
	if not bake_ready:
		push_error("Fortress6A validation: bake B+C no quedó listo")
		get_tree().quit(1)
		return
	await get_tree().process_frame

	var failures: Array[String] = []
	# A. Spawn seguro: sin percepción inicial y sin encuentro pendiente.
	for enemy_name in ENEMIES:
		var enemy: Enemy = fortress.get_node(enemy_name)
		if enemy.is_encounter_contact_valid():
			failures.append("spawn inseguro: %s percibe al Player" % enemy_name)
	print("Fortress6A spawn-safe | pending %d | player %s" % [CombatEncounterManager.get_debug_pending_count(), player.global_position])
	if CombatEncounterManager.get_debug_pending_count() != 0:
		failures.append("spawn inseguro: encounter pendiente")

	# B/C. Conectividad de la malla única y rutas A/B de patrulla.
	var map: RID = fortress.get_world_3d().get_navigation_map()
	var well: Vector3 = fortress.get_node("WellTrigger").global_position
	var spawn_path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, player.global_position), NavigationServer3D.map_get_closest_point(map, well), true)
	print("Fortress6A connectivity | spawn->well points %d" % spawn_path.size())
	if spawn_path.size() < 2:
		failures.append("sin ruta spawn -> pozo")
	for enemy_name in ENEMIES:
		var enemy: Enemy = fortress.get_node(enemy_name)
		var point_a: Node3D = enemy.get_node(enemy.patrol_points[0])
		var point_b: Node3D = enemy.get_node(enemy.patrol_points[1])
		var patrol_path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, point_a.global_position), NavigationServer3D.map_get_closest_point(map, point_b.global_position), true)
		print("Fortress6A patrol route %s | points %d" % [enemy_name, patrol_path.size()])
		if patrol_path.size() < 2:
			failures.append("sin ruta de patrulla: %s" % enemy_name)

	# D. Diez segundos de ejecución real, sin mover enemigos ni desactivar
	# percepción. Todos deben recorrer una distancia significativa.
	var samples: Dictionary = {}
	for enemy_name in ENEMIES:
		samples[enemy_name] = [(fortress.get_node(enemy_name) as Enemy).global_position]
	for second in range(10):
		await get_tree().create_timer(1.0).timeout
		for enemy_name in ENEMIES:
			samples[enemy_name].append((fortress.get_node(enemy_name) as Enemy).global_position)
	for enemy_name in ENEMIES:
		var enemy: Enemy = fortress.get_node(enemy_name)
		var travelled := 0.0
		for index in range(1, samples[enemy_name].size()):
			travelled += samples[enemy_name][index - 1].distance_to(samples[enemy_name][index])
		print("Fortress6A runtime patrol %s | %.2f m total | %s | %s" % [enemy_name, travelled, enemy.get_debug_state_name(), enemy.get_patrol_runtime_debug()])
		if travelled < 0.5:
			failures.append("patrulla sin movimiento: %s" % enemy_name)

	# E. El trigger se prueba a través del Area3D real y el Player de escena.
	player.global_position = well
	player.velocity = Vector3.ZERO
	player.force_update_transform()
	fortress.get_node("WellTrigger").force_update_transform()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var end_panel: CanvasLayer = fortress.get_node("FortressEndUI")
	print("Fortress6A end trigger | player %s | overlaps %s | activated %s | panel %s" % [player.global_position, fortress.get_node("WellTrigger").get_overlapping_bodies(), fortress.get_node("WellTrigger").activated, end_panel.visible])
	if not fortress.get_node("WellTrigger").activated or not end_panel.visible:
		failures.append("trigger final no se activó")

	CombatEncounterManager.reset()
	if failures.is_empty():
		print("Fortress6A validation: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("Fortress6A validation: %s" % failure)
		get_tree().quit(1)
