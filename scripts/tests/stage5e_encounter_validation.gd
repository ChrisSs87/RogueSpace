extends Node3D

## Prueba de integración acotada del contrato candidato/participante.
## Usa el autoload real y dobles mínimos; no altera recursos de gameplay.

class Candidate extends Node3D:
	var contact_valid: bool = true
	var joined: bool = false
	var approached: bool = false

	func refresh_encounter_contact_valid() -> bool:
		return contact_valid

	func mark_encounter_joined() -> void:
		joined = true

	func begin_combat_approach(_player: Node3D, _angle: float) -> void:
		approached = true

	func is_encounter_still_viable(_player: Node3D, _tolerance: float) -> bool:
		return contact_valid

	func is_combat_position_valid(_player: Node3D, _tolerance: float) -> bool:
		return contact_valid

	func release_encounter_candidate() -> void:
		pass


func _ready() -> void:
	var manager = CombatEncounterManager
	manager.reset()
	manager.join_window_sec = 0.05
	manager.combat_transition_enabled = true

	var player := Node3D.new()
	player.add_to_group("player")
	add_child(player)

	# Candidato que pierde todo contacto antes de lock: el encuentro se cancela.
	var lost_candidate := Candidate.new()
	add_child(lost_candidate)
	_assert(manager.request_encounter_candidate(lost_candidate) == manager.CANDIDATE_ACCEPTED, "el primer candidato debe aceptarse")
	lost_candidate.contact_valid = false
	await get_tree().create_timer(0.1).timeout
	_assert(not manager.is_encounter_active(), "un candidato sin contacto no debe iniciar combate")

	# Dos contactos independientes aún válidos dentro de la ventana: ambos
	# pasan a participantes y reciben APPROACH del manager real.
	var candidate_a := Candidate.new()
	var candidate_b := Candidate.new()
	add_child(candidate_a)
	add_child(candidate_b)
	_assert(manager.request_encounter_candidate(candidate_a) == manager.CANDIDATE_ACCEPTED, "candidato A aceptado")
	await get_tree().create_timer(0.02).timeout
	_assert(manager.request_encounter_candidate(candidate_b) == manager.CANDIDATE_ACCEPTED, "candidato B aceptado dentro de ventana")
	await get_tree().create_timer(0.1).timeout
	_assert(manager.is_encounter_active(), "dos candidatos válidos deben bloquear un encuentro")
	_assert(candidate_a.joined and candidate_b.joined and candidate_a.approached and candidate_b.approached, "ambos candidatos válidos deben convertirse en participantes")

	var late_candidate := Candidate.new()
	add_child(late_candidate)
	_assert(manager.request_encounter_candidate(late_candidate) == manager.REJECTED_CLOSED, "un candidato tardío no puede formar cola")
	manager.reset()
	print("Stage5E encounter validation: PASS (cancelación, doble válido, rechazo tardío).")
	get_tree().quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Stage5E encounter validation: %s" % message)
		get_tree().quit(1)
