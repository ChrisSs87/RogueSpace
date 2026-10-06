extends Node
const EffectContainerScript := preload("res://scripts/effects/StatusEffectContainer.gd")
const CharacterStatsScript := preload("res://scripts/stats/CharacterStats.gd")
const ModifierDef := preload("res://resources/equipment/ValueModifierResource.gd")

## RunState.gd (autoload)
## Estado TEMPORAL de la run: vida, stamina, mazo/mano/descarte del jugador
## y el equipamiento (arma/escudo/traje). No confundir con el estado
## permanente de la nave (ShipState, todavía no existe).
##
## Dos formas de "reiniciar" que NO son lo mismo:
##   - reset_run(): reinicio completo, vida incluida. Se usa al arrancar el
##     juego y al reiniciar la prueba desde la pantalla de derrota.
##   - prepare_for_combat(): se llama al ENTRAR a cada combate. Junta
##     mano+descarte de vuelta al mazo y lo mezcla, y rellena stamina — pero
##     a propósito NO toca la vida, porque la vida se conserva entre
##     combates dentro de la misma run (perderla del todo es una derrota,
##     no algo que se resetee solo).

signal player_health_changed(current: int, max: int)
signal player_stamina_changed(current: int, max: int)
signal oxygen_changed(current: float, maximum: float)
signal oxygen_telemetry_changed(distance_m: float, movement_cost: float, combat_cost: float)

## Vida máxima BASE (sin ADN). Es el valor de diseño ya fijado (30) — el
## bonus de ADN de traje se le suma encima para calcular max_player_health,
## nunca reemplaza este número.
@export var base_max_player_health: int = 30
@export var max_stamina: int = 3
@export var oxygen_max: float = 100.0

## Mazo inicial de la run. Que varias entradas apunten al mismo CardResource
## (ej. 5 veces "Golpe Básico") es intencional: las cartas son datos de solo
## lectura durante el combate, no hace falta duplicarlas por copia.
@export var starting_deck: Array[CardResource] = []
@export var equipped_weapon: WeaponResource
@export var equipped_shield: ShieldResource
@export var equipped_suit: SuitResource
@export var equipped_loadout: LoadoutResource

## Vida máxima EFECTIVA (base + bonus de ADN de traje). Se recalcula sola
## cuando cambia el ADN del traje — ver _on_dna_changed().
var max_player_health: int = 0
var player_health: int = 0
var stamina: int = 0
var block: int = 0
var oxygen_current: float = 0.0
var exploration_distance_travelled_m: float = 0.0
var oxygen_movement_spent: float = 0.0
var oxygen_combat_spent: float = 0.0
var run_started_msec: int = 0
var combats_started: int = 0
var enemies_defeated: int = 0
var movement_time_sec: Dictionary = {"STEALTH": 0.0, "WALK": 0.0, "RUN": 0.0}

var deck: Array[CardResource] = []
var hand: Array[CardResource] = []
var discard_pile: Array[CardResource] = []
var effects = EffectContainerScript.new()
var character_stats = CharacterStatsScript.new()
var run_seed: int = 0
var run_director: RunDirector


func _ready() -> void:
	DNAManager.dna_changed.connect(_on_dna_changed)
	EventBus.combat_ready.connect(_on_combat_ready)
	reset_run()


func reset_run() -> void:
	max_player_health = base_max_player_health + DNAManager.get_suit_max_health_bonus()
	player_health = max_player_health
	stamina = max_stamina
	block = 0
	reset_oxygen()
	run_started_msec = Time.get_ticks_msec()
	combats_started = 0
	enemies_defeated = 0
	movement_time_sec = {"STEALTH": 0.0, "WALK": 0.0, "RUN": 0.0}
	deck = get_starting_deck_for_loadout()
	deck.shuffle()
	hand.clear()
	discard_pile.clear()
	effects.clear_combat_effects()
	run_seed = 0
	run_director = null
	player_health_changed.emit(player_health, max_player_health)
	player_stamina_changed.emit(stamina, max_stamina)

