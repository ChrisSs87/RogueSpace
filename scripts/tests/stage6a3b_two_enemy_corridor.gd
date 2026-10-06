extends Node3D

## Dos enemigos reales de Fortress6A reciben información independiente; el
## test sólo mueve al Player y observa la IA pública/debug.
func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var a: Enemy = fortress.get_node("InitialMelee")
	var b: Enemy = fortress.get_node("StorageRogue")
	CombatEncounterManager.combat_transition_enabled = false
	await get_tree().create_timer(0.4).timeout
	player.global_position = Vector3(9, 1, -0.7) # exposición A
	player.rotation.y = PI / 2.0
	await get_tree().create_timer(1.1).timeout
	var known_a := a.get_debug_last_known_position()
	var b_forward := -b.global_transform.basis.z
	b_forward.y = 0.0
	player.global_position = b.global_position + b_forward.normalized() * 0.4 # exposición B real
	await get_tree().create_timer(1.1).timeout
	var known_b := b.get_debug_last_known_position()
	player.global_position = Vector3(45, 1, 0) # rompe LOS/audición
	var moved_a := false
	var moved_b := false
	var stalled := false
	for second in range(5):
		var pa := a.global_position; var pb := b.global_position
		await get_tree().create_timer(1.0).timeout
		var da := a.global_position.distance_to(pa); var db := b.global_position.distance_to(pb)
		moved_a = moved_a or da > 0.05
		moved_b = moved_b or db > 0.05
		stalled = stalled or a.get_debug_ai_stalled() or b.get_debug_ai_stalled()
		print("6A3B CORRIDOR t=%d | A state=%s owner=%s source=%s known=%s dist=%.2f nav=%s move=%.2f enc=%s stalled=%s | B state=%s owner=%s source=%s known=%s dist=%.2f nav=%s move=%.2f enc=%s stalled=%s" % [second + 1, a.get_debug_state_name(), a.get_debug_ai_owner(), a.get_debug_movement_source(), a.get_debug_last_known_position(), a.global_position.distance_to(a.get_debug_last_known_position()), a._debug_nav_target_str, da, a.get_debug_encounter_state(), a.get_debug_ai_stalled(), b.get_debug_state_name(), b.get_debug_ai_owner(), b.get_debug_movement_source(), b.get_debug_last_known_position(), b.global_position.distance_to(b.get_debug_last_known_position()), b._debug_nav_target_str, db, b.get_debug_encounter_state(), b.get_debug_ai_stalled()])
	# Reacquisition real de A.
	player.global_position = a.global_position - a.global_transform.basis.z.normalized() * 0.4
	await get_tree().create_timer(0.5).timeout
	var reacquired := a.is_encounter_contact_valid() and a.get_debug_last_known_source() == "VISION"
	var b_detected := b.get_debug_last_known_source() != "NONE"
	var independent := b_detected and known_a.distance_to(known_b) > 1.0
	var positioning_clean := not a.get_debug_has_combat_positioning() and not b.get_debug_has_combat_positioning()
	CombatEncounterManager.reset(); CombatEncounterManager.combat_transition_enabled = true
	if independent and moved_a and moved_b and reacquired and positioning_clean and not stalled:
		print("Stage6A3B two enemy corridor: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3B two enemy corridor: FAIL")
		get_tree().quit(1)
