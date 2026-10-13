extends RefCounted

const LIGHT := preload("res://scripts/world/RoomLogicalLight.gd")
const VISUALS := preload("res://scripts/world/RoomCoverVisuals.gd")

## Restrained first subset: destination perimeter props, BEFORE the existing
## collider-derived bake. No solver changes, no navigation drawn by hand.
static func build(plan: DungeonPlan, modules: Node3D, profile: RoomEnvironmentProfileResource, seed: int) -> Dictionary:
	var report := {"covers":[], "lit_rooms":[], "rejected":[]}
	if profile == null: return report
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + int(profile.stable_id.hash())
	for location: DungeonSemanticLocation in plan.semantic_locations:
		var id := location.definition.semantic_id
		var module := modules.get_node_or_null(NodePath(String(location.node_id))) as Node3D
		if module == null or profile.excluded_semantic_ids.has(id): continue
		var dimensions: Vector2 = module.get_meta("footprint_size")
		var light := LIGHT.new()
		light.name = "RoomLogicalLight"
		light.footprint = dimensions
		light.addition = profile.room_light_addition
		module.add_child(light)
		var fixture := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(minf(dimensions.x-1.0,4.0),0.05,0.15)
		fixture.mesh = strip
		fixture.position = Vector3(0,1.95,0)
		var lamp := StandardMaterial3D.new()
		lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp.albedo_color = Color(0.85,0.9,0.7)
		fixture.material_override = lamp
		light.add_child(fixture)
		report.lit_rooms.append(String(location.node_id))
		_build_distribution_covers(plan,module,profile,seed,location,report)
		var family: String = profile.cover_family_by_semantic.get(String(id),"")
		if family.is_empty() or plan.module_types[location.node_id] not in [&"ROOM",&"SIDE_ROOM"] or not plan.links.get(location.node_id,[]).is_empty(): continue
		var first_high := rng.randi_range(0,1) == 0
		for index in mini(profile.max_covers_per_room,2):
			var high := first_high if index == 0 else not first_high
			var category := LogicalCover.Category.HIGH if high else LogicalCover.Category.MEDIUM
			var variant := _select_variant(profile,id,category,seed,location.node_id,index)
			if not profile.cover_variants.is_empty() and variant == null:
				report.rejected.append({"node":location.node_id,"index":index,"reason":"no compatible configured cover variant"})
				continue
			var size := profile.cover_size_high if high else profile.cover_size_medium
			if variant != null: size = variant.size
			# Positive X avoids the authored room guard route on negative X.
			var center := Vector3(dimensions.x*profile.corner_fraction, size.y*0.5, dimensions.y*profile.corner_fraction*(-1 if index == 0 else 1))
			var bounds := AABB(center-size*0.5,size)
			var safe := bounds.position.x >= profile.protected_axis_half_width_m and minf(absf(bounds.position.z),absf(bounds.end.z)) >= profile.protected_axis_half_width_m
			safe = safe and bounds.end.x <= dimensions.x*0.5-profile.wall_margin_m and maxf(absf(bounds.position.z),absf(bounds.end.z)) <= dimensions.y*0.5-profile.wall_margin_m
			# Reserve every declared spawn and patrol segment, not just selected ones.
			var definition: ModuleDefinitionResource = plan.module_definitions[location.node_id]
			for slot: ContentSlotDefinitionResource in definition.content_slots:
				var reserved := bounds.grow(0.55)
				var point := Vector3(slot.local_position.x,center.y,slot.local_position.z)
				if reserved.has_point(point): safe = false
				if slot.patrol != null:
					var previous := point
					for normalized in slot.patrol.footprint_points:
						var next := Vector3(normalized.x*dimensions.x,center.y,normalized.y*dimensions.y)
						if reserved.intersects_segment(previous,next) != null: safe = false
						previous = next
					if reserved.intersects_segment(previous,point) != null: safe = false
			if not safe:
				report.rejected.append({"node":location.node_id,"index":index,"reason":"reserved circulation/patrol or footprint"})
				continue
			report.covers.append(_instantiate_cover(module,location,center,size,category,family,variant,"Cover_%d" % index))
	return report

## Shared existing physical/visual contract, used by room and opt-in candidates.
static func _instantiate_cover(module: Node3D, location: DungeonSemanticLocation, center: Vector3, size: Vector3, category: int, family: String, variant: RoomCoverVariantResource, node_name: String) -> Dictionary:
	var cover := LogicalCover.new()
	cover.name = node_name
	cover.category = category
	cover.position = center
	cover.visibility_volume = AABB(Vector3(-size.x*0.5,-center.y,-size.z*0.5),Vector3(size.x,3.0,size.z))
	module.add_child(cover)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	cover.add_child(shape)
	# Matching bake source, never a duplicate physics body.
	var mesh := CSGBox3D.new()
	mesh.size = size
	mesh.use_collision = false
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32,0.4,0.25) if category == LogicalCover.Category.HIGH else Color(0.48,0.4,0.26)
	mesh.material = material
	cover.add_child(mesh)
	var variant_id := "legacy_box"
	if variant != null:
		family = RoomCoverVariantResource.Family.keys()[variant.family]
		variant_id = String(variant.stable_id)
		material.albedo_color = variant.body_color
		cover.set_meta("cover_variant",variant.stable_id)
		VISUALS.dress(cover,variant)
	cover.set_meta("cover_family",family)
	return {"node":location.node_id,"semantic":location.definition.semantic_id,"family":family,"variant":variant_id,"category":cover.category,"position":center,"size":size}

