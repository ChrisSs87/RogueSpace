extends Resource
class_name ContentPlacementProfileResource

## Reglas de población, deliberadamente separadas de gramática/assembler.
@export var stable_id: StringName
@export var display_name := ""
@export var min_slots := 0
@export var max_slots := 0
@export var category_weights: Array[ContentCategoryWeightResource] = []
@export var allowed_node_roles: Array[StringName] = []
@export var forbidden_node_roles: Array[StringName] = []
@export var required_slot_tags: Array[StringName] = []
@export var forbidden_slot_tags: Array[StringName] = []
@export var exclude_start := true
@export var exclude_exit := true
@export var max_slots_per_node := 1
## Pools de payload runtime por categoria. Content Placement sigue eligiendo
## slots sin conocer su contenido; cada consumidor decide que categorias sabe
## materializar. El default vacio preserva perfiles y harnesses existentes.
@export var runtime_category_pools: Array[ContentRuntimeCategoryPoolResource] = []
## V1 no inventa puntos de patrulla dentro de módulos procedurales. Un perfil
## puede pedir el fallback seguro a IDLE cuando el EnemyResource requiere
## puntos authored que el slot no declara; el consumidor lo reporta siempre.
@export var fallback_to_idle_without_patrol_points := false
