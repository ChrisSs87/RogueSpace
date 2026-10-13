extends Node3D

## Bounded room contribution to the existing single logical lighting source.
## No ambient mutation, runtime lights, shadows, or influence outside this room.
var footprint := Vector2.ZERO
var addition := 2

func _ready() -> void:
	LightingManager.register_light_source(self)

func _exit_tree() -> void:
	LightingManager.unregister_light_source(self)

func get_light_contribution_at(world_position: Vector3) -> float:
	var local := to_local(world_position)
	return float(addition) if absf(local.x) < footprint.x*0.5 and absf(local.z) < footprint.y*0.5 and local.y > -0.25 and local.y < 3.0 else 0.0
