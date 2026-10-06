extends Node3D

## Validates the data-driven containment contract newly enabled for Varkhem.
## It deliberately consumes the prototype's real enclosure/seam data rather
## than reproducing placement, collision or navigation logic.
const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const TEMPLATE := preload("res://resources/run/test_templates/TestVarkhemBaseSemantic.tres")
const HORVEX_TEMPLATE := preload("res://resources/run/test_templates/TestHorvexNest.tres")

const FIRST_SEED := 65001
const LAST_SEED := 65020


func _ready() -> void:
	var forced_template := ResourceLoader.load("res://resources/run/test_templates/TestVarkhemBaseSemantic.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as DungeonTemplateResource
	var duplicated_template := TEMPLATE.duplicate(true) as DungeonTemplateResource
	var duplicated_horvex := HORVEX_TEMPLATE.duplicate(true) as DungeonTemplateResource
	print("6K.4B containment trace disk_text=true varkhem_preload=%s varkhem_load_ignore_cache=%s varkhem_duplicate=%s horvex_preload=%s horvex_duplicate=%s" % [TEMPLATE.enforce_walkable_containment, forced_template.enforce_walkable_containment if forced_template != null else false, duplicated_template.enforce_walkable_containment if duplicated_template != null else false, HORVEX_TEMPLATE.enforce_walkable_containment, duplicated_horvex.enforce_walkable_containment if duplicated_horvex != null else false])
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = FIRST_SEED
	add_child(dungeon)
	while not dungeon.nav_ready and dungeon.assembly_error.is_empty():
		await get_tree().physics_frame
	print("6K.4B active template=%s containment=%s" % [
		dungeon.active_template.stable_id if dungeon.active_template != null else &"",
		dungeon.active_template.enforce_walkable_containment if dungeon.active_template != null else false,
	])
	var report := {"runs": 0, "sectors": 0, "openings": 0, "unpaired": [], "capsule": [], "floor": [], "nav": [], "assembly": [], "semantic_65015": [], "determinism": []}
	if not TEMPLATE.enforce_walkable_containment:
		report.assembly.append({"error": "enforce_walkable_containment is false"})
	for seed in range(FIRST_SEED, LAST_SEED + 1):
		await dungeon.regenerate(seed)
		while true:
			if not dungeon.assembly_valid or not dungeon.nav_ready:
				report.assembly.append({"seed": seed, "sector": dungeon.current_sector_index, "error": dungeon.assembly_error})
				break
			var sector_result := await _audit_sector(dungeon, seed)
			report.sectors += 1
			report.openings += int(sector_result.openings)
			report.unpaired.append_array(sector_result.unpaired)
			report.capsule.append_array(sector_result.capsule)
			report.floor.append_array(sector_result.floor)
			report.nav.append_array(sector_result.nav)
			if seed == 65015 and dungeon.sector_run.get_sector(dungeon.current_sector_index).sector_id == &"BASEMENT":
				report.semantic_65015.append(_semantic_snapshot(dungeon.current_plan))
			if dungeon.current_sector_index >= dungeon.sector_run.sector_count() - 1:
				break
			await dungeon.advance_sector_from_debug()
		if not report.assembly.is_empty():
			break
		report.runs += 1
	if report.assembly.is_empty():
		for seed in [65001, 65003, 65015]:
			report.determinism.append(await _validate_determinism(dungeon, seed))
	var semantics_ok: bool = report.semantic_65015.has(["BARRACKS@NODE_6", "PRISON@SIDE_NODE_2"])
	var deterministic := true
	for entry: Dictionary in report.determinism:
		deterministic = deterministic and bool(entry.valid)
	print("6K.4B Varkhem containment runs=%d sectors=%d openings=%d unpaired=%d capsule=%d floor=%d nav=%d assembly=%d semantics65015=%s determinism=%s" % [report.runs, report.sectors, report.openings, report.unpaired.size(), report.capsule.size(), report.floor.size(), report.nav.size(), report.assembly.size(), report.semantic_65015, report.determinism.map(func(entry: Dictionary) -> bool: return bool(entry.valid))])
	if not report.unpaired.is_empty() or not report.assembly.is_empty():
		print("6K.4B Varkhem containment diagnostics unpaired=%s assembly=%s" % [report.unpaired, report.assembly])
	if report.runs == 20 and report.unpaired.is_empty() and report.capsule.is_empty() and report.floor.is_empty() and report.nav.is_empty() and report.assembly.is_empty() and semantics_ok and deterministic:
		print("Stage6K4B Varkhem containment: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K4B Varkhem containment: FAIL")
		get_tree().quit(1)


func _audit_sector(dungeon: Node3D, seed: int) -> Dictionary:
	# enclosure_results is the authoritative result of the production sealing
	# pass. A seam list alone cannot distinguish a consumed connector from one
	# intentionally closed after placement.
	var enclosure_by_connector: Dictionary = {}
	for enclosure in dungeon.enclosure_results:
		var enclosure_connector: Marker3D = enclosure.get("connector", null)
		if enclosure_connector != null and is_instance_valid(enclosure_connector):
			enclosure_by_connector[enclosure_connector.get_instance_id()] = enclosure
	var result := {"openings": 0, "unpaired": [], "capsule": [], "floor": [], "nav": []}
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	if root == null:
		result.unpaired.append({"seed": seed, "error": "missing assembled modules"})
		return result
	if dungeon.enclosure_results.is_empty():
		result.unpaired.append({"seed": seed, "sector": dungeon.current_sector_index, "error": "containment audit missing", "template": dungeon.active_template.stable_id if dungeon.active_template != null else &"", "enabled": dungeon.active_template.enforce_walkable_containment if dungeon.active_template != null else false})
		return result
	for module in root.get_children():
		if not module is Node3D:
			continue
		var floor := module.get_node_or_null("Floor") as CSGBox3D
		if floor == null or not floor.use_collision:
			result.floor.append({"seed": seed, "sector": dungeon.current_sector_index, "module": module.name})
		for child in module.get_children():
			if not child is Marker3D or not String(child.name).begins_with("Connector_"):
				continue
			result.openings += 1
			var side := StringName(String(child.name).trim_prefix("Connector_in_").trim_prefix("Connector_out_"))
			var enclosure: Dictionary = enclosure_by_connector.get(child.get_instance_id(), {})
			if bool(enclosure.get("connected", false)):
				continue
			var full_wall := module.get_node_or_null("Wall_%s" % side)
			var frames := 0
			for sibling in module.get_children():
				if String(sibling.name).begins_with("DoorFrame_%s_" % side):
					frames += 1
			if not bool(enclosure.get("sealed", false)) or full_wall == null or frames != 0:
				result.unpaired.append({"seed": seed, "sector": dungeon.current_sector_index, "module": module.name, "side": side})
	for enclosure in dungeon.enclosure_results:
		if bool(enclosure.get("connected", false)):
			continue
		var connector: Marker3D = enclosure.get("connector", null)
		if connector == null or not is_instance_valid(connector) or not await _capsule_is_blocked(connector):
			result.capsule.append({"seed": seed, "sector": dungeon.current_sector_index, "module": enclosure.get("module", &""), "side": enclosure.get("side", &"")})
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var finish := NavigationServer3D.map_get_closest_point(map, dungeon.exit_point)
	if NavigationServer3D.map_get_path(map, start, finish, true).size() < 2 or NavigationServer3D.map_get_path(map, finish, start, true).size() < 2:
		result.nav.append({"seed": seed, "sector": dungeon.current_sector_index})
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


func _semantic_snapshot(plan: DungeonPlan) -> Array[String]:
	var result: Array[String] = []
	for location in plan.semantic_locations:
		if location.definition.semantic_id in [&"PRISON", &"BARRACKS"]:
			result.append("%s@%s" % [location.definition.semantic_id, location.node_id])
	result.sort()
	return result


func _validate_determinism(dungeon: Node3D, seed: int) -> Dictionary:
	await dungeon.regenerate(seed)
	while dungeon.current_sector_index < dungeon.sector_run.sector_count() - 1:
		await dungeon.advance_sector_from_debug()
	var first := {"plan": dungeon.current_plan.get_topology_signature(), "assembly": dungeon.get_assembly_signature(), "definitions": str(dungeon.get_selected_module_definitions())}
	await dungeon.regenerate(seed)
	while dungeon.current_sector_index < dungeon.sector_run.sector_count() - 1:
		await dungeon.advance_sector_from_debug()
	var second := {"plan": dungeon.current_plan.get_topology_signature(), "assembly": dungeon.get_assembly_signature(), "definitions": str(dungeon.get_selected_module_definitions())}
	return {"seed": seed, "valid": dungeon.assembly_valid and dungeon.nav_ready and first == second}
