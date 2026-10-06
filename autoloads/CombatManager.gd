extends Node

## CombatManager.gd (autoload)
## Motor de turnos del combate. Reacciona a EventBus.combat_ready (ya lo
## emite CombatEncounterManager cuando el jugador y los enemigos llegaron a
## distancia de combate) y desde ahí lleva el turno: robo, stamina, jugar
## cartas, turno enemigo, victoria/derrota.
##
## Cada enemigo del encuentro es un EnemyCombatant independiente (vida,
## bloqueo, mazo, intención propios), guardado en _combatants. No hay
## ninguna variable "el enemigo" ni casos especiales para "el segundo
## orco": agregar un elite o un boss más adelante es agregar otro
## EnemyCombatant a la misma colección.
##
## No sabe nada de mouse, touch ni Cardboard: solo expone play_card(),
## select_target() y end_turn(). CombatUI (o cualquier otra interfaz futura)
## llama a esos mismos métodos sin importar cómo se disparó la acción.
##
## Preparación para una futura cámara lenta tipo V.A.T.S. (Sección 3 del
## checkpoint de correcciones): decision_phase_started / action_phase_started
## marcan explícitamente cuándo el jugador puede tomarse su tiempo para
## elegir carta/objetivo (mundo podría ir lento) vs. cuándo se está
## resolviendo algo (carta jugada, turno enemigo — mundo a velocidad
## normal). Hoy nadie escucha estas señales y no se toca Engine.time_scale
## en ningún lado; son solo el enganche para que, cuando se implemente, sea
## conectar un listener acá y no reescribir el flujo de turnos.
##
## LÍMITE DE ESTA ETAPA: hasta 2 combatants. CombatEncounterManager ya no
## deja formar encuentros de más de 2 (max_enemies_per_combat = 2); acá hay
## además un tope defensivo propio, por si esa configuración cambiara sin
## haber ampliado el combate todavía.

const MAX_COMBATANTS_THIS_STAGE: int = 2

signal combat_started
signal combat_ended
signal state_updated
signal player_defeated
signal decision_phase_started
signal action_phase_started

var _in_combat: bool = false
var _player: Node3D = null
var _combatants: Array[EnemyCombatant] = []
var _selected_target_index: int = 0
## Especie de cada combatiente que murió DURANTE este combate (puede haber
## repetidos, ej. dos Orcos). Se arma en _remove_dead_combatants() y se le
## pasa a RewardManager al ganar — cada uno tira su propia recompensa de
## ADN por separado (Sección 1 de la spec: "cada enemigo se evalúa por
## separado").
var _defeated_species: Array[String] = []
const POISON_EFFECT := preload("res://resources/effects/poison.tres")
var _ambush_enemy: Node3D = null
var _ambush_bonus_pending: bool = false


func _ready() -> void:
	EventBus.combat_ready.connect(_on_combat_ready)
	EventBus.ambush_ready.connect(_on_ambush_ready)

func _on_ambush_ready(enemy: Node3D, _player_ref: Node3D) -> void:
	# La señal se emite antes de combat_ready; conservar el iniciador hasta
	# que ese mismo encounter cree sus combatants.
	_ambush_enemy = enemy


func _on_combat_ready(player: Node3D, enemies: Array) -> void:
	if _in_combat or enemies.is_empty():
		return

	var usable_enemies: Array = enemies
	if enemies.size() > MAX_COMBATANTS_THIS_STAGE:
		push_warning("CombatManager: se juntaron %d enemigos; esta etapa soporta hasta %d, se ignoran los demás." % [enemies.size(), MAX_COMBATANTS_THIS_STAGE])
		usable_enemies = enemies.slice(0, MAX_COMBATANTS_THIS_STAGE)

	_combatants.clear()
	for enemy_node in usable_enemies:
		var resource: EnemyResource = enemy_node.enemy_resource
		if resource == null:
			push_warning("CombatManager: un enemigo no tiene EnemyResource asignado, se lo excluye del combate.")
			continue
		_combatants.append(EnemyCombatant.new(enemy_node, resource))

	if _combatants.is_empty():
		return

	_player = player
	_selected_target_index = 0
	_defeated_species.clear()
	_in_combat = true
	_ambush_bonus_pending = _ambush_enemy in usable_enemies
	_ambush_enemy = null

	RunState.prepare_for_combat()
	for combatant in _combatants:
		combatant.apply_opening_block()
	combat_started.emit()

	_choose_all_intentions()
	_start_player_turn()


func _start_player_turn() -> void:
	RunState.reset_block()
	RunState.refill_stamina()
	if _ambush_bonus_pending:
		RunState.stamina += 2
		RunState.player_stamina_changed.emit(RunState.stamina, RunState.max_stamina)
		_ambush_bonus_pending = false
	RunState.process_turn_start_effects()
	RunState.draw_cards(4)
	state_updated.emit()
	decision_phase_started.emit()