func begin_world_run(graph: RunGraphResource, seed: int) -> void:
	run_seed = seed
	run_director = RunDirector.new()
	run_director.start(graph, seed)


## Fuente única de verdad para O2. Por ahora agotarse solo llega a cero: no
## hay daño, muerte ni game over hasta que esa etapa esté diseñada.
func reset_oxygen() -> void:
	oxygen_current = oxygen_max
	exploration_distance_travelled_m = 0.0
	oxygen_movement_spent = 0.0
	oxygen_combat_spent = 0.0
	oxygen_changed.emit(oxygen_current, oxygen_max)
	oxygen_telemetry_changed.emit(exploration_distance_travelled_m, oxygen_movement_spent, oxygen_combat_spent)


func consume_oxygen(amount: float, source: String = "") -> float:
	if amount <= 0.0:
		return 0.0
	var consumed: float = min(amount, oxygen_current)
	oxygen_current = maxf(oxygen_current - consumed, 0.0)
	if source == "movement":
		oxygen_movement_spent += consumed
	elif source == "combat":
		oxygen_combat_spent += consumed
	oxygen_changed.emit(oxygen_current, oxygen_max)
	oxygen_telemetry_changed.emit(exploration_distance_travelled_m, oxygen_movement_spent, oxygen_combat_spent)
	return consumed


