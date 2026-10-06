extends Resource
class_name ShieldResource

## ShieldResource.gd
## Datos del escudo equipado. "Defensa Básica" (CardResource con
## action_id="player_basic_defense") consulta base_block de acá en vez de
## traer un número fijo en la carta — mismo patrón que WeaponResource con
## Golpe Básico. Cuando el ADN suba el bloqueo, alcanza con sumarle un bonus
## a este valor (ver DNAManager.get_shield_block_bonus()) sin tocar la
## carta ni CombatManager.

@export var shield_name: String = "Escudo"
@export var base_block: int = 6
