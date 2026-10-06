extends Node3D

## Integración 6A.1b. Usa percepción visual real (timer/FOV/LOS) y el mismo
## evento público que Player.gd emite al desplazarse. No llama handlers
## internos de Enemy ni fabrica una transición de IA.


func _ready() -> void:
	var sandbox: Node3D = $DungeonSandbox
	var player := Node3D.new()
	player.name = "SensoryValidationPlayer"
	player.add_to_group("player")
	add_child(player)
	var orc: Enemy = sandbox.get_node("OrcoMelee3")
	# A queda a 1.2 m delante del Xeno: el override de proximidad conserva
	# la prueba de visión independiente de la iluminación de la sandbox.
	var visual_a := Vector3(25.8, 1.0, -3.0)
	var sound_b := Vector3(27.0, 1.0, -1.0)
	var silent_c := Vector3(40.0, 1.0, -3.0)
	player.global_position = visual_a
	orc.look_at(Vector3(visual_a.x, orc.global_position.y, visual_a.z), Vector3.UP)

	await get_tree().physics_frame
	await get_tree().physics_frame
	# A. La visión real, sostenida por el timer del Enemy, fija A.
	await get_tree().create_timer(1.15).timeout
	var failures: Array[String] = []
	var known_after_vision: Vector3 = orc.get_debug_last_known_position()
	print("MULTISENSORY vision | expected %s | known %s | source %s | debug %s" % [visual_a, known_after_vision, orc.get_debug_last_known_source(), orc.get_node("DebugStateLabel").text.replace("\n", " | ")])
	if known_after_vision.distance_to(visual_a) > 0.25 or orc.get_debug_last_known_source() != "VISION":
		failures.append("la percepción visual real no fijó LAST KNOWN en A")

	# Evita que la ventana de encuentro convierta esta prueba sensorial en
	# APPROACH; el enemigo conserva su estado/percepción real.
	CombatEncounterManager.reset()

	# B. Un muro nuevo rompe el LOS. B queda dentro del rango auditivo de 3 m
	# del Orco y representa un ruido ocurrido detrás de la esquina.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 3.0, 6.0)
	collider.shape = shape
	wall.add_child(collider)
	sandbox.add_child(wall)
	wall.global_position = Vector3(25.4, 1.5, -2.0)
	await get_tree().physics_frame
	player.global_position = sound_b
	# Este es el contrato real de Player.gd: posición/radio/intensidad del
	# instante del ruido. No se invoca _on_player_heard().
	EventBus.player_noise_emitted.emit(sound_b, 3.0, 3.0)
	await get_tree().physics_frame
	var known_after_sound: Vector3 = orc.get_debug_last_known_position()
	var distance_before_navigation: float = orc.global_position.distance_to(sound_b)
	# El muro solo representa el corte de LOS en el instante de oír B. Se
	# retira antes de comprobar navegación para no inyectar un obstáculo que
	# no existe en la NavigationMesh de la escena real.
	player.global_position = silent_c
	wall.queue_free()
	# Supera la breve memoria de contacto auditivo; desde acá CHASE debe ir al
	# punto B exacto, sin conservar el standoff de contacto actual.
	await get_tree().create_timer(0.60).timeout
	var distance_after_navigation: float = orc.global_position.distance_to(sound_b)
	print("MULTISENSORY sound | expected %s | known %s | source %s | nav %.2f -> %.2f" % [sound_b, known_after_sound, orc.get_debug_last_known_source(), distance_before_navigation, distance_after_navigation])
	if known_after_sound.distance_to(sound_b) > 0.05 or orc.get_debug_last_known_source() != "SOUND":
		failures.append("el evento auditivo no sustituyó LAST KNOWN por B")
	if distance_after_navigation >= distance_before_navigation:
		failures.append("el enemigo no navegó hacia el último ruido B")

	# C. C está fuera del oído y no se emite ningún evento: no puede aparecer
	# información mágica posterior a B.
	await get_tree().create_timer(0.50).timeout
	var known_after_silence: Vector3 = orc.get_debug_last_known_position()
	print("MULTISENSORY silence | player C %s | known %s | source %s" % [silent_c, known_after_silence, orc.get_debug_last_known_source()])
	if known_after_silence.distance_to(sound_b) > 0.05 or known_after_silence.distance_to(silent_c) < 1.0:
		failures.append("fuera de hearing el enemigo obtuvo una posición nueva")

	CombatEncounterManager.reset()
	if failures.is_empty():
		print("Stage6A1b multisensory validation: PASS (vision A -> sound B -> silence C).")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("Stage6A1b multisensory validation: %s" % failure)
		get_tree().quit(1)