## Llamado por CombatUI cuando el jugador toca el panel de un enemigo.
func select_target(index: int) -> void:
	if index < 0 or index >= _combatants.size():
		return
	_selected_target_index = index
	state_updated.emit()


func get_selected_target_index() -> int:
	return _selected_target_index


## Llamado por CombatUI cuando el jugador toca una carta de su mano.
func play_card(card: CardResource) -> void:
	if not _in_combat or card == null:
		return
	if not card in RunState.hand:
		return
	if RunState.stamina < card.stamina_cost:
		return

	# El jugador ya confirmó qué carta y a quién: termina la fase de
	# decisión, arranca la de ejecución (ver nota de V.A.T.S. arriba).
	action_phase_started.emit()

	RunState.spend_stamina(card.stamina_cost)
	_resolve_player_card(card)
	RunState.discard_card(card)

	_remove_dead_combatants()
	state_updated.emit()

	if _combatants.is_empty():
		_win_combat()
		return

	# Fin de turno automático al llegar a 0 stamina. El botón de "Finalizar
	# Turno" sigue disponible en todo momento para terminar antes de forma
	# voluntaria — esto solo cubre el caso de no poder pagar ninguna carta más.
	if RunState.stamina <= 0:
		end_turn()
		return

	# Todavía hay stamina y el combate sigue: vuelve a la fase de decisión
	# para la próxima carta (no hace falta esperar a un turno nuevo).
	decision_phase_started.emit()


## Llamado por CombatUI con el botón de "Finalizar Turno".
func end_turn() -> void:
	if not _in_combat:
		return

	# Termina la fase de decisión del jugador; arranca la resolución del
	# turno enemigo (ver nota de V.A.T.S. arriba).
	action_phase_started.emit()

	RunState.discard_hand()
	_execute_enemy_turns()

	if not _in_combat:
		return  # pudo terminar en derrota dentro de _execute_enemy_turns

	_choose_all_intentions()
	_start_player_turn()


func _execute_enemy_turns() -> void:
	for combatant in _combatants.duplicate():
		combatant.reset_block_for_turn()
		if combatant.intention != null:
			_resolve_enemy_card(combatant, combatant.intention)
		combatant.process_turn_start_effects()

	state_updated.emit()

	if RunState.player_health <= 0:
		_lose_combat()


func _choose_all_intentions() -> void:
	for combatant in _combatants:
		combatant.choose_intention()
	state_updated.emit()


## Resolver genérico por action_id para una carta del JUGADOR. El objetivo
## (a qué EnemyCombatant le pega) es explícito: el actualmente seleccionado
## mediante select_target(), nunca "el enemigo" implícito.
func _resolve_player_card(card: CardResource) -> void:
	if card.uses_data_driven_resolution():
		var target: EnemyCombatant = _get_selected_combatant()
		var resolved := CardValueResolver.get_resolved_card_values(card)
		var damage: int = resolved.damage
		if target != null and damage > 0:
			target.apply_damage(damage)
		var block_amount: int = resolved.block
		if block_amount > 0:
			RunState.add_block(block_amount)
		for effect in card.apply_effects:
			if card.effect_target == "player":
				RunState.apply_effect(effect, RunState)
			elif target != null:
				target.apply_effect(effect, RunState)
		return
	match card.action_id:
		"player_basic_attack":
			var target: EnemyCombatant = _get_selected_combatant()
			if target != null:
				var damage: int = RunState.equipped_weapon.base_damage if RunState.equipped_weapon != null else 0
				damage += DNAManager.get_weapon_damage_bonus()
				target.apply_damage(damage)
		"player_basic_defense":
			var block_amount: int = RunState.equipped_shield.base_block if RunState.equipped_shield != null else 0
			block_amount += DNAManager.get_shield_block_bonus()
			RunState.add_block(block_amount)
		"player_heavy_attack":
			# A diferencia de player_basic_attack, esta es una carta especial
			# con número fijo (Golpe Pesado): no consulta el arma ni ADN.
			var target: EnemyCombatant = _get_selected_combatant()
			if target != null:
				target.apply_damage(card.value)
		"player_heavy_defense":
			# Ídem para Escudo Pesado: bloqueo fijo, no consulta el escudo.
			RunState.add_block(card.value)


## Resolver genérico por action_id para la carta de UN enemigo puntual.
func _resolve_enemy_card(owner: EnemyCombatant, card: CardResource) -> void:
	match card.action_id:
		"enemy_basic_attack", "enemy_special_attack":
			RunState.apply_damage_to_player(card.value)
		"enemy_poison_attack":
			RunState.apply_damage_to_player(card.value)
			RunState.apply_effect(POISON_EFFECT, owner)
		"enemy_defense":
			owner.add_block(card.value)
		"enemy_heal":
			owner.heal(card.value)


