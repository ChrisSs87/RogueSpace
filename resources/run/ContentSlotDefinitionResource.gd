extends Resource
class_name ContentSlotDefinitionResource

## Punto semántico local de un módulo. No instancia contenido ni participa de
## física: un sistema posterior decidirá qué recurso concreto ocupará el slot.
@export var stable_id: StringName
@export var category: StringName
@export var local_position := Vector3.ZERO
@export var local_rotation_degrees := Vector3.ZERO
@export var tags: Array[StringName] = []
@export var enabled := true
@export var allows_multiple_occupants := false
@export_range(0.0, 8.0, 0.1) var connector_clearance_m := 1.2
