extends Node3D

## Flujo real: percepción por Timer/FOV/LOS, apertura de ventana y escape.
## No invoca handlers internos ni registra candidatos directamente.
class TestPlayer extends Node3D:
	var frozen := false
	func get_current_noise_radius_m() -> float: return 0.0
	func freeze_for_combat() -> void: frozen = true

func _ready() -> void:
	var sandbox: Node3D = $DungeonSandbox
	await get_tree().create_timer(0.3).timeout
	var player := TestPlayer.new()
	player.add_to_group("player")
	add_child(player)
	var orc: Enemy = sandbox.get_node("OrcoMelee1")
	var forward := -orc.global_transform.basis.z
	player.global_position = orc.global_position + Vector3(forward.x, 0.0, forward.z).normalized()
	await get_tree().create_timer(1.4).timeout
	if orc.get_debug_state_name() != "CHASE":
		push_error("Stage5G escape: el orco no detectó por percepción real")
		get_tree().quit(1)
		return
	player.global_position = Vector3(100.0, 1.0, 0.0)
	await get_tree().create_timer(2.5).timeout
	var passed := not CombatEncounterManager.is_encounter_active() and not player.frozen
	print("Stage5G escape integration | state %s | encounter active %s | player frozen %s" % [orc.get_debug_state_name(), CombatEncounterManager.is_encounter_active(), player.frozen])
	CombatEncounterManager.reset()
	if passed:
		print("Stage5G escape integration: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage5G escape: comenzó combate/encuentro tras perder contacto")
		get_tree().quit(1)
