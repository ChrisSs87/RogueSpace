extends Node3D

## Protege el bug: un waypoint corto no es el destino final. Usa el agente y
## NavigationMap reales de DungeonSandbox; sólo invoca el helper común de
## movimiento, que es justamente la unidad de regresión.
func _ready() -> void:
	var sandbox: Node3D = $DungeonSandbox
	var enemy: Enemy = sandbox.get_node("OrcoMelee2")
	await get_tree().create_timer(0.5).timeout
	var target := Vector3(17.5, 1.0, 3.5)
	# El target queda lejano; el agente recibe una ruta real con tramos cortos.
	enemy.global_position = Vector3(12.5, 1.0, -3.5)
	var final_distance := enemy.global_position.distance_to(target)
	var arrived := enemy._move_toward_point(target, 2.0, 1.0 / 60.0)
	await get_tree().physics_frame
	var speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
	print("6A3B WAYPOINT | final=%.2f | next=%.3f | arrived=%s | velocity=%.3f | nav=%s" % [final_distance, enemy._debug_next_path_distance_m, arrived, speed, enemy._debug_nav_str])
	if final_distance > 0.3 and not arrived and speed > 0.0:
		print("Stage6A3B waypoint regression: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3B waypoint regression: FAIL")
		get_tree().quit(1)
