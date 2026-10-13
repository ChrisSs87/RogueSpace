extends RefCounted

const LIGHT := preload("res://scripts/world/RoomLogicalLight.gd")

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
		var family: String = profile.cover_family_by_semantic.get(String(id),"")
		if family.is_empty() or plan.module_types[location.node_id] not in [&"ROOM",&"SIDE_ROOM"] or not plan.links.get(location.node_id,[]).is_empty(): continue
		var first_high := rng.randi_range(0,1) == 0
		for index in mini(profile.max_covers_per_room,2):
			var high := first_high if index == 0 else not first_high
			var size := profile.cover_size_high if high else profile.cover_size_medium
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
			var cover := LogicalCover.new()
			cover.name = "Cover_%d" % index
			cover.category = LogicalCover.Category.HIGH if high else LogicalCover.Category.MEDIUM
			cover.position = center
			cover.visibility_volume = AABB(Vector3(-size.x*0.5,-center.y,-size.z*0.5),Vector3(size.x,3.0,size.z))
			module.add_child(cover)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			cover.add_child(shape)
			# Existing bake collects CSGBox sources. Body is solely LogicalCover;
			# this CSG contributes matching geometry, never a second physics body.
			var mesh := CSGBox3D.new()
			mesh.size = size
			mesh.use_collision = false
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.32,0.4,0.25) if high else Color(0.48,0.4,0.26)
			mesh.material = material
			cover.add_child(mesh)
			cover.set_meta("cover_family",family)
			report.covers.append({"node":location.node_id,"semantic":id,"family":family,"category":cover.category,"position":center,"size":size})
	return report
