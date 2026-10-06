extends Node3D

## Integración de la ruta segura de fallback de APPROACH. El obstáculo se
## agrega sólo después de que ambos orcos ya fueron admitidos al MISMO
## encuentro y ambos recibieron APPROACH por las rutas reales de percepción.
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const ORC_RESOURCE := preload("res://resources/enemies/orco_melee.tres")


class TestPlayer extends Node3D:
	var frozen := false
	func get_current_noise_radius_m() -> float: return 0.0
	func freeze_for_combat() -> void: frozen = true


func _ready() -> void:
	var sandbox: Node3D = $DungeonSandbox
	await get_tree().create_timer(0.3).timeout
	# Aísla los dos actores de este escenario; los habitantes reales de la
	# sandbox pueden tener perfiles perceptivos distintos según la etapa.
	for child in sandbox.get_children():
		if child is Enemy:
			child.set_physics_process(false)
			child.perception_timer.stop()
	var player := TestPlayer.new()
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector3(15, 1, -3)
	player.rotation.y = PI

	# Mismo punto de partida que el double integration que ya obtiene dos
	# detecciones reales dentro de la ventana de unión.
	var a: Enemy = ENEMY_SCENE.instantiate()
	a.enemy_resource = ORC_RESOURCE
	sandbox.add_child(a)
	a.global_position = Vector3(13.23, 1, -1.23)
	var b: Enemy = ENEMY_SCENE.instantiate()
	b.enemy_resource = ORC_RESOURCE
	sandbox.add_child(b)
	b.global_position = Vector3(16.77, 1, -1.23)

	if not await _wait_for_two_candidates(a, b, 5.0):
		_fail("Fase A: A y B no fueron candidatos del mismo encuentro")
		return
	print("Stage5G drop phase A | participants %d | A/B accepted" % CombatEncounterManager.get_debug_pending_count())

	# Los dos candidatos ya quedaron aceptados. Se los ubica en dos carriles
	# abiertos, apenas fuera de la banda READY, para poder observar el estado
	# APPROACH de ambos antes de introducir el obstáculo exclusivo de B.
	a.global_position = Vector3(12.6, 1, -0.8)
	b.global_position = Vector3(17.4, 1, -0.8)
	a.look_at(Vector3(player.global_position.x, a.global_position.y, player.global_position.z), Vector3.UP)
	b.look_at(Vector3(player.global_position.x, b.global_position.y, player.global_position.z), Vector3.UP)
	# Congelación exclusiva del harness durante el resto de la join window:
	# evita que CHASE los lleve a la banda READY antes de que el test pueda
	# observar el lock. El manager conserva y valida la percepción real.
	a.set_physics_process(false)
	b.set_physics_process(false)

	if not await _wait_for_both_approaching(a, b, 3.0):
		print("Stage5G drop phase B diagnostic | pending %d | A %s/%s contact %s | B %s/%s contact %s" % [CombatEncounterManager.get_debug_pending_count(), a.get_debug_state_name(), a._encounter_debug_state, a._encounter_contact_valid, b.get_debug_state_name(), b._encounter_debug_state, b._encounter_contact_valid])
		_fail("Fase B: A y B no alcanzaron APPROACH después del lock normal")
		return
	print("Stage5G drop phase B | A APPROACH | B APPROACH")

	# Fase C: recién ahora B es movido a un carril navegable de prueba y se
	# levanta una jaula BAJA. Las paredes bloquean su CharacterBody3D, pero no
	# el rayo de visión (eye=2.5 m / target=2.0 m), por lo que la imposibilidad
	# es física de APPROACH, no un rechazo previo de percepción.
	_add_low_approach_cage(sandbox, b.global_position)
	a.set_physics_process(true)
	b.set_physics_process(true)

	var dropped_seen := await _wait_for_drop_or_combat(b, 12.0)
	var combatants := CombatManager.get_combatant_count()
	var b_in_current_combat := false
	for index in combatants:
		if CombatManager.get_combatant_node(index) == b:
			b_in_current_combat = true
	var passed := dropped_seen and player.frozen and a.get_debug_state_name() == "COMBAT" and combatants == 1 and not b_in_current_combat
	print("Stage5G drop result | A %s | B %s/%s | dropped seen %s | frozen %s | combatants %d | B in combat %s" % [a.get_debug_state_name(), b.get_debug_state_name(), b._encounter_debug_state, dropped_seen, player.frozen, combatants, b_in_current_combat])
	# 6A.3b: DROP no puede retener ownership/slot. El sonido utiliza la vía
	# pública real de Player y B sigue siendo IA de exploración.
	var drop_cleanup_ok := b.get_debug_ai_owner() == "EXPLORATION" and b.get_debug_movement_source() != "COMBAT POSITIONING" and not b.get_debug_has_combat_positioning()
	var sound_position := b.global_position + Vector3(1.0, 0.0, 0.0)
	EventBus.player_noise_emitted.emit(sound_position, 5.0, 5.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sound_recovery_ok := b.get_debug_last_known_source() == "SOUND" and b.get_debug_ai_owner() == "EXPLORATION" and not b.get_debug_ai_stalled()
	print("Stage6A3B dropped recovery | owner %s | source %s | positioning %s | sound %s | nav %s" % [b.get_debug_ai_owner(), b.get_debug_movement_source(), b.get_debug_has_combat_positioning(), b.get_debug_last_known_source(), b._debug_nav_target_str])
	passed = passed and drop_cleanup_ok and sound_recovery_ok

	# B ya fue retirado del encuentro bloqueado y no se agrega al combate
	# actual. Al resetear el manager no puede aparecer una cola automática:
	# tendría que volver a detectar y solicitar un encuentro desde cero.
	CombatEncounterManager.reset()
	for cage_wall in get_tree().get_nodes_in_group("stage5g_drop_cage"):
		cage_wall.queue_free()
	await get_tree().create_timer(0.5).timeout
	var no_followup_queue := CombatEncounterManager.get_debug_pending_count() == 0 and CombatManager.get_combatant_count() == 1
	# B debe perder contacto antes de recuperar elegibilidad; así no existe
	# requeue automático, pero tampoco un bloqueo permanente tras DROPPED.
	player.global_position = Vector3(100.0, 1.0, 0.0)
	await get_tree().create_timer(0.6).timeout
	var lost_contact := not b.is_encounter_contact_valid()
	var b_forward := -b.global_transform.basis.z
	b_forward.y = 0.0
	# 0.4 m superpone el CharacterBody del Player con la cápsula 0.4 m de B:
	# la física puede expulsarlo antes del tick perceptivo y convertir la
	# comprobación de reingreso en un falso FOV:NO. 1.4 m sigue dentro del
	# proximity override real (1.5 m) sin solapar cuerpos.
	player.global_position = b.global_position + b_forward.normalized() * 1.4
	await get_tree().create_timer(1.3).timeout
	var future_eligible := b._has_requested_encounter and CombatEncounterManager.get_debug_pending_count() > 0
	print("Stage6A3B future encounter | lost %s | B requested %s | pending %d | state %s | contact %s | fov %s los %s | excluded %s wait_loss %s join_closed %s" % [lost_contact, b._has_requested_encounter, CombatEncounterManager.get_debug_pending_count(), b.get_debug_state_name(), b.is_encounter_contact_valid(), b._debug_fov_str, b._debug_los_str, b._excluded_from_active_encounter, b._must_lose_contact_before_reentry, b._encounter_join_closed])
	passed = passed and no_followup_queue and lost_contact and future_eligible
	if passed:
		print("Stage5G drop integration: PASS (A solo; B dropped sin cola posterior)")
		get_tree().quit(0)
	else:
		_fail("B no recorrió DROPPED o no se inició exactamente el combate individual de A")


func _wait_for_two_candidates(a: Enemy, b: Enemy, timeout_sec: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		var pending: Array = CombatEncounterManager._pending_enemies
		if CombatEncounterManager.get_debug_pending_count() == 2 and a in pending and b in pending and a._has_requested_encounter and b._has_requested_encounter:
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return false


func _wait_for_both_approaching(a: Enemy, b: Enemy, timeout_sec: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if a.get_debug_state_name() == "APPROACH" and b.get_debug_state_name() == "APPROACH":
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return false


func _wait_for_drop_or_combat(b: Enemy, timeout_sec: float) -> bool:
	var elapsed := 0.0
	var dropped_seen := false
	while elapsed < timeout_sec:
		# DROPPED es una transición, no un estado terminal exigido al final.
		dropped_seen = dropped_seen or b._encounter_debug_state == "DROPPED"
		if dropped_seen and CombatManager.get_combatant_count() > 0:
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return dropped_seen


func _add_low_approach_cage(parent: Node3D, center: Vector3) -> void:
	# Interior de 1.3 m: B cabe, pero su cápsula de radio 0.4 m no puede salir.
	# Las paredes llegan sólo a 0.8 m de alto para conservar LOS real sobre ellas.
	var half_extent := 0.65
	var thickness := 0.18
	for offset_and_size in [
		[Vector3(half_extent, 0.4, 0), Vector3(thickness, 0.8, 1.66)],
		[Vector3(-half_extent, 0.4, 0), Vector3(thickness, 0.8, 1.66)],
		[Vector3(0, 0.4, half_extent), Vector3(1.66, 0.8, thickness)],
		[Vector3(0, 0.4, -half_extent), Vector3(1.66, 0.8, thickness)],
	]:
		var wall := StaticBody3D.new()
		wall.add_to_group("stage5g_drop_cage")
		parent.add_child(wall)
		wall.global_position = center + offset_and_size[0]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = offset_and_size[1]
		shape.shape = box
		wall.add_child(shape)


func _fail(message: String) -> void:
	push_error("Stage5G drop: %s" % message)
	CombatEncounterManager.reset()
	get_tree().quit(1)
