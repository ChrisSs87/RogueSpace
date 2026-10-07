extends Resource
class_name SemanticLocationResource

enum SpaceKind { TRANSIT, DESTINATION }
enum Preference { ALLOWED, PREFERRED, PROHIBITED }

## Reglas puramente declarativas para reservar un nodo existente del plan.
## No instancia contenido ni conoce geometría concreta.
@export var semantic_id: StringName
@export var display_name := "Semantic Location"
@export var allowed_archetypes: Array[StringName] = []
@export var allowed_sectors: Array[StringName] = []
@export var preferred_sectors: Array[StringName] = []
@export var allowed_size_profiles: Array[StringName] = []
@export var compatible_node_roles: Array[StringName] = []
@export var mandatory := false
@export_range(0, 16) var min_count := 0
@export_range(0, 16) var max_count := 1
@export_range(0.0, 100.0, 0.1) var selection_weight := 1.0
## Desempate declarativo entre ubicaciones obligatorias. Cero conserva el
## orden de Resource existente; valores mayores reservan antes su candidato.
@export_range(-100, 100) var assignment_priority := 0
@export var preferred_size_tag: StringName
## Tags estructurales opcionales del DungeonPlan. Si se declaran, todos deben
## existir en el candidato; vacío conserva la selección legacy.
@export var required_plan_tags: Array[StringName] = []
## Variantes físicas preferidas para este significado. El plan conserva su
## ROLE lógico; el assembler recibe estas opciones antes que el kit genérico.
## Así una semantic location puede expresar jerarquía espacial sin un segundo
## grafo ni condiciones por semantic_id en gameplay.
@export var physical_module_variants: Array[ModuleDefinitionResource] = []
## Cuando es verdadero, la identidad semántica exige una de las variantes
## declaradas arriba. El assembler no puede degradarla silenciosamente al
## kit genérico del mismo ROLE si la colocación física falla.
@export var physical_variant_required := false
## Preferencia blanda para nodos de circulación con más conexiones reales.
## Cero conserva el contrato anterior; no invalida topologías pequeñas.
@export_range(0, 8) var preferred_connection_count := 0
@export var main_path_preference: Preference = Preference.ALLOWED
@export var branch_preference: Preference = Preference.ALLOWED
@export_range(0, 64) var min_depth_from_start := 0
@export var prefer_far_from_start := false
@export var space_kind: SpaceKind = SpaceKind.DESTINATION
@export var tags: Array[StringName] = []
@export var future_gameplay_tags: Array[StringName] = []
