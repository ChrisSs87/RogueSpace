extends Resource
class_name WeaponResource

## WeaponResource.gd
## Datos del arma equipada. "Golpe Básico" (CardResource con
## action_id="player_basic_attack") consulta base_damage de acá en vez de
## traer un número fijo en la carta. Cuando exista ADN, alcanza con
## modificar o reemplazar el arma equipada para que el golpe básico refleje
## la evolución — sin tocar la carta ni CombatManager.

@export var weapon_name: String = "Arma"
@export var base_damage: int = 10
@export var loadout: LoadoutResource
@export var contributed_cards: Array[CardResource] = []
@export var allows_secondary: bool = true
@export var modifiers: Array[ValueModifierResource] = []
