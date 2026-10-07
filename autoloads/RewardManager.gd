extends Node

## RewardManager.gd (autoload)
## Resuelve la secuencia de recompensa post-combate. Se llama recién cuando
## el combate terminó DEL TODO (todos los enemigos murieron) — nunca antes,
## y con la lista completa de especies derrotadas. Cada enemigo tira su
## propio ADN por separado (misma especie que él, nunca otra); el objeto de
## recuperación se tira una sola vez por encuentro.
##
## Flujo (cada paso es un "_step" distinto, ver constantes STEP_*):
##   RESUMEN -> (ADN_ELECCIÓN -> ADN_RESULTADO -> [CARTA_DESBLOQUEADA ->
##   [CARTA_REEMPLAZO]])* -> [KIT_OFERTA -> KIT_RESULTADO] -> FIN
##
## RewardUI solo LEE el estado de acá (get_step(), get_summary_lines(),
## get_current_species(), get_last_message(), get_unlocked_card_*(),
## get_replaceable_cards()) y llama a los métodos de acción
## (acknowledge_summary/choose_dna_slot/acknowledge_message/
## incorporate_unlocked_card/leave_unlocked_card_out/choose_card_to_replace/
## use_first_aid_kit/decline_first_aid_kit) — ninguna regla de recompensa
## vive en la UI.
##
## El jugador sigue congelado (lo dejó CombatManager) hasta que la
## secuencia termina — recién ahí se llama a unfreeze_after_combat().

signal reward_sequence_started
signal reward_step_changed
signal reward_sequence_finished

## DEV: temporalmente en 100% para poder probar el flujo sin depender de la
## suerte. Valor definitivo de diseño: 0.2 (Sección 1 de la spec de ADN).
@export var dna_drop_chance: float = 1.0
@export var recovery_item_chance: float = 0.10
@export var first_aid_kit_heal_amount: int = 15

const STEP_SUMMARY: String = "summary"
const STEP_DNA_CHOICE: String = "dna_choice"
const STEP_DNA_RESULT: String = "dna_result"
const STEP_CARD_UNLOCKED: String = "card_unlocked"
const STEP_CARD_REPLACE_CHOICE: String = "card_replace_choice"
const STEP_KIT_OFFER: String = "kit_offer"
const STEP_KIT_RESULT: String = "kit_result"
const STEP_DONE: String = "done"

var _player: Node3D = null
var _pending_dna_species: Array[String] = []
var _kit_offer_pending: bool = false
var _step: String = STEP_DONE
var _last_message: String = ""

var _pending_unlocked_card: CardResource = null


## Llamado por CombatManager al ganar un combate. defeated_species trae la
## especie de CADA enemigo derrotado (puede repetirse), ya con la mano
## descartada y el combate totalmente cerrado — nunca a mitad de combate.
func start_reward_sequence(defeated_species: Array, player: Node3D) -> void:
	_player = player
	_pending_dna_species.clear()

	for species_id in defeated_species:
		if species_id == "":
			continue
		if randf() < dna_drop_chance:
			_pending_dna_species.append(species_id)

	_kit_offer_pending = randf() < recovery_item_chance and RunState.player_health < RunState.max_player_health
	_pending_unlocked_card = null

	reward_sequence_started.emit()

	if _pending_dna_species.is_empty() and not _kit_offer_pending:
		_finish()
		return

	_step = STEP_SUMMARY
	reward_step_changed.emit()


func get_step() -> String:
	return _step


## Líneas de texto para la pantalla de resumen ("ADN Orco +1", "Kit de
## Primeros Auxilios", etc.) — se arma antes de procesar nada, así se ve
## el conjunto completo de recompensas antes de elegir dónde va cada una.
func get_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	var counts: Dictionary = {}
	var order: Array[String] = []
	for species_id in _pending_dna_species:
		if not counts.has(species_id):
			order.append(species_id)
		counts[species_id] = counts.get(species_id, 0) + 1
	for species_id in order:
		lines.append("%s +%d" % [_species_label(species_id), counts[species_id]])
	if _kit_offer_pending:
		lines.append("Kit de Primeros Auxilios")
	return lines


func acknowledge_summary() -> void:
	if _step != STEP_SUMMARY:
		return
	_advance()


func get_current_species() -> String:
	return _pending_dna_species[0] if not _pending_dna_species.is_empty() else ""


func get_current_species_label() -> String:
	return _species_label(get_current_species())


func get_last_message() -> String:
	return _last_message


## Llamado por RewardUI cuando el jugador elige dónde aplicar el ADN
## pendiente actual. equipment_slot: "weapon" / "shield" / "suit".
func choose_dna_slot(equipment_slot: String) -> void:
	if _step != STEP_DNA_CHOICE or _pending_dna_species.is_empty():
		return

	var species_id: String = _pending_dna_species.pop_front()
	var before: int = _get_equipment_stat(equipment_slot)
	DNAManager.add_dna(equipment_slot, species_id, 1)
	var after: int = _get_equipment_stat(equipment_slot)

	_last_message = "%s aplicado en %s.\n%s: %d → %d" % [
		_species_label(species_id),
		_slot_label(equipment_slot),
		_stat_label(equipment_slot),
		before,
		after,
	]

	_pending_unlocked_card = DNAManager.check_and_unlock(equipment_slot, species_id)
	_step = STEP_DNA_RESULT
	reward_step_changed.emit()


