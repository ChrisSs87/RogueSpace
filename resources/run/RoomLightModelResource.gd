extends Resource
class_name RoomLightModelResource

## One opt-in source per existing ceiling fixture. Gameplay units are not lux.
## Visual energy is explicitly mapped, never treated as logical exposure.
@export var enabled := true
@export var mounting_height_m := 1.9
@export var range_m := 7.0
@export var logical_peak_per_room_unit := 1.5
@export var visual_energy_per_logical_unit := 0.4
@export var cone_half_angle_deg := 80.0
@export var color := Color(0.85,0.9,0.7)
@export var direction := Vector3.DOWN
@export var ambient_readability := 0.12
@export var shadows_enabled := true
@export var inactive_fixture_brightness := 0.08

func contribution(local_offset: Vector3, room_intensity: float) -> float:
	var distance := local_offset.length()
	if range_m <= 0.0 or distance >= range_m: return 0.0
	if distance > 0.001 and rad_to_deg(direction.normalized().angle_to(local_offset)) > cone_half_angle_deg: return 0.0
	return room_intensity * logical_peak_per_room_unit * (1.0-distance/range_m)
