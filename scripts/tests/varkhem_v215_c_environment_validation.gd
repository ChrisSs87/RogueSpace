extends "res://scripts/tests/varkhem_v215_b_environment_validation.gd"

func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	var profile: RoomEnvironmentProfileResource = dungeon.active_archetype.room_environment_profile
	var report: Dictionary = dungeon.current_room_environment_report
	var modules := dungeon.get_node("AssembledModules")
	var families := {}
	for row in report.get("covers",[]):
		var matching: RoomCoverVariantResource = null
		for variant in profile.cover_variants:
			if String(variant.stable_id) == row.variant: matching = variant
		if matching == null:
			errors.append("C variant missing from configured catalogue")
			continue
		if not matching.allowed_semantic_ids.has(row.semantic) or matching.category != row.category or matching.size != row.size: errors.append("C semantic/category/physical payload mismatch")
		families[row.family] = families.get(row.family,0)+1
		var module: Node3D = modules.get_node(NodePath(String(row.node)))
		for cover in module.get_children():
			if not cover is LogicalCover or cover.position != row.position: continue
			var bounds := AABB(-matching.size*0.5,matching.size)
			var collisions := 0
			var csg_count := 0
			for part in cover.get_children():
				if part is CollisionShape3D:
					collisions += 1
					if not part.shape is BoxShape3D or part.shape.size != matching.size: errors.append("C collision mismatch")
				if part is CSGBox3D:
					csg_count += 1
					if part.use_collision or part.size != matching.size: errors.append("C bake/duplicate body mismatch")
				if part is MeshInstance3D:
					var aabb: AABB = part.transform * part.get_aabb()
					if not bounds.grow(0.001).encloses(aabb): errors.append("C visual exceeds reserved physical envelope")
			if collisions != 1 or csg_count != 1: errors.append("C not a single physical/bake envelope")
	# Exercise all configured presentations, even if an optional room was not
	# selected in this sector. Same LogicalCover contract, no duplicate rules.
	for variant in profile.cover_variants:
		var cover := LogicalCover.new()
		cover.category = variant.category
		cover.visibility_volume = AABB(Vector3(-variant.size.x*0.5,0,-variant.size.z*0.5),Vector3(variant.size.x,3,variant.size.z))
		add_child(cover)
		var from := Vector3(0,1.5,-3)
		var to := Vector3(0,1.5,3)
		if cover.blocks_sight(from,to,false) != (variant.category == LogicalCover.Category.HIGH): errors.append("C standing logical category mismatch")
		if not cover.blocks_sight(from,to,true): errors.append("C crouched cover missing")
		var side := Vector3(3,0,0)
		if cover.blocks_sight(from+side,to+side,true): errors.append("C non-interposed cover blocked vision")
		preload("res://scripts/world/RoomCoverVisuals.gd").dress(cover,variant)
		if cover.get_child_count() not in [2,4]: errors.append("C unexpected presentation complexity")
		cover.free()
	print("C_FAMILIES="+JSON.stringify({"seed":dungeon.seed,"sector":dungeon.current_sector_index,"counts":families,"variants_checked":profile.cover_variants.size(),"errors":errors}))
	return errors
