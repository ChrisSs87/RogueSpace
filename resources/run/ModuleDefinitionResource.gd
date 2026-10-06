extends Resource
class_name ModuleDefinitionResource
@export var stable_id: StringName
@export var scene: PackedScene
@export var tags: Array[StringName] = []
@export var connector_tags: Array[StringName] = []
@export var selection_weight := 1.0
## Orden de preferencia del placement dentro de variantes equivalentes. Un
## valor mayor se prueba primero; una variante de menor prioridad queda como
## fallback geométrico sin cambiar el ROLE lógico del DungeonPlan.
@export var placement_priority := 0
# Datos físicos/semánticos que un assembler futuro puede interpretar. El
# catálogo TEST 6H usa estos campos; no impone escenas ni biomas productivos.
@export var roles: Array[StringName] = []
@export var footprint_size := Vector2(8.0, 8.0)
## Topología física local del módulo. Vacío conserva el fallback legacy por
## role; definido permite variantes físicas del mismo rol (p.ej. Junction N/S).
@export var connector_sides: Array[StringName] = []
@export var supports_main_path := true
@export var supports_branch := false
# Restricciones de transición simples. Secuencias de tres o más roles viven
# en DungeonTemplateResource para no duplicarlas entre ModuleDefinitions.
@export var allowed_next_selectors: Array[StringName] = []
@export var forbidden_next_selectors: Array[StringName] = []
# Slots semánticos locales: no se infieren de la geometría ni crean contenido.
@export var content_slots: Array[ContentSlotDefinitionResource] = []
