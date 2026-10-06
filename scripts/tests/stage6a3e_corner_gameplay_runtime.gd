extends Node3D

## Regresión de gameplay sobre la boca inferior x=9. Usa Player, Enemy,
## percepción y NavigationRegion de MainFortress6A. No inyecta CHASE/LAST
## KNOWN: la única intervención es mover físicamente/espacialmente al Player
## de prueba y presentar la exposición inicial.
func _ready() -> void:
	var mode := "chase"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--corner-mode="):
			mode = argument.trim_prefix("--corner-mode=")
	if mode not in ["chase", "last_known", "search_return"]:
		push_error("Unknown corner gameplay mode: %s" % mode)
		get_tree().quit(1)
		return
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var enemy: Enemy = fortress.get_node("InitialMelee")
	for enemy_name in ["StorageRogue", "BarracksMelee", "FinalRogue"]:
		var other: Enemy = fortress.get_node(enemy_name)
		other.perception_timer.stop()
		other.set_physics_process(false)
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = false
	await get_tree().create_timer(0.6).timeout
	# Se expone primero cerca de la boca (percepción real, sin asignar estado)
	# y luego corre al otro lado; así la ruta de CHASE atraviesa el corner sin
	# depender de una detección a distancia límite.
	player.global_position = Vector3(10.8, 1.0, -0.45)
	player.velocity = Vector3.ZERO
	var light := LightSource.new()
	light.intensity = 5
	light.radius = 6.0
	main.add_child(light)
	light.global_position = player.global_position + Vector3.UP
	# Una de las aproximaciones Android que corta la punta de pared: está
	# dentro del rango de visión Varkhen y obliga a cruzar la misma boca.
	enemy.global_position = Vector3(8.5, 1.0, -2.00)
	enemy.velocity = Vector3.ZERO
	var facing := player.global_position - enemy.global_position
	facing.y = 0.0
	enemy.look_at(enemy.global_position + facing.normalized(), Vector3.UP)
	# El Timer de percepción real adquiere desde el lateral antes de que
	# PATROL modifique el forward del setup.
	enemy.set_physics_process(false)
	await get_tree().create_timer(1.15).timeout
	enemy.set_physics_process(true)
	await get_tree().physics_frame

	var crossed := false
	var acquired := false
	var last_known_target := Vector3.INF
	var search_seen := false
	var returned_to_patrol := false
	var player_advanced := false
	var advance_tick := -1
	var recovery_at_acquisition := -1
	for tick in range(900):
		await get_tree().physics_frame
		acquired = acquired or enemy._last_known_source == "VISION" or enemy.is_encounter_contact_valid()
		if acquired and recovery_at_acquisition < 0:
			recovery_at_acquisition = enemy.get_debug_stuck_recovery_count()
		if acquired and not player_advanced:
			player.global_position = Vector3(15.0, 1.0, -0.45)
			player.velocity = Vector3.ZERO
			light.global_position = player.global_position + Vector3.UP
			player_advanced = true
			advance_tick = tick
		if mode != "chase" and advance_tick >= 0 and tick == advance_tick + 120:
			# Rompe VISION/HEARING sin emitir un evento artificial: el Enemy debe
			# conservar sólo la última posición adquirida en la boca opuesta.
			last_known_target = enemy._last_known_player_position
			player.global_position = Vector3(30.0, 1.0, 8.0)
			player.velocity = Vector3.ZERO
			light.global_position = player.global_position + Vector3.UP
		crossed = crossed or enemy.global_position.x > 9.6
		search_seen = search_seen or enemy.get_debug_movement_source() == "SEARCH"
		returned_to_patrol = returned_to_patrol or (search_seen and enemy.get_debug_state_name() == "PATROL")
		if tick % 60 == 59:
			var known_dist := enemy.global_position.distance_to(enemy._last_known_player_position) if enemy._last_known_source != "NONE" else -1.0
			print("6A3E CORNER %s t=%d state=%s source=%s contact=%s pos=(%.2f,%.2f) known_dist=%.2f crossed=%s stalled=%s recovery=%d" % [mode, tick / 60 + 1, enemy.get_debug_state_name(), enemy.get_debug_movement_source(), enemy._current_contact_kind, enemy.global_position.x, enemy.global_position.z, known_dist, crossed, enemy.get_debug_ai_stalled(), enemy.get_debug_stuck_recovery_count()])
		if mode == "chase" and crossed and tick > 180:
			break
		if mode == "last_known" and crossed and search_seen:
			break
		if mode == "search_return" and returned_to_patrol:
			break

	var no_stall := not enemy.get_debug_ai_stalled()
	# La aserción de corner comienza cuando la percepción real toma control de
	# CHASE; las recuperaciones de PATROL previas al setup no son el recorrido
	# semántico que esta regresión evalúa.
	var no_recovery := recovery_at_acquisition >= 0 and enemy.get_debug_stuck_recovery_count() == recovery_at_acquisition
	var passed := acquired and player_advanced and crossed and no_stall and no_recovery
	if mode == "last_known":
		passed = passed and last_known_target != Vector3.INF and enemy.global_position.distance_to(last_known_target) <= 0.45 and search_seen
	if mode == "search_return":
		passed = passed and search_seen and returned_to_patrol
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = true
	if passed:
		print("Stage6A3E corner gameplay %s: PASS" % mode)
		get_tree().quit()
	else:
		push_error("Stage6A3E corner gameplay %s: FAIL" % mode)
		get_tree().quit(1)