func _get_selected_combatant() -> EnemyCombatant:
	if _selected_target_index < 0 or _selected_target_index >= _combatants.size():
		return null
	return _combatants[_selected_target_index]


## Saca de la colección a los combatants que murieron y libera su nodo real
## ahí mismo (el resto sigue el combate sin él). Si el objetivo seleccionado
## murió, el índice se reacomoda al primero que siga con vida.
func _remove_dead_combatants() -> void:
	var still_alive: Array[EnemyCombatant] = []
	for combatant in _combatants:
		if combatant.is_dead():
			RunState.record_enemy_defeated()
			if combatant.enemy_resource != null and combatant.enemy_resource.species_id != "":
				_defeated_species.append(combatant.enemy_resource.species_id)
			if combatant.enemy_node != null and is_instance_valid(combatant.enemy_node):
				combatant.enemy_node.queue_free()
		else:
			still_alive.append(combatant)
	_combatants = still_alive

	if _selected_target_index >= _combatants.size():
		_selected_target_index = 0


## El combate termina normalmente recién cuando la colección queda vacía
## (todos los combatants murieron). El jugador NO se libera acá todavía:
## eso pasa a ser responsabilidad de RewardManager, recién cuando termine
## la secuencia de recompensa completa (resumen + ADN + cartas + kit) — así
## nunca hay una ventana donde el jugador recupera el control antes de ver
## qué ganó.
func _win_combat() -> void:
	_in_combat = false
	RunState.effects.clear_combat_effects()
	_ambush_bonus_pending = false

	# Si se ganó a mitad de turno puede haber cartas sin jugar en la mano
	# (end_turn() las descarta, pero acá no pasamos por end_turn()). Las
	# consolidamos en el descarte para que el pool de 10 cartas usado por
	# el reemplazo de mazo (RewardManager/RunState.get_full_card_pool())
	# quede completo, sin cartas "perdidas" en la mano.
	RunState.discard_hand()

	var defeated_species: Array = _defeated_species.duplicate()
	_defeated_species.clear()
	var player_ref: Node3D = _player
	_combatants.clear()

	CombatEncounterManager.reset()
	combat_ended.emit()

	RewardManager.start_reward_sequence(defeated_species, player_ref)


## A propósito NO libera al jugador ni a los enemigos, y NO resetea
## CombatEncounterManager: esta etapa no implementa pérdida de run ni
## retorno a la nave. El único camino hacia adelante es reiniciar la prueba
## desde la pantalla de derrota (ver reset_after_defeat()).
func _lose_combat() -> void:
	_in_combat = false
	player_defeated.emit()


## Llamado por CombatUI cuando el jugador toca "Reiniciar prueba" en la
## pantalla de derrota, antes de recargar la escena.
func reset_after_defeat() -> void:
	_in_combat = false
	_player = null
	_combatants.clear()
	_defeated_species.clear()
	_selected_target_index = 0
	RunState.effects.clear_combat_effects()
	_ambush_bonus_pending = false
	_ambush_enemy = null

func get_debug_player_poisoned() -> bool:
	return RunState.effects.has_effect(&"poison")


# --- Consultas usadas por CombatUI (una por combatiente, por índice) ---

func get_combatant_count() -> int:
	return _combatants.size()


## Nodo real del enemigo en la escena 3D — lo usa CombatUI para el
## targeting por mirada (ver select_target_by_gaze en CombatUI.gd): necesita
## la posición espacial real de cada combatiente, no solo sus datos de HUD.
## También es el punto de enganche natural para un futuro indicador
## direccional del Scanner (sabe dónde está cada amenaza en el mundo).
func get_combatant_node(index: int) -> Node3D:
	if index < 0 or index >= _combatants.size():
		return null
	return _combatants[index].enemy_node


func get_combatant_display_name(index: int) -> String:
	if index < 0 or index >= _combatants.size():
		return ""
	return _combatants[index].get_display_name()


func get_combatant_health(index: int) -> int:
	if index < 0 or index >= _combatants.size():
		return 0
	return _combatants[index].current_health


func get_combatant_max_health(index: int) -> int:
	if index < 0 or index >= _combatants.size():
		return 0
	return _combatants[index].max_health


func get_combatant_block(index: int) -> int:
	if index < 0 or index >= _combatants.size():
		return 0
	return _combatants[index].block


func get_combatant_intention_text(index: int) -> String:
	if index < 0 or index >= _combatants.size():
		return "—"
	return _combatants[index].get_intention_text()