## Llamado por RewardUI con "Continuar", tanto después de un mensaje de ADN
## como de un mensaje de Kit.
func acknowledge_message() -> void:
	if _step == STEP_DNA_RESULT:
		if _pending_unlocked_card != null:
			_step = STEP_CARD_UNLOCKED
			reward_step_changed.emit()
			return
		_advance()
	elif _step == STEP_KIT_RESULT:
		_advance()


func get_unlocked_card_description() -> String:
	if _pending_unlocked_card == null:
		return ""
	var card: CardResource = _pending_unlocked_card
	var category_label: String = "ATAQUE" if card.category == "attack" else "DEFENSA"
	var stat_line: String = "%d" % card.value
	match card.action_id:
		"player_heavy_attack":
			stat_line = "%d daño" % card.value
		"player_heavy_defense":
			stat_line = "%d bloqueo" % card.value
	return "Nueva carta desbloqueada:\n%s\n%s — %d stamina\n\nPuede reemplazar una carta de %s." % [
		card.card_name.to_upper(),
		stat_line,
		card.stamina_cost,
		category_label,
	]


## El jugador decide sumar la carta desbloqueada al mazo -> pasa a elegir
## qué carta de la misma categoría sacrifica.
func incorporate_unlocked_card() -> void:
	if _step != STEP_CARD_UNLOCKED or _pending_unlocked_card == null:
		return
	_step = STEP_CARD_REPLACE_CHOICE
	reward_step_changed.emit()


## El jugador decide dejarla afuera: queda desbloqueada (no se vuelve a
## ofrecer) pero el mazo no cambia.
func leave_unlocked_card_out() -> void:
	if _step != STEP_CARD_UNLOCKED:
		return
	_pending_unlocked_card = null
	_advance()


## Cartas del pool completo del jugador (deck+hand+discard) que comparten
## categoría con la carta desbloqueada — son las candidatas a reemplazar.
func get_replaceable_cards() -> Array[CardResource]:
	if _pending_unlocked_card == null:
		return []
	var result: Array[CardResource] = []
	for card in RunState.get_full_card_pool():
		if card.category == _pending_unlocked_card.category:
			result.append(card)
	return result


func get_unlocked_card_category_label() -> String:
	if _pending_unlocked_card == null:
		return ""
	return "ATAQUE" if _pending_unlocked_card.category == "attack" else "DEFENSA"


func choose_card_to_replace(old_card: CardResource) -> void:
	if _step != STEP_CARD_REPLACE_CHOICE or _pending_unlocked_card == null:
		return
	RunState.replace_card(old_card, _pending_unlocked_card)
	_pending_unlocked_card = null
	_advance()


func use_first_aid_kit() -> void:
	if _step != STEP_KIT_OFFER:
		return
	RunState.heal(first_aid_kit_heal_amount)
	_last_message = "Kit de Primeros Auxilios usado.\nVida: %d/%d" % [RunState.player_health, RunState.max_player_health]
	_step = STEP_KIT_RESULT
	reward_step_changed.emit()


func decline_first_aid_kit() -> void:
	if _step != STEP_KIT_OFFER:
		return
	_advance()


func _advance() -> void:
	if not _pending_dna_species.is_empty():
		_step = STEP_DNA_CHOICE
		reward_step_changed.emit()
		return

	if _kit_offer_pending:
		_kit_offer_pending = false  # se ofrece una única vez por encuentro
		_step = STEP_KIT_OFFER
		reward_step_changed.emit()
		return

	_finish()


func _finish() -> void:
	_step = STEP_DONE
	var player_ref: Node3D = _player
	_player = null
	reward_sequence_finished.emit()

	if player_ref != null and player_ref.has_method("unfreeze_after_combat"):
		player_ref.unfreeze_after_combat()


func _get_equipment_stat(equipment_slot: String) -> int:
	match equipment_slot:
		"weapon":
			var base: int = RunState.equipped_weapon.base_damage if RunState.equipped_weapon != null else 0
			return base + DNAManager.get_weapon_damage_bonus()
		"shield":
			var base: int = RunState.equipped_shield.base_block if RunState.equipped_shield != null else 0
			return base + DNAManager.get_shield_block_bonus()
		"suit":
			return RunState.max_player_health
	return 0


func _stat_label(equipment_slot: String) -> String:
	match equipment_slot:
		"weapon":
			return "Daño de Golpe Básico"
		"shield":
			return "Bloqueo de Defensa Básica"
		"suit":
			return "Vida máxima"
	return ""


func _slot_label(equipment_slot: String) -> String:
	match equipment_slot:
		"weapon":
			return "la Espada"
		"shield":
			return "el Escudo"
		"suit":
			return "el Traje"
	return equipment_slot


func _species_label(species_id: String) -> String:
	match species_id:
		"varkhen":
			return "ADN Varkhen"
		"horvex":
			return "ADN Horvex"
	return "ADN"
