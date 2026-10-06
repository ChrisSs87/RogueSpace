extends Resource
class_name DungeonSizeProfileResource

## Perfil de escala lógico. Permite que un archetype cambie profundidad y
## potencial futuro sin convertir SMALL/MEDIUM/LARGE en condicionales de código.
@export var size_id: StringName
@export var display_name := "Size"
@export_range(1.0, 100.0, 0.1) var selection_weight := 1.0
@export var min_modules := 0
@export var max_modules := 0
## Overrides data-driven por rol para que el tamaño cambie capacidad real,
## no sólo una etiqueta. Ejemplo .tres: {"JUNCTION": 2, "ROOM": 1}.
@export var role_min_counts: Dictionary = {}
@export var role_max_counts: Dictionary = {}
## -1 conserva la configuración del template; otros valores la especializan
## por escala sin condicionales de archetype dentro del generador.
@export var min_reconnections := -1
@export var max_reconnections := -1
@export var tags: Array[StringName] = []
