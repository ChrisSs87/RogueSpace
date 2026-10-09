extends Resource
class_name ContentPlacementProfileResource

## Reglas de población, deliberadamente separadas de gramática/assembler.
@export var stable_id: StringName
@export var display_name := ""
@export var min_slots := 0
@export var max_slots := 0
## Optional declarative population ranges keyed by DungeonSizeProfile.size_id.
## Empty preserves the previous budget/RNG path for legacy profiles.
@export var slot_count_ranges_by_size: Dictionary[StringName, Vector2i] = {}
@export var category_weights: Array[ContentCategoryWeightResource] = []
@export var allowed_node_roles: Array[StringName] = []
@export var forbidden_node_roles: Array[StringName] = []
@export var required_slot_tags: Array[StringName] = []
@export var forbidden_slot_tags: Array[StringName] = []
@export var exclude_start := true
@export var exclude_exit := true
@export var max_slots_per_node := 1
## Opt-in coverage, in order. Atomic groups must fit the existing slot budget.
## Empty retains legacy selection byte-for-byte.
@export var priority_slot_tags: Array[StringName] = []
## Optional coverage tag -> semantic location. The requirement is active only
## when that location owns eligible slots with the tag. Other coverage and the
## population budget remain unchanged; an absent location is never substituted.
@export var coverage_semantic_conditions: Dictionary[StringName, StringName] = {}
@export var procedural_patrols := false
## Opt-in conservative START safety: the entire declared patrol (including
## spawn-to-first-point) must stay outside every eligible payload's visual
## range. Does not rely on a favorable heading, light level or temporary LOS.
@export var protect_start_from_patrol_vision := false
## Optional budget-capacity reference during redistribution. Keeps the count
## that the previous tagged slot set could supply, without selecting only it.
@export var budget_capacity_tag: StringName
## Pools de payload runtime por categoria. Content Placement sigue eligiendo
## slots sin conocer su contenido; cada consumidor decide que categorias sabe
## materializar. El default vacio preserva perfiles y harnesses existentes.
@export var runtime_category_pools: Array[ContentRuntimeCategoryPoolResource] = []
## V1 no inventa puntos de patrulla dentro de módulos procedurales. Un perfil
## puede pedir el fallback seguro a IDLE cuando el EnemyResource requiere
## puntos authored que el slot no declara; el consumidor lo reporta siempre.
@export var fallback_to_idle_without_patrol_points := false
