extends Node3D

## Diagnóstico 6K.4C Parte 1. No altera el kit ni la topología: verifica que
## cada apertura física declarada por un módulo tenga un conector y que, una
## vez ensamblado un sector, ninguna apertura quede expuesta al exterior.
const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const TEMPLATE := preload("res://resources/run/test_templates/TestHorvexNest.tres")
const ARCHETYPE := preload("res://resources/run/test_archetypes/HorvexNest.tres")

const FIRST_SEED := 66001
const LAST_SEED := 66020


func _ready() -> void:
	var isolated := _audit_isolated_kit()
	var bounds := _requested_bounds()
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 2
	dungeon.initial_seed = int(bounds.from)
	add_child(dungeon)
	while not dungeon.nav_ready and dungeon.assembly_error.is_empty():
		await get_tree().physics_frame
	var report := {"sectors": 0, "openings": 0, "retries": {0: 0, 1: 0, 2: 0}, "unpaired_openings": [], "capsule_failures": [], "nav_failures": [], "assembly_failures": [], "determinism": []}
	for seed in range(int(bounds.from), int(bounds.to) + 1):
		await dungeon.regenerate(seed)
		if not dungeon.assembly_valid or not dungeon.nav_ready:
			report.assembly_failures.append({"seed": seed, "sector": dungeon.current_sector_index, "error": dungeon.assembly_error})
			break
		while true:
			var sector_report := await _audit_live_sector(dungeon, seed)
			report.sectors += 1
			report.openings += int(sector_report.openings)
			var retry: int = dungeon.sector_retry_index
			report.retries[retry] = int(report.retries.get(retry, 0)) + 1
			for issue in sector_report.unpaired:
				report.unpaired_openings.append(issue)
			for issue in sector_report.capsule_failures:
				report.capsule_failures.append(issue)
			for issue in sector_report.nav_failures:
				report.nav_failures.append(issue)
			if dungeon.current_sector_index >= dungeon.sector_run.sector_count() - 1:
				break
			await dungeon.advance_sector_from_debug()
			if not dungeon.assembly_valid or not dungeon.nav_ready:
				report.assembly_failures.append({"seed": seed, "sector": dungeon.current_sector_index, "error": dungeon.assembly_error})
				break
		if not report.assembly_failures.is_empty():
			break
	if report.assembly_failures.is_empty() and int(bounds.from) == FIRST_SEED and int(bounds.to) == LAST_SEED:
		for seed in [66001, 66005]:
			report.determinism.append(await _validate_determinism(dungeon, seed))
	print("6K.4C Horvex containment sectors=%d openings=%d retries=%s isolated_failures=%d unpaired=%d capsule_failures=%d nav_failures=%d assembly_failures=%d determinism=%s" % [report.sectors, report.openings, report.retries, isolated.failures.size(), report.unpaired_openings.size(), report.capsule_failures.size(), report.nav_failures.size(), report.assembly_failures.size(), report.determinism.map(func(result: Dictionary) -> bool: return bool(result.valid))])
	var deterministic := true
	for result in report.determinism:
		deterministic = deterministic and bool(result.valid)
	if isolated.failures.is_empty() and report.assembly_failures.is_empty() and report.unpaired_openings.is_empty() and report.capsule_failures.is_empty() and report.nav_failures.is_empty() and deterministic:
		print("Stage6K4C Horvex containment diagnostic: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K4C Horvex containment diagnostic: FAIL")
		get_tree().quit(1)


func _audit_isolated_kit() -> Dictionary:
	var probe: Node3D = STAGE_SCRIPT.new()
	add_child(probe)
	var inventory: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	var definitions: Array[ModuleDefinitionResource] = []
	for definition: ModuleDefinitionResource in TEMPLATE.module_pool:
		if definition != null and not definitions.has(definition):
			definitions.append(definition)
	# Las piezas semánticas REQUIRED no pertenecen al pool de gramática: también
	# son parte del kit físico y deben pasar el mismo contrato aislado.
	for semantic: SemanticLocationResource in ARCHETYPE.semantic_locations:
		for definition: ModuleDefinitionResource in semantic.physical_module_variants:
			if definition != null and not definitions.has(definition):
				definitions.append(definition)
	for sector in ARCHETYPE.sectors:
		for semantic: SemanticLocationResource in sector.semantic_locations:
			for definition: ModuleDefinitionResource in semantic.physical_module_variants:
				if definition != null and not definitions.has(definition):
					definitions.append(definition)
	for definition: ModuleDefinitionResource in definitions:
		if definition == null:
			continue
		var role: StringName = definition.roles.front() if not definition.roles.is_empty() else &""
		for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
			var module: Node3D = probe._make_module(definition.stable_id, role, definition)
			module.rotation.y = yaw
			probe.add_child(module)
			var dimensions: Vector2 = module.get_meta("footprint_size", Vector2.ZERO)
			var entry := {"definition": definition.stable_id, "role": role, "yaw": yaw, "footprint": dimensions, "connectors": definition.connector_sides, "closed_sides": [], "failures": []}
			var floor := module.get_node_or_null("Floor") as CSGBox3D
			if floor == null or not floor.use_collision:
				entry.failures.append("floor collision missing")
			for side in [&"west", &"east", &"north", &"south"]:
				var connector: Marker3D = null
				for child: Node in module.get_children():
					if child is Marker3D and String(child.name).ends_with("_%s" % side):
						connector = child as Marker3D
						break
				var full_wall := module.get_node_or_null("Wall_%s" % side) as CSGBox3D
				var frames := 0
				for child in module.get_children():
					if String(child.name).begins_with("DoorFrame_%s_" % side):
						frames += 1
				if definition.connector_sides.has(side):
					if connector == null or frames != 2 or full_wall != null:
						entry.failures.append("connector contract %s" % side)
				else:
					entry.closed_sides.append(side)
					if connector != null or full_wall == null or not full_wall.use_collision:
						entry.failures.append("closed wall contract %s" % side)
			if not entry.failures.is_empty():
				failures.append(entry.duplicate(true))
			inventory.append(entry)
			module.free()
	probe.free()
	return {"inventory": inventory, "failures": failures}