func restore_oxygen(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var restored: float = min(amount, oxygen_max - oxygen_current)
	oxygen_current = min(oxygen_current + restored, oxygen_max)
	oxygen_changed.emit(oxygen_current, oxygen_max)
	return restored


func record_exploration_distance(distance_m: float) -> void:
	if distance_m <= 0.0:
		return
	exploration_distance_travelled_m += distance_m
	consume_oxygen(distance_m * GameBalance.oxygen_cost_per_meter, "movement")


## EventBus solo emite esto al comenzar COMBAT de verdad. Por ello vale una
## vez por encuentro sin importar si contiene uno o dos combatientes.
func _on_combat_ready(_player: Node3D, _enemies: Array) -> void:
	combats_started += 1
	consume_oxygen(GameBalance.normal_combat_oxygen_cost, "combat")


func record_enemy_defeated() -> void:
	enemies_defeated += 1


func record_movement_time(mode: String, seconds: float) -> void:
	if movement_time_sec.has(mode) and seconds > 0.0:
		movement_time_sec[mode] = float(movement_time_sec[mode]) + seconds


func get_run_time_sec() -> float:
	return maxf(0.0, float(Time.get_ticks_msec() - run_started_msec) / 1000.0)


func prepare_for_combat() -> void:
	deck = deck + hand + discard_pile
	hand.clear()
	discard_pile.clear()
	deck.shuffle()
	stamina = max_stamina
	block = 0
	player_stamina_changed.emit(stamina, max_stamina)

func get_starting_deck_for_loadout() -> Array[CardResource]:
	if equipped_loadout != null:
		var composed := equipped_loadout.compose_starting_deck()
		if not composed.is_empty():
			return composed
	if equipped_weapon != null and equipped_weapon.loadout != null and not equipped_weapon.loadout.starting_cards.is_empty():
		return equipped_weapon.loadout.starting_cards.duplicate()
	return starting_deck.duplicate()

func get_active_artifacts() -> Array[ArtifactResource]:
	return equipped_loadout.active_artifacts if equipped_loadout != null else []

func get_damage_card_stat() -> int:
	return character_stats.get_value(&"damage") + (equipped_weapon.base_damage if equipped_weapon != null else 0) + DNAManager.get_weapon_damage_bonus() + DNAManager.get_stat_bonus("weapon", ModifierDef.ValueKind.DAMAGE)

func get_block_card_stat() -> int:
	return character_stats.get_value(&"block") + (equipped_shield.base_block if equipped_shield != null else 0) + DNAManager.get_shield_block_bonus() + DNAManager.get_stat_bonus("shield", ModifierDef.ValueKind.BLOCK)

func rebuild_deck_from_loadout() -> void:
	deck = get_starting_deck_for_loadout()
	deck.shuffle()
	hand.clear()
	discard_pile.clear()


## Si el ADN de traje cambia (queda preparado para cuando exista la
## recompensa real en el Checkpoint B), el HP máximo se recalcula al toque.
## Subir el máximo también sube la vida actual en esa misma cantidad, para
## no dejar al jugador "por debajo" del nuevo máximo sin motivo — decisión
## de diseño razonable a falta de que la spec lo aclare explícitamente.
func _on_dna_changed(equipment_slot: String, _species_id: String, _new_amount: int) -> void:
	if equipment_slot != "suit":
		return

	var new_max: int = base_max_player_health + DNAManager.get_suit_max_health_bonus()
	var delta: int = new_max - max_player_health
	max_player_health = new_max
	if delta > 0:
		player_health += delta
	player_health = clamp(player_health, 0, max_player_health)
	player_health_changed.emit(player_health, max_player_health)


func apply_damage_to_player(amount: int) -> void:
	var absorbed: int = min(block, amount)
	block -= absorbed
	var remaining: int = amount - absorbed
	player_health = max(player_health - remaining, 0)
	player_health_changed.emit(player_health, max_player_health)

func apply_effect_damage(amount: int) -> void:
	apply_damage_to_player(amount)

func apply_effect(definition: Resource, source: Variant = null) -> bool:
	return effects.apply_effect(definition, source)

func process_turn_start_effects() -> void:
	effects.process_turn_start(self)


## Cura sin pasar de max_player_health. Usado por el Kit de Primeros
## Auxilios (Checkpoint B) — cualquier otra fuente de curación futura
## también debería pasar por acá, no tocar player_health directo desde
## afuera.
func heal(amount: int) -> void:
	player_health = min(player_health + amount, max_player_health)
	player_health_changed.emit(player_health, max_player_health)


func add_block(amount: int) -> void:
	block += amount


func spend_stamina(amount: int) -> bool:
	if amount > stamina:
		return false
	stamina -= amount
	player_stamina_changed.emit(stamina, max_stamina)
	return true


func refill_stamina() -> void:
	stamina = max_stamina
	player_stamina_changed.emit(stamina, max_stamina)


func reset_block() -> void:
	block = 0


func draw_cards(count: int) -> void:
	for i in count:
		if deck.is_empty():
			_reshuffle_discard_into_deck()
			if deck.is_empty():
				return  # no quedan cartas ni en mazo ni en descarte
		hand.append(deck.pop_back())


func _reshuffle_discard_into_deck() -> void:
	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()


func discard_card(card: CardResource) -> void:
	hand.erase(card)
	discard_pile.append(card)


func discard_hand() -> void:
	for card in hand.duplicate():
		discard_card(card)


## Las 10 cartas del jugador completas, sin importar en qué pila estén en
## este momento. Se usa entre combates (nunca durante uno) para mostrarle
## al jugador qué cartas de una categoría puede elegir para reemplazar.
func get_full_card_pool() -> Array[CardResource]:
	return deck + hand + discard_pile


## Reemplaza old_card por new_card en la pila donde esté (deck/hand/
## descarte) — nunca se llama durante un combate, solo desde el flujo de
## recompensa entre combates. Como varias entradas del mismo tipo de carta
## comparten el mismo CardResource (ej. 5x Golpe Básico), esto reemplaza la
## PRIMERA que encuentra; como son idénticas entre sí, da igual cuál.
## Devuelve true si encontró y reemplazó la carta.
func replace_card(old_card: CardResource, new_card: CardResource) -> bool:
	var idx: int = deck.find(old_card)
	if idx != -1:
		deck[idx] = new_card
		return true

	idx = hand.find(old_card)
	if idx != -1:
		hand[idx] = new_card
		return true

	idx = discard_pile.find(old_card)
	if idx != -1:
		discard_pile[idx] = new_card
		return true

	return false
