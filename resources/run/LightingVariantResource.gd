extends Resource
class_name LightingVariantResource
@export var stable_id: StringName
@export var allowed_sources: Array[StringName] = []
@export_range(0,1) var activation_probability := 1.0
@export var power_multiplier := 1.0
@export var minimum_active_lights := 0
@export var override_color := false
@export var color := Color.WHITE
