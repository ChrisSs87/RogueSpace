extends Resource
class_name BiomeLightingProfileResource
@export var stable_id: StringName
@export var architecture_id: StringName
@export_range(0,10) var ambient := 3.0
@export var readability_per_ambient_unit := 0.06
@export_range(0,16) var max_visual_lights := 8
@export var sources: Array[LightingSourceResource] = []
@export var variants: Array[LightingVariantResource] = []
@export var default_variant: StringName = &"OPERATIVA"
## Declarative roles/semantic/mount/source/priority/depth_stride, no tile RNG.
@export var placement_rules: Array[Dictionary] = []

func get_variant(id: StringName) -> LightingVariantResource:
	for variant in variants:
		if variant.stable_id == (default_variant if id == &"" else id): return variant
	return null

func get_source(id: StringName) -> LightingSourceResource:
	for source in sources:
		if source.stable_id == id: return source
	return null

func validate_variant(id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if ambient < 0 or ambient > 10 or max_visual_lights < 0 or max_visual_lights > 16: errors.append("invalid ambient/budget")
	var variant := get_variant(id)
	var variant_ids := {}
	for declared in variants:
		if declared.stable_id == &"" or variant_ids.has(declared.stable_id): errors.append("invalid/duplicate variant id")
		variant_ids[declared.stable_id] = true
	if not variant_ids.has(default_variant): errors.append("unknown default variant")
	if stable_id == &"" or architecture_id == &"": errors.append("lighting profile identity missing")
	if variant == null: errors.append("unauthorized lighting variant")
	var ids := {}
	for source in sources:
		if source.mount not in ["CEILING","WALL","COLUMN","CONSOLE","OPENING","ORGANIC"]: errors.append("unsupported light mount")
		if source.stable_id == &"" or ids.has(source.stable_id) or source.range_m <= 0 or source.reference_room_gain <= 0 or source.direction.length() < 0.001 or source.power < 0 or source.power > 10 or source.visual_energy < 0 or source.cone_half_angle_deg <= 0 or source.cone_half_angle_deg >= 90:
			errors.append("invalid/duplicate light source")
		ids[source.stable_id] = true
	if variant != null:
		if variant.minimum_active_lights < 0 or variant.minimum_active_lights > max_visual_lights: errors.append("minimum active lights conflicts with budget")
		var enabled_allowed := 0
		for source in sources:
			if source.enabled and variant.allowed_sources.has(source.stable_id): enabled_allowed += 1
		if variant.minimum_active_lights > 0 and enabled_allowed == 0: errors.append("minimum active lights has no enabled authorized source")
		if variant.activation_probability < 0 or variant.activation_probability > 1 or variant.power_multiplier < 0: errors.append("invalid variant activation/power")
		for source_id in variant.allowed_sources:
			if not ids.has(source_id): errors.append("variant references unknown source")
	for rule in placement_rules:
		var source := get_source(rule.get("source",&""))
		if source == null or source.mount != rule.get("mount",""): errors.append("incompatible source/socket rule")
	return errors
