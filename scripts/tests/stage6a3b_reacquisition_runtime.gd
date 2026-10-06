extends Node3D

## Pipeline real: exposición, pérdida de LOS y reaparición visual. No llama
## handlers internos de Enemy ni asigna estados.
func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var enemy: Enemy = fortress.get_node("InitialMelee")
	# Mantiene el pipeline perceptivo/encounter pero evita congelar al Player
	# antes de que pueda romper LOS y volver a entrar en FOV.
	CombatEncounterManager.combat_transition_enabled = false
	await get_tree().create_timer(0.4).timeout
	player.global_position = Vector3(9.0, 1.0, -0.7)
	player.rotation.y = PI / 2.0
	await get_tree().create_timer(1.1).timeout
	player.global_position = Vector3(29.0, 1.0, 8.0) # rompe percepción
	await get_tree().create_timer(0.3).timeout
	var old_known := enemy.get_debug_last_known_position()
	var before := enemy.global_position
	# Reaparece físicamente dentro del forward real actual; no se asume una
	# coordenada fija porque la ruta puede variar legítimamente con el margen
	# de navegación, pero el caso sigue siendo FOV/LOS real.
	var forward := -enemy.global_transform.basis.z
	forward.y = 0.0
	# Evita solapar los colliders físicos de Player/Enemy: sigue dentro del
	# override de proximidad, pero no queda expulsado por move_and_slide.
	# La ruta puede cambiar la orientación física entre ticks. Durante toda la
	# ventana de reacquisition el Player se mantiene delante del forward REAL,
	# sin solapar colliders; FOV, LOS y el Timer productivo siguen decidiendo
	# si hay visión (no se llama ningún handler interno).
	for _tick in range(72):
		forward = -enemy.global_transform.basis.z
		forward.y = 0.0
		player.global_position = enemy.global_position + forward.normalized() * 1.4
		await get_tree().physics_frame
	var visual_ok := enemy.is_encounter_contact_valid() and enemy.get_debug_last_known_source() == "VISION" and enemy.get_debug_last_known_position().distance_to(player.global_position) < 0.2 and enemy.get_debug_movement_source() == "LIVE CHASE"
	var moved := enemy.global_position.distance_to(before)
	print("6A3B REACQ VISION state=%s owner=%s source=%s contact=%s old=%s new=%s moved=%.2f stalled=%s" % [enemy.get_debug_state_name(), enemy.get_debug_ai_owner(), enemy.get_debug_movement_source(), enemy.is_encounter_contact_valid(), old_known, enemy.get_debug_last_known_position(), moved, enemy.get_debug_ai_stalled()])
	# El evento público es la misma vía que Player usa para ruido; conserva la
	# coordenada situada y no consulta la posición invisible posteriormente.
	CombatEncounterManager.reset()
	CombatEncounterManager.combat_transition_enabled = true
	var sound_pos := Vector3(11.0, 1.0, 0.7)
	player.global_position = sound_pos
	EventBus.player_noise_emitted.emit(sound_pos, 5.0, 5.0)
	var sound_received := enemy.get_debug_last_known_source() == "SOUND" and enemy.get_debug_last_known_position().distance_to(sound_pos) < 0.05
	var nav_adopted := false
	var first_displacement := false
	var previous := enemy.global_position
	for tick in range(12):
		await get_tree().physics_frame
		var displacement := enemy.global_position.distance_to(previous)
		previous = enemy.global_position
		var target_ok := enemy._debug_nav_target_str.begins_with("11.0, 0.7")
		nav_adopted = nav_adopted or target_ok
		first_displacement = first_displacement or displacement > 0.001
		print("6A3B REACQ SOUND tick=%d source=%s known=%s nav=%s moved=%.3f owner=%s stalled=%s" % [tick + 1, enemy.get_debug_last_known_source(), enemy.get_debug_last_known_position(), enemy._debug_nav_target_str, displacement, enemy.get_debug_ai_owner(), enemy.get_debug_ai_stalled()])
		if nav_adopted and first_displacement: break
	var sound_ok := sound_received and nav_adopted and first_displacement and enemy.get_debug_ai_owner() == "EXPLORATION" and not enemy.get_debug_ai_stalled()
	if visual_ok and sound_ok and not enemy.get_debug_ai_stalled():
		print("Stage6A3B reacquisition runtime: PASS")
		get_tree().quit()
	else:
		push_error("Stage6A3B reacquisition runtime: FAIL")
		get_tree().quit(1)
