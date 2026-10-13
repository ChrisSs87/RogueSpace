extends RefCounted
class_name ContentPlacementDirector

## Resuelve sólo ocupación semántica. Los consumidores futuros recibirán
## ContentSlot + un content ID/resource, sin que este director conozca Enemy,
## loot, diálogos o escenas concretas.
static func build(plan: DungeonPlan, profile: ContentPlacementProfileResource, placement_seed: int, size_id: StringName = &"") -> ContentPlacementPlan:
	var result := ContentPlacementPlan.new()
	result.seed = placement_seed
	result.profile_id = profile.stable_id if profile != null else &""
	if plan == null or not plan.is_valid() or profile == null:
		result.generation_error = "invalid plan or profile"
		return result
	for node_id in plan.module_ids:
		var definition: ModuleDefinitionResource = plan.module_definitions.get(node_id, null)
		var module_transform: Transform3D = plan.assembly_transforms.get(node_id, Transform3D.IDENTITY)
		if definition == null or not plan.assembly_transforms.has(node_id):
			continue
		for slot_definition in definition.content_slots:
			if slot_definition == null:
				continue
			var slot := DungeonContentSlot.new()
			slot.unique_id = StringName("%s:%s" % [node_id, slot_definition.stable_id])
			slot.category = slot_definition.category
			slot.node_id = node_id
			slot.tags = slot_definition.tags.duplicate()
			slot.enabled = slot_definition.enabled
			slot.allows_multiple_occupants = slot_definition.allows_multiple_occupants
			slot.connector_clearance_m = slot_definition.connector_clearance_m
			slot.definition = slot_definition
			var local_transform := Transform3D(Basis.from_euler(slot_definition.local_rotation_degrees * (PI / 180.0)), slot_definition.local_position)
			slot.global_transform = module_transform * local_transform
			result.all_slots.append(slot)
	var candidates := _eligible_slots(plan, profile, result.all_slots)
	if profile.protect_start_from_patrol_vision:
		var safe_candidates: Array[DungeonContentSlot] = []
		for slot in candidates:
			var exposure := patrol_start_exposure(slot, plan, profile)
			if exposure.is_empty():
				safe_candidates.append(slot)
			else:
				exposure["slot"] = slot.unique_id
				result.start_safety_rejections.append(exposure)
		# Conditional coverage may be absent in this sector, but safety filtering
		# must never turn an existing required post into optional coverage.
		for tag in profile.coverage_semantic_conditions:
			var existed := candidates.any(func(slot: DungeonContentSlot): return slot.tags.has(tag))
			var remains := safe_candidates.any(func(slot: DungeonContentSlot): return slot.tags.has(tag))
			if existed and not remains:
				result.generation_error = "START safety conflicts with required coverage %s" % tag
				return result
		candidates = safe_candidates
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed + int(profile.stable_id.hash())
	var minimum := profile.min_slots
	var maximum := profile.max_slots
	if not profile.slot_count_ranges_by_size.is_empty():
		if not profile.slot_count_ranges_by_size.has(size_id):
			result.generation_error = "missing population size profile %s" % size_id
			return result
		var bounds: Vector2i = profile.slot_count_ranges_by_size[size_id]
		if bounds.x < 0 or bounds.y < bounds.x:
			result.generation_error = "invalid population range %s" % size_id
			return result
		minimum = bounds.x
		maximum = bounds.y
	var desired := rng.randi_range(minimum, maximum) if maximum >= minimum else minimum
	result.budget_range = Vector2i(minimum, maximum)
	result.requested_slot_count = desired
	if not profile.budget_capacity_tag.is_empty():
		var capacity := candidates.filter(func(slot: DungeonContentSlot): return slot.tags.has(profile.budget_capacity_tag)).size()
		desired = mini(desired, capacity)
	result.effective_slot_budget = desired
	if not profile.priority_slot_tags.is_empty():
		_select_grouped(result, candidates, profile, rng, desired, plan)
		return result
	while result.selected_slots.size() < desired and not candidates.is_empty():
		var selected_index := _weighted_slot_index(candidates, profile, rng)
		if selected_index < 0:
			break
		var slot: DungeonContentSlot = candidates[selected_index]
		slot.occupied = true
		slot.occupant_id = StringName("reserved:%s" % profile.stable_id)
		result.selected_slots.append(slot)
		candidates.remove_at(selected_index)
		if not slot.allows_multiple_occupants:
			candidates = candidates.filter(func(other: DungeonContentSlot) -> bool: return other.unique_id != slot.unique_id)
		if profile.max_slots_per_node > 0:
			var node_count := 0
			for chosen in result.selected_slots:
				if chosen.node_id == slot.node_id:
					node_count += 1
			if node_count >= profile.max_slots_per_node:
				candidates = candidates.filter(func(other: DungeonContentSlot) -> bool: return other.node_id != slot.node_id)
	return result


