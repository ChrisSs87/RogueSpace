extends Resource
class_name LightingSourceResource
@export var stable_id: StringName
@export_enum("CEILING","WALL","COLUMN","CONSOLE","OPENING","ORGANIC") var mount := "CEILING"
@export_range(0,10) var power := 6.0
@export var visual_energy := 1.2
@export var range_m := 7.0
@export var direction := Vector3.DOWN
@export var color := Color(0.85,0.9,0.7)
@export var cone_half_angle_deg := 80.0
@export var enabled := true
## Migration bridge: preserve sector overrides of the existing room gain.
@export var reference_room_gain := 2.0

func create_model(gain: float, variant: LightingVariantResource, readability: float) -> RoomLightModelResource:
	var model := RoomLightModelResource.new()
	model.range_m = range_m
	model.direction = direction
	model.cone_half_angle_deg = cone_half_angle_deg
	model.color = variant.color if variant.override_color else color
	model.enabled = enabled
	model.ambient_readability = readability
	# RoomLogicalLight remains a legacy-unit source; manager aggregates canonically.
	var effective_power := clampf(power*gain/reference_room_gain*variant.power_multiplier,0,10)
	model.logical_peak_per_room_unit = effective_power/(2.0*gain) if gain > 0.0 else 0.0
	model.visual_energy_per_logical_unit = visual_energy*2.0/power if power > 0.0 else 0.0
	return model
