extends RefCounted
class_name EnemyCombatant
const POISON_EFFECT := preload("res://resources/effects/poison.tres")
const EffectContainerScript := preload("res://scripts/effects/StatusEffectContainer.gd")

## EnemyCombatant.gd
## Estado de combate de UN enemigo dentro del encuentro actual. CombatManager
## mantiene una colección de estos (uno por enemigo real) en vez de
## variables sueltas tipo "_enemy_health" — agregar un segundo/tercer
## combatiente, o más adelante un elite/boss, es agregar un elemento a la
## lista, no duplicar lógica.
##
## No es un Resource: es puramente estado de ESTA instancia de combate, se
## descarta al terminar (no persiste entre combates ni entre enemigos).

var enemy_node: Node3D
var enemy_resource: EnemyResource

var current_health: int
var max_health: int
var block: int = 0
var intention: CardResource = null
var _opening_block_applied: bool = false
var effects = EffectContainerScript.new()
var poisoned: bool:
	get: return effects.has_effect(&"poison")


func _init(node: Node3D, resource: EnemyResource) -> void:
	enemy_node = node
	enemy_resource = resource
	max_health = resource.max_health
	current_health = max_health
	if resource.poison_immune: effects.grant_immunity(&"toxin")


func is_dead() -> bool:
	return current_health <= 0


## Elige al azar la próxima carta del mazo interno de ESTE enemigo. Un mazo
## vacío (ej. Xenomorfo/Boss en esta etapa) deja intention en null: ese
## combatiente simplemente no ataca ni se defiende ese turno.
func choose_intention() -> void:
	if enemy_resource == null or enemy_resource.combat_deck.is_empty():
		intention = null
	else:
		var valid_cards: Array[CardResource] = []
		for card in enemy_resource.combat_deck:
			if card.action_id != "enemy_heal" or current_health < max_health:
				valid_cards.append(card)
		intention = valid_cards.pick_random() if not valid_cards.is_empty() else null


func apply_opening_block() -> void:
	if _opening_block_applied or enemy_resource == null:
		return
	_opening_block_applied = true
	add_block(enemy_resource.opening_block)


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)


func reset_block_for_turn() -> void:
	block = 0


func apply_damage(amount: int) -> void:
	var absorbed: int = min(block, amount)
	block -= absorbed
	var remaining: int = amount - absorbed
	current_health = max(current_health - remaining, 0)


func add_block(amount: int) -> void:
	block += amount


func apply_effect_damage(amount: int) -> void: apply_damage(amount)
func apply_effect(definition: Resource, source: Variant = null) -> bool: return effects.apply_effect(definition, source)
func process_turn_start_effects() -> void: effects.process_turn_start(self)
func apply_poison() -> bool: return apply_effect(POISON_EFFECT)


func get_display_name() -> String:
	if enemy_resource != null and enemy_resource.enemy_name != "":
		return enemy_resource.enemy_name
	return "Enemigo"


func get_intention_text() -> String:
	if intention == null:
		return "—"
	return "%s (%s)" % [intention.card_name, _describe_card_value(intention)]


func _describe_card_value(card: CardResource) -> String:
	match card.action_id:
		"enemy_basic_attack", "enemy_special_attack":
			return "%d daño" % card.value
		"enemy_defense":
			return "%d bloqueo" % card.value
		"enemy_heal":
			return "%d HP" % card.value
		_:
			return ""
