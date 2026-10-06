extends Node

## Diagnóstico aislado 6K.4B Parte 2.1. No cambia recursos productivos ni
## intenta reparar el plan: reconstruye el mismo BASEMENT y prueba variantes
## semánticas físicas sobre copias nuevas del DungeonPlan.
const ARCHETYPE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")
const ARCHETYPE_DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const RUN_DIRECTOR := preload("res://scripts/world/RunDirector.gd")
const STAGE_PROBE := preload("res://scripts/tests/stage6g_assembly_probe.gd")

const DEFAULT_SEED := 65015

func _ready() -> void:
	var seed := DEFAULT_SEED
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): seed = int(args[0])
	var archetype_director: DungeonArchetypeDirector = ARCHETYPE_DIRECTOR.new()
	var sector_run := archetype_director.create_sector_run(ARCHETYPE, seed)
	var sector_index := _sector_index(sector_run, &"BASEMENT")
	if sector_index < 0:
		push_error("6K.4B DIAG missing BASEMENT for seed %d" % seed)
		get_tree().quit(1)
		return
	var sector := sector_run.get_sector(sector_index)
	var template := archetype_director.get_sector_template(sector_run, sector_index)
	var semantic_seed := sector_run.run_seed + sector_index * 313
	var raw := _build_raw_plan(archetype_director, sector_run, sector_index, template)
	var definitions := _semantic_definitions(sector_run, sector_index)
	var prison := _find_semantic(definitions, &"PRISON")
	var barracks := _find_semantic(definitions, &"BARRACKS")
	print("6K.4B DIAG CONTEXT seed=%d sector=%s index=%d size=%s template=%s effective_seed=%d modules=%d" % [seed, sector.sector_id, sector_index, sector_run.sector_size_profiles[sector_index].size_id, template.stable_id, archetype_director.get_sector_effective_seed(sector_run, sector_index, 0), raw.module_ids.size()])
	print("6K.4B DIAG DEFINITIONS %s" % [definitions.map(func(d): return d.semantic_id)])
	if raw == null or prison == null or barracks == null:
		push_error("6K.4B DIAG missing raw plan or required semantic")
		get_tree().quit(1)
		return
	var selector := SemanticLocationDirector.new()
	raw.calculate_depths()
	var occupied: Dictionary = {}
	var prison_selected := selector._select_candidate(raw, prison, occupied, semantic_seed, 0)
	occupied[prison_selected] = prison
	selector._apply_physical_variants(raw, prison_selected, prison)
	var barracks_selected := selector._select_candidate(raw, barracks, occupied, semantic_seed, 0)
	print("6K.4B DIAG GREEDY prison=%s barracks=%s" % [prison_selected, barracks_selected])
	var candidates := _barracks_candidates(raw, selector, barracks, occupied)
	for candidate in candidates:
		_print_candidate(raw, candidate, occupied)
		var probe := _probe_assignment(archetype_director, sector_run, sector_index, template, prison, prison_selected, barracks, candidate)
		print("6K.4B DIAG PROBE candidate=%s assembly=%s placed=%s stats=%s detail=%s" % [candidate, probe.get("success", false), probe.get("placed", false), probe.get("stats", {}), probe.get("detail", {})])
	print("6K.4B DIAG GLOBAL-REASSIGNMENT BEGIN")
	var global_solutions := _probe_all_destination_pairs(archetype_director, sector_run, sector_index, template, prison, barracks, semantic_seed)
	print("6K.4B DIAG GLOBAL-REASSIGNMENT solutions=%s" % [global_solutions])
	for depth in [3, 4, 6, 8]:
		var offline := _probe_assignment_with_budget(archetype_director, sector_run, sector_index, template, prison, prison_selected, barracks, barracks_selected, depth)
		print("6K.4B DIAG OFFLINE depth=%d greedy_prison=%s greedy_barracks=%s assembly=%s placed=%s stats=%s detail=%s" % [depth, prison_selected, barracks_selected, offline.get("success", false), offline.get("placed", false), offline.get("stats", {}), offline.get("detail", {})])
	get_tree().quit(0)


func _sector_index(sector_run: DungeonSectorRun, target: StringName) -> int:
	for index in range(sector_run.sector_count()):
		if sector_run.get_sector(index).sector_id == target:
			return index
	return -1


func _build_raw_plan(archetype_director: DungeonArchetypeDirector, sector_run: DungeonSectorRun, sector_index: int, template: DungeonTemplateResource) -> DungeonPlan:
	var director: RunDirector = RUN_DIRECTOR.new()
	director.seed = archetype_director.get_sector_effective_seed(sector_run, sector_index, 0)
	var sector := sector_run.get_sector(sector_index)
	director.current_node_id = StringName("%s:%s:%d" % [sector_run.archetype.archetype_id, sector.sector_id, sector_index])
	return director.build_plan(template)


func _semantic_definitions(sector_run: DungeonSectorRun, sector_index: int) -> Array[SemanticLocationResource]:
	var result: Array[SemanticLocationResource] = []
	result.append_array(sector_run.get_sector(sector_index).semantic_locations)
	if sector_index < sector_run.archetype_semantic_locations.size():
		result.append_array(sector_run.archetype_semantic_locations[sector_index])
	return result


