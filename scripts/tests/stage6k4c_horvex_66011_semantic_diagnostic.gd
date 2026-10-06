extends Node3D

## Diagnóstico offline 6K.4C Parte 2.3. No modifica Resources productivos,
## no promueve un retry y ejecuta el assembler real sobre copias del mismo
## DungeonPlan congelado para separar contrato semántico, footprint y budget.
const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const ARCHETYPE := preload("res://resources/run/test_archetypes/HorvexNest.tres")
const CORE_ID := &"nest_core_chamber"
const DEPTHS := [2, 3, 4, 6, 8]


func _ready() -> void:
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 2
	dungeon.initial_seed = 66011
	add_child(dungeon)
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	await dungeon.advance_sector_from_debug()
	if not dungeon.assembly_valid or not dungeon.nav_ready:
		_fail("unexpected failure before CORE_NEST: %s" % dungeon.assembly_error)
		return
	await dungeon.advance_sector_from_debug()
	var frozen: DungeonPlan = dungeon.current_plan
	if frozen == null or dungeon.assembly_valid:
		_fail("expected frozen semantic failure, assembly=%s" % dungeon.assembly_valid)
		return
	var candidates := _core_candidates(frozen)
	var inventory := _inventory(frozen, candidates)
	var baseline := _probe_baseline(dungeon, frozen, 2)
	var depth_two: Array[Dictionary] = []
	for node_id in candidates:
		depth_two.append(_probe(dungeon, frozen, node_id, 2, Vector2(14, 12)))
	var deep: Array[Dictionary] = []
	for node_id in candidates:
		var solved := false
		for budget in DEPTHS.slice(1):
			var result := _probe(dungeon, frozen, node_id, int(budget), Vector2(14, 12))
			deep.append(result)
			if bool(result.get("success", false)):
				solved = true
				break
		if not solved:
			deep.append({"node": node_id, "depth": -1, "success": false, "summary": "no solution through depth 8"})
	var footprint_tests: Array[Dictionary] = []
	for footprint in [Vector2(12, 12), Vector2(12, 10)]:
		for node_id in candidates:
			footprint_tests.append(_probe(dungeon, frozen, node_id, 2, footprint))
	print("6K.4C 66011 BASELINE=" + str(baseline))
	print("6K.4C 66011 CORE INVENTORY=" + str(inventory))
	print("6K.4C 66011 CORE DEPTH2_SUMMARY=" + str(_compact(depth_two)))
	print("6K.4C 66011 CORE DEEP_SUMMARY=" + str(_compact(deep)))
	print("6K.4C 66011 CORE FOOTPRINT_SUMMARY=" + str(_compact(footprint_tests)))
	get_tree().quit(0)


func _core_candidates(plan: DungeonPlan) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in plan.semantic_feasibility:
		if entry.get("semantic_id", &"") != &"NEST_CORE":
			continue
		var node_id: StringName = entry.get("node_id", &"")
		if node_id != &"" and not result.has(node_id):
			result.append(node_id)
	return result


