extends RefCounted
class_name SemanticLocationDirector

## Reserva locations sobre el plan ya válido. El placement físico no cambia:
## cada semantic location debe adaptarse a un nodo que ya existe.
func populate(plan: DungeonPlan, archetype: DungeonArchetypeResource, sector: DungeonSectorDefinitionResource, size_profile: DungeonSizeProfileResource, definitions: Array[SemanticLocationResource], run_seed: int, physical_feasibility_probe: Callable = Callable()) -> bool:
	if plan == null or archetype == null or sector == null:
		return false
	plan.calculate_depths()
	plan.semantic_locations.clear()
	plan.semantic_error = ""
	plan.semantic_feasibility.clear()
	plan.required_feasibility_status = &""
	plan.required_feasibility_error = ""
	var occupied: Dictionary = {}
	var ordered := definitions.duplicate()
	ordered.sort_custom(func(a: SemanticLocationResource, b: SemanticLocationResource) -> bool:
		return (1 if a.mandatory else 0) > (1 if b.mandatory else 0))
	for definition in ordered:
		if definition == null or not _matches_context(definition, archetype, sector, size_profile):
			continue
		var requested := maxi(definition.min_count, 1 if definition.mandatory else 0)
		if not definition.mandatory and definition.max_count > requested:
			var rng := RandomNumberGenerator.new()
			rng.seed = run_seed + int(definition.semantic_id.hash())
			requested = rng.randi_range(requested, definition.max_count)
		for occurrence in range(requested):
			var candidate := _select_candidate(plan, definition, occupied, run_seed, occurrence, physical_feasibility_probe)
			if candidate.is_empty():
				if definition.mandatory or occurrence < definition.min_count:
					plan.semantic_error = "Required semantic location %s has no compatible node" % definition.semantic_id
					return false
				break
			occupied[candidate] = definition
			_apply_physical_variants(plan, candidate, definition)
			var instance := DungeonSemanticLocation.new()
			instance.definition = definition
			instance.node_id = candidate
			instance.depth_from_start = int(plan.node_depths.get(candidate, 0))
			instance.is_main_path = plan.main_path_nodes.has(candidate)
			instance.is_branch = plan.branch_nodes.has(candidate)
			plan.semantic_locations.append(instance)
	return true


func _apply_physical_variants(plan: DungeonPlan, node_id: StringName, definition: SemanticLocationResource) -> void:
	if definition.physical_module_variants.is_empty(): return
	var merged: Array[ModuleDefinitionResource] = []
	for variant in definition.physical_module_variants:
		if variant != null and not merged.has(variant): merged.append(variant)
	if not definition.physical_variant_required:
		for variant in plan.module_definition_variants.get(node_id, []):
			if variant != null and not merged.has(variant): merged.append(variant)
	if not merged.is_empty():
		plan.module_definition_variants[node_id] = merged

func _matches_context(definition: SemanticLocationResource, archetype: DungeonArchetypeResource, sector: DungeonSectorDefinitionResource, size_profile: DungeonSizeProfileResource) -> bool:
	return (definition.allowed_archetypes.is_empty() or definition.allowed_archetypes.has(archetype.archetype_id)) and (definition.allowed_sectors.is_empty() or definition.allowed_sectors.has(sector.sector_id)) and (definition.allowed_size_profiles.is_empty() or (size_profile != null and definition.allowed_size_profiles.has(size_profile.size_id)))