func _audit_live_sector(dungeon: Node3D, seed: int) -> Dictionary:
	var connected: Dictionary = {}
	for seam in dungeon._seam_results:
		for key in [&"source", &"incoming"]:
			var marker: Marker3D = seam.get(key, null)
			if marker != null and is_instance_valid(marker):
				connected[marker.get_instance_id()] = true
	var unpaired: Array[Dictionary] = []
	var openings := 0
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	if root == null:
		return {"openings": 0, "unpaired": [{"seed": seed, "error": "missing AssembledModules"}], "capsule_failures": [], "nav_failures": []}
	for module: Node in root.get_children():
		if not module is Node3D:
			continue
		for child in module.get_children():
			if not child is Marker3D or not String(child.name).begins_with("Connector_"):
				continue
			openings += 1
			var side := StringName(String(child.name).trim_prefix("Connector_in_").trim_prefix("Connector_out_"))
			if connected.has(child.get_instance_id()):
				continue
			var full_wall := module.get_node_or_null("Wall_%s" % side)
			var frames := 0
			for sibling in module.get_children():
				if String(sibling.name).begins_with("DoorFrame_%s_" % side):
					frames += 1
			if full_wall == null and frames == 2:
				unpaired.append({
					"seed": seed, "sector": dungeon.current_sector_index,
					"retry": dungeon.sector_retry_index, "effective_seed": dungeon.sector_effective_seed,
					"node": module.name, "role": module.get_meta("module_kind", &""),
					"definition": dungeon.current_plan.module_definitions.get(StringName(module.name), null).stable_id if dungeon.current_plan.module_definitions.has(StringName(module.name)) else &"AUXILIARY",
					"side": side, "position": (child as Marker3D).global_position,
				})
	var capsule_failures: Array[Dictionary] = []
	for enclosure in dungeon.enclosure_results:
		if bool(enclosure.get("connected", false)):
			continue
		var connector: Marker3D = enclosure.get("connector", null)
		if connector == null or not is_instance_valid(connector) or not await _capsule_is_blocked(connector):
			capsule_failures.append({"seed": seed, "sector": dungeon.current_sector_index, "module": enclosure.get("module", &""), "side": enclosure.get("side", &"")})
	var nav_failures: Array[Dictionary] = []
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var target := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	if dungeon.current_sector_index >= dungeon.sector_run.sector_count() - 1:
		for location in dungeon.current_plan.semantic_locations:
			if location.definition.semantic_id == &"NEST_CORE":
				target = NavigationServer3D.map_get_closest_point(map, location.global_transform.origin)
				break
	if NavigationServer3D.map_get_path(map, start, target, true).size() < 2 or NavigationServer3D.map_get_path(map, target, start, true).size() < 2:
		nav_failures.append({"seed": seed, "sector": dungeon.current_sector_index, "start": start, "target": target})
	return {"openings": openings, "unpaired": unpaired, "capsule_failures": capsule_failures, "nav_failures": nav_failures}


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


func _validate_determinism(dungeon: Node3D, seed: int) -> Dictionary:
	await dungeon.regenerate(seed)
	while dungeon.current_sector_index < dungeon.sector_run.sector_count() - 1:
		await dungeon.advance_sector_from_debug()
	var first := {
		"plan": dungeon.current_plan.get_topology_signature(),
		"defs": str(dungeon.get_selected_module_definitions()),
		"assembly": dungeon._assembly_signature,
		"retry": dungeon.sector_retry_index,
		"effective_seed": dungeon.sector_effective_seed,
	}
	await dungeon.regenerate(seed)
	while dungeon.current_sector_index < dungeon.sector_run.sector_count() - 1:
		await dungeon.advance_sector_from_debug()
	var second := {
		"plan": dungeon.current_plan.get_topology_signature(),
		"defs": str(dungeon.get_selected_module_definitions()),
		"assembly": dungeon._assembly_signature,
		"retry": dungeon.sector_retry_index,
		"effective_seed": dungeon.sector_effective_seed,
	}
	return {"seed": seed, "valid": dungeon.assembly_valid and dungeon.nav_ready and first == second, "first": first, "second": second}


func _requested_bounds() -> Dictionary:
	var bounds := {"from": FIRST_SEED, "to": LAST_SEED}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--containment-from="):
			bounds.from = clampi(int(arg.trim_prefix("--containment-from=")), FIRST_SEED, LAST_SEED)
		elif arg.begins_with("--containment-to="):
			bounds.to = clampi(int(arg.trim_prefix("--containment-to=")), int(bounds.from), LAST_SEED)
	return bounds
