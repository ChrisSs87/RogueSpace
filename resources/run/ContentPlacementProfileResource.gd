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
