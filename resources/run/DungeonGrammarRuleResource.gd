extends Resource
class_name DungeonGrammarRuleResource

## Regla declarativa de un rol estructural. El generador usa estas reglas para
## elegir nodos; el assembler sólo consume el rol y su ModuleDefinition.
@export var role: StringName
@export var min_count := 0
@export var max_count := -1 # -1 = limitado sólo por el tamaño del template.
@export var selection_weight := 1.0
@export var max_consecutive := -1 # -1 = sin límite específico.
@export_range(0, 64) var min_depth_from_start := 0
## -1 conserva ausencia de límite superior. Permite declarar acceso/hub
## temprano sin introducir un ROLE específico para un archetype.
@export var max_depth_from_start := -1
## Los destinos branch-only nunca entran en el recorrido principal. El
## generador puede seguir crearlos mediante DungeonBranchRuleResource.
@export var main_path_allowed := true
@export var required := false
@export var forbidden := false
@export var main_path_only := true
@export var module_definition: ModuleDefinitionResource
# Variantes físicas semánticamente equivalentes. El plan conserva el ROLE;
# placement elige una de estas definiciones sin alterar la topología.
@export var module_variants: Array[ModuleDefinitionResource] = []