func _inventory(plan: DungeonPlan, candidates: Array[StringName]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node_id in plan.module_ids:
		var semantics: Array[StringName] = []
		for location in plan.semantic_locations:
			if location.node_id == node_id:
				semantics.append(location.definition.semantic_id)
		result.append({"id": node_id, "role": plan.module_types.get(node_id, &""), "depth": plan.node_depths.get(node_id, -1), "parent": _parent_of(plan, node_id), "children": plan.links.get(node_id, []), "main": plan.main_path_nodes.has(node_id), "branch": plan.branch_nodes.has(node_id), "semantic": semantics, "core_candidate": candidates.has(node_id)})
	return result


func _parent_of(plan: DungeonPlan, node_id: StringName) -> StringName:
	for parent_variant in plan.links:
		if (plan.links[parent_variant] as Array).has(node_id): return parent_variant
	return &""


func _probe(dungeon: Node3D, frozen: DungeonPlan, node_id: StringName, budget: int, footprint: Vector2) -> Dictionary:
	var plan := frozen.duplicate_for_assembly_probe()
	plan.semantic_error = ""
	var core: ModuleDefinitionResource = _core_definition().duplicate(true)
	core.footprint_size = footprint
	plan.module_definition_variants[node_id] = [core]
	var original_budget: int = dungeon.active_template.max_spatial_backtrack_depth
	dungeon.active_template.max_spatial_backtrack_depth = budget
	var started := Time.get_ticks_msec()
	var assembly: Dictionary = dungeon._assemble_plan(plan)
	var elapsed := Time.get_ticks_msec() - started
	dungeon.active_template.max_spatial_backtrack_depth = original_budget
	var trace: Array = dungeon.assembly_trace.duplicate(true)
	var stats: Dictionary = assembly.get("placement_stats", {}).duplicate(true)
	var core_trace := _find_core_trace(trace, node_id)
	var result := {"node": node_id, "depth": budget, "footprint": footprint, "success": bool(assembly.get("success", false)), "error": str(assembly.get("error", "")), "elapsed_ms": elapsed, "candidate_checks": stats.get("candidate_checks", 0), "backtracks": stats.get("backtracks", 0), "backtrack_nodes": stats.get("backtrack_nodes", []), "core_transform": core_trace.get("transform", Transform3D.IDENTITY), "core_bounds": core_trace.get("bounds", AABB()), "core_seam": core_trace.get("seam_valid", false), "core_conflicts": core_trace.get("conflicts", [])}
	# _assemble_plan libera por sí mismo las raíces de FAIL. Sólo un PASS deja
	# un root vivo que esta prueba debe retirar para no contaminar la siguiente.
	if bool(assembly.get("success", false)):
		var root: Variant = assembly.get("root", null)
		if root != null and is_instance_valid(root):
			if root.get_parent() != null: root.get_parent().remove_child(root)
			root.free()
	return result


func _probe_baseline(dungeon: Node3D, frozen: DungeonPlan, budget: int) -> Dictionary:
	var plan := frozen.duplicate_for_assembly_probe()
	plan.semantic_error = ""
	var original_budget: int = dungeon.active_template.max_spatial_backtrack_depth
	dungeon.active_template.max_spatial_backtrack_depth = budget
	var started := Time.get_ticks_msec()
	var assembly: Dictionary = dungeon._assemble_plan(plan)
	var elapsed := Time.get_ticks_msec() - started
	dungeon.active_template.max_spatial_backtrack_depth = original_budget
	var stats: Dictionary = assembly.get("placement_stats", {}).duplicate(true)
	var result := {"success": bool(assembly.get("success", false)), "error": str(assembly.get("error", "")), "elapsed_ms": elapsed, "candidate_checks": stats.get("candidate_checks", 0), "backtracks": stats.get("backtracks", 0), "backtrack_nodes": stats.get("backtrack_nodes", [])}
	if bool(assembly.get("success", false)):
		var root: Variant = assembly.get("root", null)
		if root != null and is_instance_valid(root):
			if root.get_parent() != null: root.get_parent().remove_child(root)
			root.free()
	return result


func _core_definition() -> ModuleDefinitionResource:
	for semantic in ARCHETYPE.semantic_locations:
		if semantic.semantic_id == &"NEST_CORE": return semantic.physical_module_variants.front()
	return null


func _find_core_trace(trace: Array, node_id: StringName) -> Dictionary:
	for entry_variant in trace:
		var entry: Dictionary = entry_variant
		if entry.get("id", &"") == node_id and entry.get("definition", &"") == CORE_ID: return entry
	return {}


func _compact(results: Array[Dictionary]) -> Array[String]:
	var output: Array[String] = []
	for result in results:
		output.append("%s d=%s fp=%s pass=%s checks=%s backtracks=%s error=%s" % [result.get("node", &""), result.get("depth", -1), result.get("footprint", ""), result.get("success", false), result.get("candidate_checks", 0), result.get("backtracks", 0), result.get("error", result.get("summary", ""))])
	return output


func _fail(message: String) -> void:
	push_error("6K.4C 66011 diagnostic failed: %s" % message)
	get_tree().quit(1)
