extends RefCounted
class_name ContentPlacementDirector

## Resuelve sólo ocupación semántica. Los consumidores futuros recibirán
## ContentSlot + un content ID/resource, sin que este director conozca Enemy,
## loot, diálogos o escenas concretas.
static func build(plan: DungeonPlan, profile: ContentPlacementProfileResource, placement_seed: int) -> ContentPlacementPlan:
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
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed + int(profile.stable_id.hash())
	var desired := rng.randi_range(profile.min_slots, profile.max_slots) if profile.max_slots >= profile.min_slots else profile.min_slots
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
