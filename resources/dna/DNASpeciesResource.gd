extends Resource
class_name DNASpeciesResource

## DNASpeciesResource.gd
## Cuánto aporta CADA NIVEL de ADN de esta especie en cada equipamiento.
## DNAManager no tiene ningún "if especie == orco": lee estos números de
## acá. Agregar una especie nueva (fuera de alcance de esta demo) sería
## crear un .tres más, no tocar código.
##
## Checkpoint A: solo los stats numéricos directos (daño de arma, bloqueo de
## escudo, HP de traje). Los campos de % crítico y % veneno (Sección 9/11
## de la spec) se agregan en el Checkpoint D, cuando esos sistemas existan
## — no los incluyo todavía para no declarar campos que nada usa aún.

@export var species_id: String = ""
@export var species_display_name: String = ""
@export var tags: Array[StringName] = []
@export var units_per_level: int = 5
## Bonuses de CharacterStats por nivel. Reutiliza ValueModifierResource;
## para stats se usan operaciones FLAT y value_kind DAMAGE/BLOCK.
@export var stat_modifiers: Array[ValueModifierResource] = []

@export_category("Espada (por nivel de ADN)")
@export var weapon_damage_per_level: int = 0
## Carta que se desbloquea al llegar a nivel 3 / nivel 5 de ADN en la
## espada. Null = no desbloquea nada en ese nivel (ej. Xenomorfo espada en
## esta etapa: sus cartas necesitan Veneno, todavía no implementado).
@export var weapon_level_3_card: CardResource
@export var weapon_level_5_card: CardResource

@export_category("Escudo (por nivel de ADN)")
@export var shield_block_per_level: int = 0
@export var shield_level_3_card: CardResource
@export var shield_level_5_card: CardResource

@export_category("Traje (por nivel de ADN)")
@export var suit_max_health_per_level: int = 0
