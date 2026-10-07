extends Resource
class_name DungeonBranchRuleResource

## Regla declarativa opcional para colgar destinos terminales de un nodo de
## circulación existente. No crea un segundo grafo: sólo añade children al
## DungeonPlan ya construido. Los templates que no la usan conservan la
## gramática legacy de JUNCTION -> rama fija.
enum ParentSelection { SEEDED, EARLIEST, LATEST }

@export var stable_id: StringName
## Roles o tags de ModuleDefinition que pueden actuar como distribuidores.
@export var parent_selectors: Array[StringName] = []
@export_range(0, 16) var min_parent_count := 0
@export_range(0, 16) var max_parent_count := 1
@export_range(0, 64) var min_parent_depth := 0
@export var max_parent_depth := -1
@export var require_main_path_parent := true
## Vecindario lógico de clearance alrededor de un parent distribuidor. Limita
## los TURN_* a ambos lados del parent para reservar, de forma conservadora,
## espacio de circulación para sus destinos laterales obligatorios. La pareja
## 0/-1 conserva por completo la gramática legacy.
@export_range(0, 16) var distribution_clearance_main_path_radius := 0
@export_range(-1, 32) var max_turns_in_distribution_clearance := -1
## Si se declara, el parent debe quedar después del nodo principal marcado por
## este tag. Permite expresar acceso -> núcleo -> ala sin conocer archetypes.
@export var parent_after_plan_tag: StringName
@export var parent_selection: ParentSelection = ParentSelection.SEEDED
## Total de destinos que esta regla añade, repartidos de forma determinista
## entre los parents elegidos. Estos límites permiten que un corredor sirva
## una cantidad variable de salas sin convertirlo en un layout fijo.
@export_range(0, 32) var min_total_children := 0
@export_range(0, 32) var max_total_children := 1
@export_range(1, 8) var min_children_per_parent := 1
@export_range(1, 8) var max_children_per_parent := 1
@export var destination_role: StringName = &"SIDE_ROOM"
## Tag lógico opcional para enlazar una SemanticLocation con el nodo que
## realmente distribuye. Es genérico: no conoce archetypes ni semánticas.
@export var parent_plan_tag: StringName
## Una regla puede pedir una variante física de su parent cuando necesita más
## conectores que el módulo de circulación estándar. La ausencia preserva las
## variantes normales del ROLE.
@export var parent_module_variants: Array[ModuleDefinitionResource] = []
@export var parent_variant_required := false
