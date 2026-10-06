extends Node3D

const BakeUtil = preload("res://scripts/tests/navigation_bake_test_util.gd")

## CHASE real con percepción: no fuerza estados ni destinos internos.
func _ready() -> void:
	var main := $MainFortress6A as Node3D
	var fortress := main.get_node("Fortress6A") as Node3D
	var player := main.get_node("Player") as CharacterBody3D
	var enemy := fortress.get_node("InitialMelee") as Enemy
	await BakeUtil.activate_bc_only(fortress, &"test_bc_height_chase_source")
	BakeUtil.align_agent_to_navigation_plane(enemy)
	CombatEncounterManager.combat_transition_enabled = false
	player.global_position = Vector3(6.0, 1.0, -0.7)
	player.velocity = Vector3.ZERO
	var initial_distance := enemy.global_position.distance_to(player.global_position)
	var minimum_distance := initial_distance
	var saw_live_pursuit := false
	var stalled := false
	for second in range(5):
		await get_tree().create_timer(1.0).timeout
		var distance := enemy.global_position.distance_to(player.global_position)
		minimum_distance = minf(minimum_distance, distance)
		saw_live_pursuit = saw_live_pursuit or enemy.get_debug_movement_source() == "LIVE CHASE"
		# Dentro de la banda de combate, CHASE puede detenerse legítimamente a
		# la espera de Encounter. Sólo se considera stall mientras aún debe
		# cerrar distancia.
		if distance > CombatEncounterManager.combat_max_distance_m + 0.2:
			stalled = stalled or enemy.get_debug_ai_stalled()
		print("BC_HEIGHT CHASE t=%d state=%s source=%s contact=%s dist=%.3f velocity=%.3f stalled=%s" % [second + 1, enemy.get_debug_state_name(), enemy.get_debug_movement_source(), enemy._current_contact_kind, distance, Vector2(enemy.velocity.x, enemy.velocity.z).length(), enemy.get_debug_ai_stalled()])
		if second == 1:
			# Mantiene una separación real para observar una segunda fase de
			# persecución, sin alterar estados ni destinos internos.
			player.global_position = Vector3(1.0, 1.0, -0.7)
		var stop_distance := enemy.enemy_resource.combat_distance_tiles * GameBalance.tile_size_m
		if second >= 2 and distance <= stop_distance + 0.05:
			break
	CombatEncounterManager.combat_transition_enabled = true
	var passed := saw_live_pursuit and minimum_distance < initial_distance - 0.5 and not stalled and enemy.get_debug_stuck_recovery_count() == 0
	if passed:
		print("Stage6A B+C height CHASE: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A B+C height CHASE: FAIL")
		get_tree().quit(1)
