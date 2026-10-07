extends Node3D

## Gate físico específico de Varkhem V2. Consume Stage6G real: no reproduce
## assembly, seams, containment, navegación ni transiciones.
const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")

const DEFAULT_FIRST_SEED := 65001
const DEFAULT_LAST_SEED := 65020


func _ready() -> void:
	var first_seed := DEFAULT_FIRST_SEED
	var last_seed := DEFAULT_LAST_SEED
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		first_seed = int(args[0])
		last_seed = int(args[1])
	var dungeon: Node3D = STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = first_seed
	add_child(dungeon)
	await _await_sector(dungeon)
	var report := {
		"runs": 0, "sectors": 0, "failures": [], "openings": 0,
		"containment": [], "capsule": [], "floor": [], "seams": [], "nav": [], "transitions": [],
		"required_variants": [], "max_backtracks": 0, "attempts": {}, "determinism": [],
	}
	for seed in range(first_seed, last_seed + 1):
		await dungeon.regenerate(seed)
		await _await_sector(dungeon)
		var run_valid := true
		for sector_index in range(dungeon.sector_run.sector_count()):
			report.sectors += 1
			if not dungeon.assembly_valid or not dungeon.nav_ready:
				report.failures.append("seed=%d sector=%d error=%s topology=%s" % [seed, sector_index, dungeon.assembly_error, dungeon.current_plan.get_topology_signature() if dungeon.current_plan != null else "NULL"])
				run_valid = false
				break
			var sector := await _audit_sector(dungeon, seed)
			report.openings += int(sector.openings)
			report.containment.append_array(sector.containment)
			report.capsule.append_array(sector.capsule)
			report.floor.append_array(sector.floor)
			report.seams.append_array(sector.seams)
			report.nav.append_array(sector.nav)
			report.transitions.append_array(_transition_errors(dungeon, seed, sector_index))
			report.required_variants.append_array(_required_variant_errors(dungeon, seed, sector_index))
			report.max_backtracks = maxi(int(report.max_backtracks), int(dungeon.placement_stats.get("backtracks", 0)))
			var attempt := int(dungeon.sector_retry_index)
			report.attempts[attempt] = int(report.attempts.get(attempt, 0)) + 1
			if sector_index < dungeon.sector_run.sector_count() - 1:
				await dungeon.advance_sector_from_debug()
				await _await_sector(dungeon)
		if run_valid:
			report.runs += 1
	for seed in [65001, 65015, 65020]:
		report.determinism.append(await _determinism(dungeon, seed))
	var deterministic: bool = report.determinism.all(func(entry: Dictionary) -> bool: return bool(entry.valid))
	print("6K.4 Varkhem V2 physical report=%s" % report)
	var passed: bool = report.runs == last_seed - first_seed + 1 and report.failures.is_empty() and report.containment.is_empty() and report.capsule.is_empty() and report.floor.is_empty() and report.seams.is_empty() and report.nav.is_empty() and report.transitions.is_empty() and report.required_variants.is_empty() and deterministic
	if passed:
		print("Stage6K.4 Varkhem Architecture V2 physical: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4 Varkhem Architecture V2 physical: FAIL")
		get_tree().quit(1)


func _await_sector(dungeon: Node3D) -> void:
	for _frame in 900:
		if dungeon.nav_ready or not dungeon.assembly_error.is_empty():
			return
		await get_tree().physics_frame


func _audit_sector(dungeon: Node3D, seed: int) -> Dictionary:
	var result := {"openings": 0, "containment": [], "capsule": [], "floor": [], "seams": [], "nav": []}
	if not dungeon._validate_walkable_containment():
		result.containment.append("seed=%d sector=%d" % [seed, dungeon.current_sector_index])
	if not dungeon._validate_physical_seams():
		result.seams.append("seed=%d sector=%d" % [seed, dungeon.current_sector_index])
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	if root == null:
		result.floor.append("seed=%d sector=%d missing-root" % [seed, dungeon.current_sector_index])
		return result
	for module in root.get_children():
		if not module is Node3D:
			continue
		var floor := module.get_node_or_null("Floor") as CSGBox3D
		if floor == null or not floor.use_collision:
			result.floor.append("seed=%d sector=%d module=%s" % [seed, dungeon.current_sector_index, module.name])
	for enclosure in dungeon.enclosure_results:
		if bool(enclosure.get("connected", false)):
			continue
		result.openings += 1
		var connector: Marker3D = enclosure.get("connector", null)
		if connector == null or not is_instance_valid(connector) or not await _capsule_is_blocked(connector):
			result.capsule.append("seed=%d sector=%d module=%s side=%s" % [seed, dungeon.current_sector_index, enclosure.get("module", &""), enclosure.get("side", &"")])
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var finish := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	if NavigationServer3D.map_get_path(map, start, finish, true).size() < 2 or NavigationServer3D.map_get_path(map, finish, start, true).size() < 2:
		result.nav.append("seed=%d sector=%d" % [seed, dungeon.current_sector_index])
	return result


func _capsule_is_blocked(connector: Marker3D) -> bool:
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	add_child(body)
	var outward := -connector.global_transform.basis.z.normalized()
	body.global_position = Vector3(connector.global_position.x - outward.x * 0.65, 0.9, connector.global_position.z - outward.z * 0.65)
	await get_tree().physics_frame
	var hit := body.move_and_collide(outward * 1.6)
	body.queue_free()
	return hit != null


func _transition_errors(dungeon: Node3D, seed: int, sector: int) -> Array[String]:
	var roots := 0
	var regions := 0
	for child in dungeon.get_children():
		if child.name == &"AssembledModules": roots += 1
		if child is NavigationRegion3D: regions += 1
	if roots == 1 and regions == 1:
		return []
	return ["seed=%d sector=%d roots=%d nav_regions=%d" % [seed, sector, roots, regions]]


func _required_variant_errors(dungeon: Node3D, seed: int, sector: int) -> Array[String]:
	var result: Array[String] = []
	var selected: Dictionary = dungeon.get_selected_module_definitions()
	for location in dungeon.current_plan.semantic_locations:
		var definition: SemanticLocationResource = location.definition
		if not definition.physical_variant_required or definition.physical_module_variants.is_empty():
			continue
		var actual: StringName = selected.get(location.node_id, &"")
		var expected: ModuleDefinitionResource = definition.physical_module_variants[0]
		if expected == null or actual != expected.stable_id:
			result.append("seed=%d sector=%d semantic=%s node=%s expected=%s actual=%s" % [seed, sector, definition.semantic_id, location.node_id, expected.stable_id if expected != null else &"NONE", actual])
	return result


func _determinism(dungeon: Node3D, seed: int) -> Dictionary:
	var signatures: Array[Dictionary] = []
	for _attempt in 2:
		await dungeon.regenerate(seed)
		await _await_sector(dungeon)
		var sectors: Array[String] = []
		while true:
			if not dungeon.assembly_valid or not dungeon.nav_ready:
				return {"seed": seed, "valid": false, "error": dungeon.assembly_error}
			sectors.append("%s|%s|%s" % [dungeon.current_plan.get_topology_signature(), dungeon.get_assembly_signature(), dungeon.get_selected_module_definitions()])
			if dungeon.current_sector_index >= dungeon.sector_run.sector_count() - 1:
				break
			await dungeon.advance_sector_from_debug()
			await _await_sector(dungeon)
		signatures.append({"sectors": sectors})
	return {"seed": seed, "valid": signatures.size() == 2 and signatures[0] == signatures[1]}
