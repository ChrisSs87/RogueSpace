extends Resource
class_name DungeonSectorPathResource

## Una ruta de sectores permitida por un archetype. Permite, por ejemplo,
## GROUND→BASEMENT o GROUND→UPPER sin convertir el director en un condicional.
@export var path_id: StringName
@export_range(1.0, 100.0, 0.1) var selection_weight := 1.0
@export var sectors: Array[DungeonSectorDefinitionResource] = []