## An exact horizontal distance bound over ALL route segments, not endpoint
## sampling. Enemy's first vision condition rejects anything outside this
## range, regardless of FOV/LOS/light/exposure. We deliberately reject uncertain
## in-range positions even if currently facing away or behind a wall: patrol
## pauses/turns cannot invalidate an accepted safety certificate.
## Current modular START's PlayerSpawn shares its root XZ; Y is irrelevant to
## Enemy._passes_vision_baseline's horizontal range gate.
static func patrol_start_exposure(slot: DungeonContentSlot, plan: DungeonPlan, profile: ContentPlacementProfileResource) -> Dictionary:
	if slot.category != &"ENCOUNTER": return {}
	var start: Variant = null
	for id in plan.module_ids:
		if plan.module_types[id] == &"START" and plan.assembly_transforms.has(id):
			start = plan.assembly_transforms[id].origin
			break
	if start == null: return {"reason":"missing START transform"}
	var radius := -1.0
	for mapping in profile.runtime_category_pools:
		if mapping == null or mapping.category != slot.category or mapping.pool == null: continue
		for entry in mapping.pool.entries:
			if entry == null or entry.weight <= 0.0: continue
			var enemy := entry.payload as EnemyResource
			if enemy == null: return {"reason":"invalid encounter payload"}
			radius = maxf(radius, enemy.vision_range_tiles * GameBalance.tile_size_m)
	if radius < 0.0: return {"reason":"missing encounter payload range"}
	var points: Array[Vector3] = [slot.global_transform.origin]
	if profile.procedural_patrols:
		var patrol := ContentPatrolRoutes.planned_points(slot, plan)
		if patrol.size() < 2: return {"reason":"missing complete patrol"}
		points.append_array(patrol)
	var minimum := INF
	var target := Vector2(start.x, start.z)
	# Closing segment is conservative for >2 points; existing routes are straight
	# and traversed in both directions. Include initial travel and every endpoint.
	for index in points.size():
		var a := Vector2(points[index].x, points[index].z)
		var b := Vector2(points[(index+1) % points.size()].x, points[(index+1) % points.size()].z)
		var segment := b-a
		var t := clampf((target-a).dot(segment)/segment.length_squared(), 0.0, 1.0) if segment.length_squared() > 0.0 else 0.0
		minimum = minf(minimum, target.distance_to(a+segment*t))
	if minimum <= radius:
		return {"reason":"patrol enters START visual envelope", "minimum_distance_m":minimum, "pool_visual_range_m":radius}
	return {}