func _find_semantic(definitions: Array[SemanticLocationResource], semantic_id: StringName) -> SemanticLocationResource:
	for definition in definitions:
		if definition.semantic_id == semantic_id:
			return definition
	return null


func _barracks_candidates(plan: DungeonPlan, selector: SemanticLocationDirector, barracks: SemanticLocationResource, occupied: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for node_id in plan.module_ids:
		if occupied.has(node_id):
			continue
		if not selector._node_matches(plan, node_id, barracks):
			continue
		if barracks.space_kind == SemanticLocationResource.SpaceKind.DESTINATION and selector._touches_destination(plan, node_id, occupied):
			continue
		result.append(node_id)
	return result


func _parent(plan: DungeonPlan, node_id: StringName) -> StringName:
	for source_variant in plan.links:
		if (plan.links[source_variant] as Array).has(node_id):
			return source_variant
	return &""


func _neighbors(plan: DungeonPlan, node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for child in plan.links.get(node_id, []):
		if not result.has(child): result.append(child)
	for source_variant in plan.links:
		if (plan.links[source_variant] as Array).has(node_id) and not result.has(source_variant): result.append(source_variant)
	return result


func _print_candidate(plan: DungeonPlan, node_id: StringName, occupied: Dictionary) -> void:
	var reserved := &""
	if occupied.has(node_id): reserved = (occupied[node_id] as SemanticLocationResource).semantic_id
	print("6K.4B DIAG CANDIDATE node=%s role=%s depth=%d parent=%s route=%s links=%s reserved=%s planned_definition=%s" % [node_id, plan.module_types.get(node_id, &""), int(plan.node_depths.get(node_id, -1)), _parent(plan, node_id), "MAIN" if plan.main_path_nodes.has(node_id) else "BRANCH" if plan.branch_nodes.has(node_id) else "OTHER", _neighbors(plan, node_id), reserved, (plan.module_definitions.get(node_id, null) as ModuleDefinitionResource).stable_id])


func _probe_assignment(archetype_director: DungeonArchetypeDirector, sector_run: DungeonSectorRun, sector_index: int, template: DungeonTemplateResource, prison: SemanticLocationResource, prison_node: StringName, barracks: SemanticLocationResource, barracks_node: StringName) -> Dictionary:
	return _probe_assignment_with_budget(archetype_director, sector_run, sector_index, template, prison, prison_node, barracks, barracks_node, template.max_spatial_backtrack_depth)


func _probe_assignment_with_budget(archetype_director: DungeonArchetypeDirector, sector_run: DungeonSectorRun, sector_index: int, template: DungeonTemplateResource, prison: SemanticLocationResource, prison_node: StringName, barracks: SemanticLocationResource, barracks_node: StringName, budget: int) -> Dictionary:
	var plan := _build_raw_plan(archetype_director, sector_run, sector_index, template)
	var selector := SemanticLocationDirector.new()
	selector._apply_physical_variants(plan, prison_node, prison)
	selector._apply_physical_variants(plan, barracks_node, barracks)
	var probe: Node3D = STAGE_PROBE.new()
	add_child(probe)
	probe.active_template = template.duplicate(true)
	probe.active_template.max_spatial_backtrack_depth = budget
	var result: Dictionary = probe._assemble_plan(plan)
	var placed := false
	var detail: Dictionary = {}
	for entry in probe.assembly_trace:
		if entry.get("id", &"") == barracks_node:
			detail = entry
			if entry.get("status", "") == "PLACED" and entry.get("definition", &"") == &"base_barracks":
				placed = true
	if bool(result.get("success", false)):
		var root_value: Variant = result.get("root", null)
		if root_value != null and is_instance_valid(root_value):
			(root_value as Node3D).free()
	probe.queue_free()
	return {"success": bool(result.get("success", false)), "placed": placed, "detail": detail, "stats": result.get("placement_stats", {})}


func _probe_all_destination_pairs(archetype_director: DungeonArchetypeDirector, sector_run: DungeonSectorRun, sector_index: int, template: DungeonTemplateResource, prison: SemanticLocationResource, barracks: SemanticLocationResource, semantic_seed: int) -> Array[String]:
	var raw := _build_raw_plan(archetype_director, sector_run, sector_index, template)
	raw.calculate_depths()
	var selector := SemanticLocationDirector.new()
	var prison_candidates: Array[StringName] = []
	for node_id in raw.module_ids:
		if selector._node_matches(raw, node_id, prison): prison_candidates.append(node_id)
	var solutions: Array[String] = []
	for prison_node in prison_candidates:
		var occupied := {prison_node: prison}
		for barracks_node in _barracks_candidates(raw, selector, barracks, occupied):
			var probe := _probe_assignment(archetype_director, sector_run, sector_index, template, prison, prison_node, barracks, barracks_node)
			if bool(probe.get("success", false)) and bool(probe.get("placed", false)):
				solutions.append("PRISON=%s BARRACKS=%s" % [prison_node, barracks_node])
	return solutions
