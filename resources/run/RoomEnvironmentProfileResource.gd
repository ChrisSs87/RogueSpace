extends Resource
class_name RoomEnvironmentProfileResource

## Opt-in physical dressing, not a topology/content-population rule.
@export var stable_id: StringName
@export_range(0, 5) var room_light_addition := 2
@export var cover_family_by_semantic: Dictionary = {}
@export var excluded_semantic_ids: Array[StringName] = []
@export var max_covers_per_room := 2
## Keep a full cross clear: door half-width 1.2 + baked agent radius 0.55.
@export var protected_axis_half_width_m := 1.8
@export var wall_margin_m := 0.35
@export var cover_size_high := Vector3(1.6, 2.0, 1.2)
@export var cover_size_medium := Vector3(1.8, 1.1, 0.9)
@export var corner_fraction := 0.32
