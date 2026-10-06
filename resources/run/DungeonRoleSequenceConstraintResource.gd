extends Resource
class_name DungeonRoleSequenceConstraintResource

## Patrón de selectores de rol/tag que no puede aparecer de forma contigua en
## el camino principal. Los selectores se comparan contra el rol del nodo y
## contra roles/tags de la ModuleDefinition elegida.
@export var selector_pattern: Array[StringName] = []
@export var description := ""