## Separate stream/policy: no draws from room, topology or population RNG.
## Geometry PASS is deliberately not a claim of tactical usefulness.
static func _build_distribution_covers(plan: DungeonPlan, module: Node3D, profile: RoomEnvironmentProfileResource, seed: int, location: DungeonSemanticLocation, report: Dictionary) -> void:
	var candidates: Array[Dictionary] = []
	for candidate in profile.distribution_cover_candidates:
		if candidate.get("semantic") == location.definition.semantic_id and candidate.get("role") == plan.module_types[location.node_id]: candidates.append(candidate)
	if candidates.is_empty(): return
	if not report.has("distribution"): report["distribution"] = []
	var audit := {"node":location.node_id,"semantic":location.definition.semantic_id,"examined":[],"instantiated":0,"tactical":"INCOMPLETE","tactical_reason":"requires runtime access and relevant-guard LOS validation"}
	var rng := RandomNumberGenerator.new()
	rng.seed = String("%s/%s/%s/distribution" % [seed,profile.stable_id,location.node_id]).hash()
	var selected := rng.randf() < profile.distribution_cover_probability
	# Rotate deterministic priority without changing the authored candidates.
	var offset := rng.randi_range(0,candidates.size()-1)
	var dimensions: Vector2 = module.get_meta("footprint_size")
	var occupied: Array[AABB] = []
	for index in candidates.size():
		var candidate := candidates[(index+offset)%candidates.size()]
		var reason := ""
		var variant := _select_variant(profile,location.definition.semantic_id,LogicalCover.Category.MEDIUM,seed,location.node_id,index)
		var fraction: Vector2 = candidate.get("position_fraction",Vector2.ZERO)
		var center := Vector3.ZERO
		var bounds := AABB()
		if variant == null: reason = "no compatible MEDIUM variant"
		else:
			center = Vector3(fraction.x*dimensions.x,variant.size.y*0.5,fraction.y*dimensions.y)
			bounds = AABB(center-variant.size*0.5,variant.size)
			reason = _distribution_rejection(plan.module_definitions[location.node_id],dimensions,bounds,profile)
			for previous in occupied:
				if previous.grow(0.55).intersects(bounds): reason = "another accepted cover reserve"
		var geometry_valid := reason.is_empty()
		if reason.is_empty() and not selected: reason = "deterministic optional omission"
		if reason.is_empty() and audit.instantiated >= profile.max_covers_per_distribution: reason = "distribution budget reached"
		audit.examined.append({"id":candidate.get("id",""),"position":center,"geometry_valid":geometry_valid,"accepted":reason.is_empty(),"reason":reason})
		if not reason.is_empty(): continue
		# Same single-body / matching bake source / logical category as rooms.
		var family: String = RoomCoverVariantResource.Family.keys()[variant.family]
		occupied.append(bounds)
		audit.instantiated += 1
		report.covers.append(_instantiate_cover(module,location,center,variant.size,LogicalCover.Category.MEDIUM,family,variant,"DistributionCover_%s" % candidate.get("id",index)))
	report.distribution.append(audit)

static func _distribution_rejection(definition: ModuleDefinitionResource, dimensions: Vector2, bounds: AABB, profile: RoomEnvironmentProfileResource) -> String:
	var cross := profile.protected_axis_half_width_m
	if not (bounds.end.x <= -cross or bounds.position.x >= cross) or not (bounds.end.z <= -cross or bounds.position.z >= cross): return "reserved circulation/access cross"
	if bounds.position.x < -dimensions.x*0.5+profile.wall_margin_m or bounds.end.x > dimensions.x*0.5-profile.wall_margin_m or bounds.position.z < -dimensions.y*0.5+profile.wall_margin_m or bounds.end.z > dimensions.y*0.5-profile.wall_margin_m: return "footprint/wall margin"
	var reserved := bounds.grow(0.55)
	for slot: ContentSlotDefinitionResource in definition.content_slots:
		var point := Vector3(slot.local_position.x,bounds.get_center().y,slot.local_position.z)
		if reserved.has_point(point): return "declared spawn reserve"
		if slot.patrol != null:
			var previous := point
			for normalized in slot.patrol.footprint_points:
				var next := Vector3(normalized.x*dimensions.x,point.y,normalized.y*dimensions.y)
				if reserved.intersects_segment(previous,next) != null: return "declared patrol reserve"
				previous = next
			if reserved.intersects_segment(previous,point) != null: return "declared patrol return reserve"
	return ""

static func _select_variant(profile: RoomEnvironmentProfileResource, semantic: StringName, category: int, seed: int, node: StringName, index: int) -> RoomCoverVariantResource:
	var eligible: Array[RoomCoverVariantResource] = []
	for variant in profile.cover_variants:
		if variant.category == category and variant.allowed_semantic_ids.has(semantic): eligible.append(variant)
	if eligible.is_empty(): return null
	# Separate stream: adding presentation variants does not consume the B
	# placement/category RNG or perturb subsequent room placements.
	var rng := RandomNumberGenerator.new()
	rng.seed = String("%s/%s/%s/%s" % [seed,profile.stable_id,node,index]).hash()
	return eligible[rng.randi_range(0,eligible.size()-1)]
