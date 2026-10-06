extends RefCounted
class_name DungeonArchetypeDirector

const RUN_DIRECTOR := preload("res://scripts/world/RunDirector.gd")

## El RNG de archetype/sector es local y derivado del seed de run. No toca el
## RNG global ni sabe nada de geometría o B+C.
func create_sector_run(archetype: DungeonArchetypeResource, run_seed: int) -> DungeonSectorRun:
	var result := DungeonSectorRun.new()
	result.archetype = archetype
	result.run_seed = run_seed
	if archetype == null or archetype.sectors.is_empty():
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + int(archetype.archetype_id.hash())
	if not archetype.sector_paths.is_empty():
		var path := _choose_sector_path(archetype.sector_paths, rng)
		result.sector_definitions = path.sectors.duplicate()
	else:
		var min_count := clampi(archetype.sector_count_min, 1, archetype.sectors.size())
		var max_count := clampi(archetype.sector_count_max, min_count, archetype.sectors.size())
		var count := rng.randi_range(min_count, max_count)
		for index in range(count): result.sector_definitions.append(archetype.sectors[index])
	for sector in result.sector_definitions:
		result.sector_size_profiles.append(_choose_size_profile(sector, rng))
	_assign_archetype_semantics(result)
	if not archetype.allowed_enemy_faction_tags.is_empty():
		result.selected_faction = archetype.allowed_enemy_faction_tags[rng.randi_range(0, archetype.allowed_enemy_faction_tags.size() - 1)]
	return result

func build_sector_plan(sector_run: DungeonSectorRun, sector_index: int) -> DungeonPlan:
	if sector_run == null:
		return null
	if sector_index < 0 or sector_index >= sector_run.sector_definitions.size():
		return null
	while sector_run.sector_plans.size() <= sector_index:
		sector_run.sector_plans.append(null)
	var existing: DungeonPlan = sector_run.sector_plans[sector_index]
	if existing != null:
		return existing
	var plan := build_sector_plan_attempt(sector_run, sector_index, 0)
	sector_run.record_effective_sector_attempt(sector_index, 0, get_sector_effective_seed(sector_run, sector_index, 0), plan)
	return plan

## Construye un intento aislado. No lo promueve al estado efectivo de la run:
## eso sólo ocurre cuando el assembler confirma que la geometría cabe.
func build_sector_plan_attempt(sector_run: DungeonSectorRun, sector_index: int, retry_index: int, physical_feasibility_probe: Callable = Callable()) -> DungeonPlan:
	if sector_run == null or sector_index < 0 or sector_index >= sector_run.sector_definitions.size():
		return null
	var sector := sector_run.sector_definitions[sector_index]
	if sector == null or sector.template_pool.is_empty():
		return null
	var template := get_sector_template(sector_run, sector_index)
	if template == null:
		return null
	var director: RunDirector = RUN_DIRECTOR.new()
	director.seed = get_sector_effective_seed(sector_run, sector_index, retry_index)
	director.current_node_id = StringName("%s:%s:%d" % [sector_run.archetype.archetype_id, sector.sector_id, sector_index])
	var plan := director.build_plan(template)
	if plan != null and plan.is_valid():
		var semantic_director := SemanticLocationDirector.new()
		var semantic_definitions: Array[SemanticLocationResource] = []
		semantic_definitions.append_array(sector.semantic_locations)
		if sector_index < sector_run.archetype_semantic_locations.size(): semantic_definitions.append_array(sector_run.archetype_semantic_locations[sector_index])
		var semantic_seed := sector_run.run_seed + sector_index * 313 + retry_index * 65537
		semantic_director.populate(plan, sector_run.archetype, sector, sector_run.sector_size_profiles[sector_index], semantic_definitions, semantic_seed, physical_feasibility_probe)
	return plan

