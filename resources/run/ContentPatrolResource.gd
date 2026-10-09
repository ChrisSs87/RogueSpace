extends Resource
class_name ContentPatrolResource

## Local XZ points as fractions of the assembled ModuleDefinition footprint.
## Geometry/nav validation is mandatory; this is not a second AI controller.
@export var stable_id: StringName
@export var footprint_points: Array[Vector2] = []
@export_range(0.0, 10.0) var pause_sec := 1.5
@export_range(0.0, 360.0) var turn_speed_deg := 100.0
