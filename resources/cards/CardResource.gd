extends Resource
class_name CardResource

## CardResource.gd
## Carta genérica de combate. Agregar una carta nueva es crear un .tres con
## estos mismos campos — CombatManager no tiene ninguna lista de cartas
## específicas ni ningún "if es Golpe Básico".
##
## IMPORTANTE: "value" es el valor genérico de la acción. Para acciones que
## consultan el equipamiento, este campo se IGNORA a propósito:
##   - player_basic_attack: el daño sale del arma equipada (WeaponResource).
##   - player_basic_defense: el bloqueo sale del escudo equipado
##     (ShieldResource), más el bonus de ADN — ver DNAManager.
## Esto es lo que permite que, con ADN, alcance con modificar el arma o el
## escudo para que todas las cartas básicas reflejen el cambio, sin tener
## que crear una carta nueva por cada evolución.

@export var card_name: String = "Carta"
@export var stamina_cost: int = 1

## Categoría para las reglas de reemplazo de mazo: una carta especial
## desbloqueada por ADN reemplaza una carta de su misma categoría, nunca
## una específica por nombre (ej. "cualquier carta de ATAQUE", no
## "Golpe Básico" puntualmente). Las cartas de enemigos no usan esto.
@export_enum("attack", "defense") var category: String = "attack"

## Qué acción ejecuta esta carta. CombatManager tiene un resolver genérico
## por action_id, no una lógica particular por carta.
@export_enum(
	"player_basic_attack",
	"player_basic_defense",
	"player_heavy_attack",
	"player_heavy_defense",
	"enemy_basic_attack",
	"enemy_defense",
	"enemy_special_attack",
	"enemy_poison_attack"
) var action_id: String = "player_basic_attack"

## Valor genérico (daño/bloqueo de cartas enemigas o especiales con número
## fijo, ej. Golpe Pesado). Ignorado en player_basic_attack y
## player_basic_defense: ver nota de arriba.
@export var value: int = 0

@export var description: String = ""
@export var tags: Array[StringName] = [&"physical"]

## Componentes data-driven (6D). Cuando cualquiera está configurado, la
## carta se resuelve sin depender de action_id. Los Resources legacy siguen
## usando action_id hasta que se migren de manera deliberada.
@export var damage_amount: int = 0
@export var block_amount: int = 0
@export var apply_effects: Array[Resource] = []
@export_enum("enemy", "player") var effect_target: String = "enemy"
@export var derive_damage_from_weapon: bool = false
@export var derive_block_from_shield: bool = false

func uses_data_driven_resolution() -> bool:
	return damage_amount != 0 or block_amount != 0 or not apply_effects.is_empty() or derive_damage_from_weapon or derive_block_from_shield