func get_sector_effective_seed(sector_run: DungeonSectorRun, sector_index: int, retry_index: int) -> int:
	if sector_run == null or sector_index < 0 or sector_index >= sector_run.sector_definitions.size():
		return 0
	var sector := sector_run.sector_definitions[sector_index]
	if sector == null:
		return 0
	var rng := RandomNumberGenerator.new()
	## retry=0 reproduce exactamente la semilla histórica del sector.
	rng.seed = sector_run.run_seed + int(sector.sector_id.hash()) + sector_index * 7919 + retry_index * 104729
	return rng.randi_range(1, 2147480000)

func get_sector_template(sector_run: DungeonSectorRun, sector_index: int) -> DungeonTemplateResource:
	var sector := sector_run.get_sector(sector_index) if sector_run != null else null
	if sector == null or sector.template_pool.is_empty():
		return null
	while sector_run.sector_templates.size() <= sector_index:
		sector_run.sector_templates.append(null)
	var cached: DungeonTemplateResource = sector_run.sector_templates[sector_index]
	if cached != null:
		return cached
	var rng := RandomNumberGenerator.new()
	rng.seed = sector_run.run_seed + int(sector.sector_id.hash()) + sector_index * 7919
	var selected: DungeonTemplateResource = sector.template_pool[rng.randi_range(0, sector.template_pool.size() - 1)]
	var resolved := selected.duplicate(true) as DungeonTemplateResource
	var size_profile: DungeonSizeProfileResource = sector_run.sector_size_profiles[sector_index] if sector_index < sector_run.sector_size_profiles.size() else null
	if size_profile != null:
		if size_profile.min_modules > 0: resolved.min_modules = size_profile.min_modules
		if size_profile.max_modules > 0: resolved.max_modules = size_profile.max_modules
		for rule in resolved.grammar_rules:
			if rule == null:
				continue
			if size_profile.role_min_counts.has(String(rule.role)):
				rule.min_count = int(size_profile.role_min_counts[String(rule.role)])
			if size_profile.role_max_counts.has(String(rule.role)):
				rule.max_count = int(size_profile.role_max_counts[String(rule.role)])
		if size_profile.min_reconnections >= 0: resolved.min_reconnections = size_profile.min_reconnections
		if size_profile.max_reconnections >= 0: resolved.max_reconnections = size_profile.max_reconnections
	sector_run.sector_templates[sector_index] = resolved
	return resolved

func _choose_size_profile(sector: DungeonSectorDefinitionResource, rng: RandomNumberGenerator) -> DungeonSizeProfileResource:
	if sector == null or sector.size_profiles.is_empty():
		return null
	var total := 0.0
	for profile in sector.size_profiles: total += profile.selection_weight
	var roll := rng.randf() * total
	for profile in sector.size_profiles:
		roll -= profile.selection_weight
		if roll <= 0.0: return profile
	return sector.size_profiles.back()

func _choose_sector_path(paths: Array[DungeonSectorPathResource], rng: RandomNumberGenerator) -> DungeonSectorPathResource:
	var total := 0.0
	for path in paths: total += path.selection_weight
	var roll := rng.randf() * total
	for path in paths:
		roll -= path.selection_weight
		if roll <= 0.0: return path
	return paths.back()

func _assign_archetype_semantics(sector_run: DungeonSectorRun) -> void:
	for _index in range(sector_run.sector_definitions.size()): sector_run.archetype_semantic_locations.append([])
	for definition in sector_run.archetype.semantic_locations:
		var candidates: Array[int] = []
		var preferred: Array[int] = []
		for index in range(sector_run.sector_definitions.size()):
			var sector := sector_run.sector_definitions[index]
			if definition.allowed_sectors.is_empty() or definition.allowed_sectors.has(sector.sector_id):
				candidates.append(index)
				if definition.preferred_sectors.has(sector.sector_id): preferred.append(index)
		if candidates.is_empty():
			if definition.mandatory: sector_run.initialization_error = "Mandatory archetype semantic %s has no sector" % definition.semantic_id
			continue
		var target: int = preferred.back() if not preferred.is_empty() else candidates[0]
		sector_run.archetype_semantic_locations[target].append(definition)
