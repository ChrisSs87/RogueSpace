extends Node3D
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const ORC_RESOURCE := preload("res://resources/enemies/orco_melee.tres")
class TestPlayer extends Node3D:
	var frozen := false
	func get_current_noise_radius_m() -> float: return 0.0
	func freeze_for_combat() -> void: frozen = true
func _ready() -> void:
	var sandbox: Node3D = $DungeonSandbox
	await get_tree().create_timer(0.3).timeout
	# El escenario integra dos detectores creados abajo. Desactivamos los
	# habitantes de la sandbox para que perfiles de visión futuros no roben
	# el encounter bajo prueba.
	for child in sandbox.get_children():
		if child is Enemy:
			child.set_physics_process(false)
			child.perception_timer.stop()
	var player := TestPlayer.new(); player.add_to_group("player"); add_child(player); player.global_position = Vector3(15, 1, -3); player.rotation.y = PI
	var a: Enemy = ENEMY_SCENE.instantiate(); a.enemy_resource = ORC_RESOURCE; sandbox.add_child(a); a.global_position = Vector3(13.23, 1, -1.23)
	var b: Enemy = ENEMY_SCENE.instantiate(); b.enemy_resource = ORC_RESOURCE; sandbox.add_child(b); b.global_position = Vector3(16.77, 1, -1.23)
	await get_tree().create_timer(8.0).timeout
	_report_approach("A", a, player, sandbox)
	_report_approach("B", b, player, sandbox)
	var combatants := CombatManager.get_combatant_count()
	var passed := player.frozen and combatants == 2 and a.get_debug_state_name() == "COMBAT" and b.get_debug_state_name() == "COMBAT"
	print("Stage5G double integration | frozen %s | combatants %d | A %s | B %s" % [player.frozen, combatants, a.get_debug_state_name(), b.get_debug_state_name()])
	CombatEncounterManager.reset()
	if passed: print("Stage5G double integration: PASS"); get_tree().quit(0)
	else: push_error("Stage5G double: no combat real con dos detectores"); get_tree().quit(1)

func _report_approach(label: String, enemy: Enemy, player: Node3D, sandbox: Node3D) -> void:
	var map := sandbox.get_world_3d().get_navigation_map()
	var slot: Vector3 = enemy._compute_slot_target_position()
	var projected := NavigationServer3D.map_get_closest_point(map, slot)
	var path := NavigationServer3D.map_get_path(map, enemy.global_position, projected, true)
	var path_distance := 0.0
	for i in range(1, path.size()): path_distance += path[i - 1].distance_to(path[i])
	print("SLOT %s | player %s | enemy %s | angle %.1f | requested %s | projected %s | projection delta %.2f | reachable %s | path %s | points %d | path distance %.2f | remaining %.2f | combat distance %.2f | state %s" % [label, player.global_position, enemy.global_position, enemy._combat_slot_angle_deg, slot, projected, slot.distance_to(projected), enemy.navigation_agent.is_target_reachable(), path, path.size(), path_distance, enemy.global_position.distance_to(projected), enemy.global_position.distance_to(player.global_position), enemy.get_debug_state_name()])