func _select_candidate(plan: DungeonPlan, definition: SemanticLocationResource, occupied: Dictionary, run_seed: int, occurrence: int, physical_feasibility_probe: Callable = Callable()) -> StringName:
	var candidates: Array[StringName] = []
	for node_id in plan.module_ids:
		if occupied.has(node_id) or not _node_matches(plan, node_id, definition):
			continue
		if definition.space_kind == SemanticLocationResource.SpaceKind.DESTINATION and _touches_destination(plan, node_id, occupied):
			continue
		candidates.append(node_id)
	if candidates.is_empty():
		return &""
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool:
		var sa := _score(plan, a, definition, run_seed, occurrence)
		var sb := _score(plan, b, definition, run_seed, occurrence)
		return sa > sb if not is_equal_approx(sa, sb) else String(a) < String(b))
	if not definition.physical_variant_required or not physical_feasibility_probe.is_valid():
		return candidates[0]
	# Antes de atribuir un FAIL a la semantic REQUIRED, preguntar al assembler
	# real si el sector parcial ya es inviable sin esa variante. Esta separación
	# permite que el retry físico Horvex reciba el caso correcto.
	var baseline: Dictionary = physical_feasibility_probe.call(plan)
	if not bool(baseline.get("success", false)):
		plan.required_feasibility_status = &"BASE_PHYSICAL_FAILURE"
		plan.required_feasibility_error = str(baseline.get("error", "baseline physical assembly failed"))
		plan.semantic_feasibility.append({
			"semantic_id": definition.semantic_id,
			"status": plan.required_feasibility_status,
			"reason": plan.required_feasibility_error,
			"elapsed_ms": int(baseline.get("elapsed_ms", 0)),
			"candidate_checks": int(baseline.get("candidate_checks", 0)),
			"backtracks": int(baseline.get("backtracks", 0)),
		})
		return &""
	for candidate in candidates:
		var had_variants := plan.module_definition_variants.has(candidate)
		var previous_variants: Array = plan.module_definition_variants.get(candidate, []).duplicate()
		_apply_physical_variants(plan, candidate, definition)
		var result: Dictionary = physical_feasibility_probe.call(plan)
		var accepted := bool(result.get("success", false))
		plan.semantic_feasibility.append({
			"semantic_id": definition.semantic_id,
			"node_id": candidate,
			"accepted": accepted,
			"reason": str(result.get("error", "")),
			"elapsed_ms": int(result.get("elapsed_ms", 0)),
			"candidate_checks": int(result.get("candidate_checks", 0)),
			"backtracks": int(result.get("backtracks", 0)),
		})
		if had_variants:
			plan.module_definition_variants[candidate] = previous_variants
		else:
			plan.module_definition_variants.erase(candidate)
		if accepted:
			plan.required_feasibility_status = &"REQUIRED_CANDIDATE_VALID"
			plan.required_feasibility_error = ""
			return candidate
	plan.required_feasibility_status = &"REQUIRED_CANDIDATES_INVALID"
	plan.required_feasibility_error = "no REQUIRED candidate materializes within the production spatial budget"
	return &""

func _node_matches(plan: DungeonPlan, node_id: StringName, definition: SemanticLocationResource) -> bool:
	var role: StringName = plan.module_types.get(node_id, &"")
	if not definition.compatible_node_roles.is_empty() and not definition.compatible_node_roles.has(role):
		return false
	var depth := int(plan.node_depths.get(node_id, -1))
	if depth < definition.min_depth_from_start:
		return false
	var main := plan.main_path_nodes.has(node_id)
	var branch := plan.branch_nodes.has(node_id)
	if definition.main_path_preference == SemanticLocationResource.Preference.PROHIBITED and main:
		return false
	if definition.branch_preference == SemanticLocationResource.Preference.PROHIBITED and branch:
		return false
	return true

func _touches_destination(plan: DungeonPlan, node_id: StringName, occupied: Dictionary) -> bool:
	for other in occupied:
		var other_definition: SemanticLocationResource = occupied[other]
		if other_definition.space_kind != SemanticLocationResource.SpaceKind.DESTINATION:
			continue
		if plan.links.get(node_id, []).has(other) or plan.links.get(other, []).has(node_id):
			return true
	return false

func _score(plan: DungeonPlan, node_id: StringName, definition: SemanticLocationResource, run_seed: int, occurrence: int) -> float:
	var result := definition.selection_weight
	var depth := int(plan.node_depths.get(node_id, 0))
	if definition.prefer_far_from_start:
		result += depth * 100.0
	if definition.main_path_preference == SemanticLocationResource.Preference.PREFERRED and plan.main_path_nodes.has(node_id):
		result += 20.0
	if definition.branch_preference == SemanticLocationResource.Preference.PREFERRED and plan.branch_nodes.has(node_id):
		result += 20.0
	if definition.preferred_connection_count > 0:
		result -= abs(_connection_count(plan, node_id) - definition.preferred_connection_count) * 10.0
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + int(definition.semantic_id.hash()) + int(node_id.hash()) + occurrence * 31
	return result + rng.randf()


func _connection_count(plan: DungeonPlan, node_id: StringName) -> int:
	var count := (plan.links.get(node_id, []) as Array).size()
	for parent_variant in plan.links:
		if (plan.links[parent_variant] as Array).has(node_id): count += 1
	return count