static func _select_grouped(result: ContentPlacementPlan, candidates: Array[DungeonContentSlot], profile: ContentPlacementProfileResource, rng: RandomNumberGenerator, desired: int, plan: DungeonPlan) -> void:
	var groups: Array = []
	var keys := {}
	for slot in candidates:
		var group: StringName = slot.definition.selection_group
		var key := String(slot.unique_id) if group.is_empty() else "%s:%s" % [slot.node_id, group]
		if not keys.has(key):
			keys[key] = groups.size()
			groups.append([])
		groups[keys[key]].append(slot)
	var priorities := profile.priority_slot_tags.duplicate()
	for tag in profile.coverage_semantic_conditions:
		var available := candidates.any(func(slot: DungeonContentSlot): return slot.tags.has(tag) and _matches_coverage_location(plan, profile, slot, tag))
		if not available:
			priorities.erase(tag)
	while result.selected_slots.size() < desired:
		var eligible: Array = []
		var tag: StringName = priorities.pop_front() if not priorities.is_empty() else &""
		for group in groups:
			if group.size() > desired - result.selected_slots.size(): continue
			var first: DungeonContentSlot = group[0]
			if not tag.is_empty() and not first.tags.has(tag): continue
			var already := 0
			for slot in result.selected_slots:
				if slot.node_id == first.node_id: already += 1
			if profile.max_slots_per_node > 0 and already + group.size() > profile.max_slots_per_node: continue
			eligible.append(group)
		if eligible.is_empty():
			if not tag.is_empty():
				result.generation_error = "no slot group for required coverage %s" % tag
			elif not profile.slot_count_ranges_by_size.is_empty():
				result.generation_error = "insufficient slot groups for population budget %s (selected %s)" % [desired, result.selected_slots.size()]
			return
		var selected: Array = eligible[rng.randi_range(0, eligible.size()-1)]
		groups.erase(selected)
		for slot: DungeonContentSlot in selected:
			slot.occupied = true
			slot.occupant_id = StringName("reserved:%s" % profile.stable_id)
			result.selected_slots.append(slot)
	if not priorities.is_empty():
		result.generation_error = "population budget exhausted before required coverage %s" % priorities


static func _matches_coverage_location(plan: DungeonPlan, profile: ContentPlacementProfileResource, slot: DungeonContentSlot, tag: StringName) -> bool:
	var semantic_id: StringName = profile.coverage_semantic_conditions[tag]
	for location: DungeonSemanticLocation in plan.semantic_locations:
		if location.definition != null and location.definition.semantic_id == semantic_id and location.node_id == slot.node_id:
			return true
	return false


static func _eligible_slots(plan: DungeonPlan, profile: ContentPlacementProfileResource, slots: Array[DungeonContentSlot]) -> Array[DungeonContentSlot]:
	var result: Array[DungeonContentSlot] = []
	for slot in slots:
		var role: StringName = plan.module_types.get(slot.node_id, &"")
		if not slot.enabled or (profile.exclude_start and role == &"START") or (profile.exclude_exit and role == &"EXIT"):
			continue
		if not profile.allowed_node_roles.is_empty() and not profile.allowed_node_roles.has(role):
			continue
		if profile.forbidden_node_roles.has(role) or not _tags_match(slot.tags, profile.required_slot_tags, profile.forbidden_slot_tags):
			continue
		if _category_weight(profile, slot.category) <= 0.0:
			continue
		var matches_location := true
		for tag in profile.coverage_semantic_conditions:
			if slot.tags.has(tag) and not _matches_coverage_location(plan, profile, slot, tag):
				matches_location = false
		if not matches_location:
			continue
		result.append(slot)
	return result


static func _tags_match(slot_tags: Array[StringName], required: Array[StringName], forbidden: Array[StringName]) -> bool:
	for tag in required:
		if not slot_tags.has(tag):
			return false
	for tag in forbidden:
		if slot_tags.has(tag):
			return false
	return true


static func _weighted_slot_index(slots: Array[DungeonContentSlot], profile: ContentPlacementProfileResource, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for slot in slots:
		total += _category_weight(profile, slot.category)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for index in range(slots.size()):
		roll -= _category_weight(profile, slots[index].category)
		if roll <= 0.0:
			return index
	return slots.size() - 1


static func _category_weight(profile: ContentPlacementProfileResource, category: StringName) -> float:
	for rule in profile.category_weights:
		if rule != null and rule.category == category:
			return maxf(0.0, rule.weight)
	return 0.0
