extends Node3D

const BakeUtil = preload("res://scripts/tests/navigation_bake_test_util.gd")

## Verifica la separación world/nav en slots sin forzar estados de IA.
func _ready() -> void:
	var main := $MainFortress6A as Node3D
	var fortress := main.get_node("Fortress6A") as Node3D
	var player := main.get_node("Player") as CharacterBody3D
	var enemy := fortress.get_node("InitialMelee") as Enemy
	await BakeUtil.activate_bc_only(fortress, &"test_bc_slot_source")
	BakeUtil.align_agent_to_navigation_plane(enemy)
	# Slot válido: mismo que el caso runtime, físicamente libre y a 2.5 m.
	player.global_position = Vector3(9.0, enemy.global_position.y, -0.7)
	enemy.global_position = Vector3(12.0, enemy.global_position.y, -0.7)
	var valid_world := Vector3(6.5, enemy.global_position.y, -0.7)
	var valid := enemy._is_valid_combat_slot(valid_world, player.global_position)
	print("BC_SLOT valid accepted=%s world=%s nav=%s xz=%.3f y=%.3f" % [valid, enemy._debug_combat_slot_world, enemy._debug_combat_slot_navigation, enemy._debug_combat_slot_lateral_error_m, enemy._debug_combat_slot_vertical_error_m])
	# Dentro de W02: la proyección debe tener salto lateral y ser rechazada.
	player.global_position = Vector3(4.0, enemy.global_position.y, 1.5)
	var invalid_world := Vector3(4.0, enemy.global_position.y, 4.0)
	var invalid := enemy._is_valid_combat_slot(invalid_world, player.global_position)
	print("BC_SLOT wall accepted=%s world=%s nav=%s xz=%.3f y=%.3f" % [invalid, enemy._debug_combat_slot_world, enemy._debug_combat_slot_navigation, enemy._debug_combat_slot_lateral_error_m, enemy._debug_combat_slot_vertical_error_m])
	if valid and not invalid:
		print("Stage6A B+C slot projection: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A B+C slot projection: FAIL")
		get_tree().quit(1)
