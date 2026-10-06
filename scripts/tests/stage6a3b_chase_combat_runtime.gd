extends Node3D

const BakeUtil = preload("res://scripts/tests/navigation_bake_test_util.gd")

## Integración sobre la misma MainFortress6A del paquete móvil. Sólo mueve
## al Player real a una posición de exposición: no fuerza estados de Enemy.
func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var enemy: Enemy = fortress.get_node("InitialMelee")
	if "--nav-bc-height" in OS.get_cmdline_user_args():
		await BakeUtil.activate_bc_only(fortress, &"test_bc_chase_source")
		BakeUtil.align_agent_to_navigation_plane(enemy)
	await get_tree().create_timer(0.5).timeout
	player.global_position = Vector3(9.0, 1.0, -0.7)
	player.rotation.y = PI / 2.0
	player.velocity = Vector3.ZERO
	var combat_seen := false
	for second in range(8):
		await get_tree().create_timer(1.0).timeout
		var distance := enemy.global_position.distance_to(player.global_position)
		print("6A3B CHASE_COMBAT t=%d state=%s owner=%s source=%s contact=%s encounter=%s dist=%.2f velocity=%.2f stalled=%s slot_world=%s slot_nav=%s slot_xz=%.3f slot_y=%.3f slot_valid=%s" % [second + 1, enemy.get_debug_state_name(), enemy.get_debug_ai_owner(), enemy.get_debug_movement_source(), enemy.is_encounter_contact_valid(), enemy._encounter_debug_state, distance, Vector2(enemy.velocity.x, enemy.velocity.z).length(), enemy.get_debug_ai_stalled(), enemy._debug_combat_slot_world, enemy._debug_combat_slot_navigation, enemy._debug_combat_slot_lateral_error_m, enemy._debug_combat_slot_vertical_error_m, enemy._debug_combat_slot_valid])
		combat_seen = combat_seen or CombatManager.get_combatant_count() == 1
		if combat_seen:
			break
	var passed := combat_seen and enemy.get_debug_state_name() == "COMBAT" and enemy.get_debug_ai_owner() == "COMBAT"
	CombatEncounterManager.reset()
	if passed:
		print("Stage6A3B chase -> combat runtime: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3B chase -> combat runtime: FAIL")
		get_tree().quit(1)
