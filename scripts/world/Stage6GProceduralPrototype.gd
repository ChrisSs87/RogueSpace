extends Node3D

## Prototipo 6G aislado. Consume DungeonPlan (6F), interpreta sus variantes
## mediante conectores físicos y reutiliza B+C para producir una sola región.
const GROUP := &"stage6g_nav_source"
const LAYER := 32
const DIRECTOR := preload("res://scripts/world/RunDirector.gd")
const ARCHETYPE_DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const CONTENT_DIRECTOR := preload("res://scripts/world/ContentPlacementDirector.gd")
const CONTENT_RUNTIME_CONSUMER := preload("res://scripts/world/ContentPlacementRuntimeConsumer.gd")
const TEMPLATE := preload("res://resources/run/DungeonTemplateResource.gd")
const TEST_TEMPLATE_A := preload("res://resources/run/test_templates/TestCorridorHeavy.tres")
const TEST_TEMPLATE_B := preload("res://resources/run/test_templates/TestRoomBranchHeavy.tres")
const TEST_ARCHETYPE_SHIP := preload("res://resources/run/test_archetypes/AbandonedShip.tres")
const TEST_ARCHETYPE_VARKHEM := preload("res://resources/run/test_archetypes/VarkhemBase.tres")
const TEST_ARCHETYPE_HORVEX := preload("res://resources/run/test_archetypes/HorvexNest.tres")
const TEST_CONTENT_PROFILE_A := preload("res://resources/run/test_content_profiles/TestCombatHeavy.tres")
const TEST_CONTENT_PROFILE_B := preload("res://resources/run/test_content_profiles/TestExploration.tres")
const TILE_SIZE := 8.0
const DOOR_WIDTH := 2.4
const DOOR_HEIGHT := 2.0

@export var initial_seed := 61001
@export_range(0, 1) var test_template_index := 0
@export_range(0, 1) var test_content_profile_index := 0
## Sólo Stage6J activa este modo. Stage6G/6H conserva sus templates directos.
@export var archetype_mode := false
@export_range(0, 2) var test_archetype_index := 0
var seed := 0
var nav_ready := false
var nav_sync_state := "IDLE"
var nav_sync_attempts := 0
var nav_sync_cycles := 0
var assembly_valid := false
var proxies := 0
var module_count := 0
var nav_mesh: NavigationMesh
var nav_region: NavigationRegion3D
var start_point := Vector3(0, 0.9, 0)
var exit_point := Vector3(0, 0.9, 0)
var current_plan: DungeonPlan
var current_content_plan: ContentPlacementPlan
var current_content_profile: ContentPlacementProfileResource
var current_runtime_content_report: Dictionary = {}
var assembly_error := ""
var _assembly_signature := ""
var _topology_signature := ""
var _seam_results: Array[Dictionary] = []
## Contrato 6K.4C: una apertura declarada que no llega a usar un seam debe
## cerrarse físicamente antes del bake. Es telemetría de containment, no una
## segunda topología ni una modificación del DungeonPlan.
var enclosure_results: Array[Dictionary] = []
var enclosure_valid := false
# Telemetría read-only para el diagnóstico B+C de 6G.2. No participa en el
# assembly ni modifica el resultado del bake.
var bake_source_vertex_count := 0
var bake_source_index_count := 0
var bake_source_bounds := AABB()
var bake_proxy_reports: Array[Dictionary] = []
var active_template: DungeonTemplateResource
var placement_stats: Dictionary = {}
# Traza read-only para diagnóstico de placement 6H; no altera la selección ni
# el criterio de overlap del assembler.
var assembly_trace: Array[Dictionary] = []
var active_archetype: DungeonArchetypeResource
var sector_run: DungeonSectorRun
var current_sector_index := 0
var transition_slot: DungeonTransitionSlot
var sector_completion_count := 0
var dungeon_completion_count := 0
## Telemetría del intento físico finalmente elegido para el sector activo.
## No participa de la lógica ni del placement; permite reproducir una run.
var sector_retry_index := 0
var sector_effective_seed := 0
var sector_generation_attempts := 0
## Historial del intento de sector actual; telemetría para distinguir retry
## físico base de rechazos de candidatos REQUIRED sin persistir probes.
var sector_attempt_reports: Array[Dictionary] = []
## Telemetría de ensamblaje; excluye bake/sincronización y no influye en rutas.
var assembly_elapsed_ms := 0


func _ready() -> void:
	await regenerate(initial_seed)


func regenerate_from_debug() -> void:
	await regenerate(seed + 1)


func toggle_archetype_from_debug() -> void:
	if not archetype_mode:
		return
	test_archetype_index = (test_archetype_index + 1) % 3
	await regenerate(seed)


func advance_sector_from_debug() -> void:
	if not archetype_mode or sector_run == null:
		return
	if current_sector_index >= sector_run.sector_count() - 1:
		dungeon_completion_count += 1
		_update_debug()
		return
	sector_run.completed_sectors[current_sector_index] = true
	sector_completion_count += 1
	current_sector_index += 1
	await _regenerate_current_sector()


func toggle_template_from_debug() -> void:
	test_template_index = (test_template_index + 1) % 2
	await regenerate(seed)


func toggle_content_profile_from_debug() -> void:
	test_content_profile_index = (test_content_profile_index + 1) % 2
	_rebuild_content_placement()


func get_active_template_id() -> StringName:
	return active_template.stable_id if active_template != null else &""


func get_active_content_profile_id() -> StringName:
	var profile := _active_content_profile()
	return profile.stable_id


func regenerate(requested_seed: int) -> void:
	seed = requested_seed
	current_sector_index = 0
	transition_slot = null
	if archetype_mode:
		active_archetype = _selected_archetype()
		var archetype_director: DungeonArchetypeDirector = ARCHETYPE_DIRECTOR.new()
		sector_run = archetype_director.create_sector_run(active_archetype, seed)
	else:
		active_archetype = null
		sector_run = null
	await _regenerate_current_sector()


func _regenerate_current_sector() -> void:
	nav_ready = false
	nav_sync_state = "SYNCING"
	nav_sync_attempts = 0
	nav_sync_cycles += 1
	assembly_valid = false
	assembly_error = ""
	sector_retry_index = 0
	sector_effective_seed = 0
	sector_generation_attempts = 0
	sector_attempt_reports.clear()
	assembly_elapsed_ms = 0
	await _clear_previous_assembly()
	var started := Time.get_ticks_msec()
	var assembly: Dictionary = {}
	if archetype_mode:
		var archetype_director: DungeonArchetypeDirector = ARCHETYPE_DIRECTOR.new()
		active_template = archetype_director.get_sector_template(sector_run, current_sector_index)
		var max_attempts := maxi(1, active_template.max_physical_sector_attempts if active_template != null else 1)
		for retry_index in range(max_attempts):
			sector_generation_attempts += 1
			var candidate_plan := archetype_director.build_sector_plan_attempt(sector_run, current_sector_index, retry_index, Callable(self, "_probe_required_semantic_feasibility"))
			var effective_seed := archetype_director.get_sector_effective_seed(sector_run, current_sector_index, retry_index)
			if candidate_plan == null or not candidate_plan.is_valid():
				current_plan = candidate_plan
				if candidate_plan != null and candidate_plan.required_feasibility_status == &"BASE_PHYSICAL_FAILURE":
					assembly = {"success": false, "error": "BASE_PHYSICAL_FAILURE: %s" % candidate_plan.required_feasibility_error}
					sector_attempt_reports.append({"attempt": retry_index, "effective_seed": effective_seed, "status": &"BASE_PHYSICAL_FAILURE", "error": candidate_plan.required_feasibility_error, "semantic_feasibility": candidate_plan.semantic_feasibility.duplicate(true)})
					if retry_index + 1 < max_attempts:
						print("6K SECTOR RETRY archetype=%s sector=%d attempt=%d effective_seed=%d error=%s" % [active_archetype.archetype_id, current_sector_index, retry_index, effective_seed, assembly.error])
						continue
				else:
					assembly = {"success": false, "error": "logical/semantic sector plan invalid on attempt %d" % retry_index}
				break
			current_plan = candidate_plan
			assembly = _assemble_plan(candidate_plan)
			if bool(assembly.get("success", false)):
				sector_attempt_reports.append({"attempt": retry_index, "effective_seed": effective_seed, "status": &"ASSEMBLY_OK", "semantic_feasibility": candidate_plan.semantic_feasibility.duplicate(true)})
				sector_retry_index = retry_index
				sector_effective_seed = effective_seed
				sector_run.record_effective_sector_attempt(current_sector_index, retry_index, effective_seed, candidate_plan)
				break
			var physical_error := str(assembly.get("error", "unknown assembly error"))
			sector_attempt_reports.append({"attempt": retry_index, "effective_seed": effective_seed, "status": &"ASSEMBLY_PHYSICAL_FAILURE", "error": physical_error, "semantic_feasibility": candidate_plan.semantic_feasibility.duplicate(true)})
			if not _is_retryable_physical_assembly_error(physical_error):
				break
			print("6K SECTOR RETRY archetype=%s sector=%d attempt=%d effective_seed=%d error=%s" % [active_archetype.archetype_id, current_sector_index, retry_index, effective_seed, physical_error])
	else:
		current_plan = _build_seeded_plan(seed)
		assembly = _assemble_plan(current_plan)
		sector_generation_attempts = 1
	assembly_valid = bool(assembly.get("success", false))
	assembly_elapsed_ms = Time.get_ticks_msec() - started
	if not assembly_valid:
		assembly_error = str(assembly.get("error", "unknown assembly error"))
		_update_debug()
		push_error("6G assembly failed: %s" % assembly_error)
		return
	var root: Node3D = assembly.root
	module_count = int(assembly.module_count)
	start_point = assembly.start_point
	exit_point = assembly.exit_point
	_assembly_signature = str(assembly.signature)
	_topology_signature = str(assembly.topology_signature)
	_seam_results = assembly.seams
	_build_transition_slot()
	_rebuild_semantic_location_debug(root)
	_rebuild_content_placement()
	_update_debug()
	await get_tree().physics_frame
	if not _validate_physical_seams():
		assembly_valid = false
		assembly_error = "physical seam blocked"
		_update_debug()
		push_error("6G assembly failed: %s" % assembly_error)
		return
	if active_template != null and active_template.enforce_walkable_containment and not _validate_walkable_containment():
		assembly_valid = false
		assembly_error = "walkable containment failed"
		_update_debug()
		push_error("6G assembly failed: %s" % assembly_error)
		return
	await _bake(root)
	nav_ready = await _await_navigation_ready()
	nav_sync_state = "OK" if nav_ready else "FAIL"
	if nav_ready:
		_validate_runtime_content_navigation()
	_reposition_player()
	_update_debug()
	print("6G ASSEMBLY seed=%d sector_retry=%d effective_sector_seed=%d modules=%d proxies=%d vertices=%d polygons=%d valid=%s nav=%s ms=%d signature=%s" % [seed, sector_retry_index, sector_effective_seed, module_count, proxies, nav_mesh.vertices.size() if nav_mesh != null else 0, nav_mesh.get_polygon_count() if nav_mesh != null else 0, assembly_valid, nav_ready, Time.get_ticks_msec() - started, _assembly_signature])


func _build_seeded_plan(run_seed: int) -> DungeonPlan:
	if archetype_mode:
		var archetype_director: DungeonArchetypeDirector = ARCHETYPE_DIRECTOR.new()
		active_template = archetype_director.get_sector_template(sector_run, current_sector_index)
		return archetype_director.build_sector_plan(sector_run, current_sector_index)
	active_template = TEST_TEMPLATE_A if test_template_index == 0 else TEST_TEMPLATE_B
	var director: RunDirector = DIRECTOR.new()
	director.seed = run_seed
	director.current_node_id = &"STAGE6G_PROTOTYPE"
	return director.build_plan(active_template)


## Consulta acotada usada únicamente durante la asignación de una semantic
## REQUIRED. Reutiliza el assembler real sobre una copia profunda del plan:
## no genera proxies/NavMesh, no toca RunState y restaura toda telemetría del
## assembly activo antes de devolver el resultado.
func _probe_required_semantic_feasibility(candidate_plan: DungeonPlan) -> Dictionary:
	if candidate_plan == null:
		return {"success": false, "error": "missing candidate plan"}
	var started := Time.get_ticks_msec()
	var trace_before := assembly_trace.duplicate(true)
	var stats_before := placement_stats.duplicate(true)
	var plan_probe := candidate_plan.duplicate_for_assembly_probe()
	var result := _assemble_plan(plan_probe)
	var stats: Dictionary = result.get("placement_stats", {})
	var success := bool(result.get("success", false))
	if success:
		var root_value: Variant = result.get("root", null)
		if root_value != null and is_instance_valid(root_value):
			(root_value as Node3D).free()
	assembly_trace = trace_before
	placement_stats = stats_before
	return {
		"success": success,
		"error": str(result.get("error", "")),
		"elapsed_ms": Time.get_ticks_msec() - started,
		"candidate_checks": int(stats.get("candidate_checks", 0)),
		"backtracks": int(stats.get("backtracks", 0)),
	}


func _is_retryable_physical_assembly_error(error: String) -> bool:
	## Sólo el agotamiento del placement físico habilita un sector alternativo.
	## Plan/semántica, seams, bake y navegación son errores reales y no se
	## enmascaran con reintentos.
	return error.begins_with("no spatially valid placement")


func _selected_archetype() -> DungeonArchetypeResource:
	match test_archetype_index:
		1: return TEST_ARCHETYPE_VARKHEM
		2: return TEST_ARCHETYPE_HORVEX
		_: return TEST_ARCHETYPE_SHIP


func _build_transition_slot() -> void:
	transition_slot = null
	if not archetype_mode or sector_run == null or current_sector_index >= sector_run.sector_count() - 1:
		return
	var sector := sector_run.get_sector(current_sector_index)
	transition_slot = DungeonTransitionSlot.new()
	transition_slot.slot_id = StringName("TRANSITION:%d:%d" % [current_sector_index, current_sector_index + 1])
	transition_slot.transition_type = sector.transition_to_next_type if sector != null else &"HATCH"
	transition_slot.from_sector_index = current_sector_index
	transition_slot.to_sector_index = current_sector_index + 1
	transition_slot.global_transform = Transform3D(Basis.IDENTITY, exit_point)
	var root := Node3D.new()
	root.name = "SectorTransitionDebug"
	add_child(root)
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.7
	mesh.height = 0.12
	marker.mesh = mesh
	marker.material_override = _debug_material(Color(1.0, 0.95, 0.1, 1.0))
	marker.global_transform = transition_slot.global_transform
	root.add_child(marker)


func _rebuild_semantic_location_debug(modules: Node3D) -> void:
	var old := get_node_or_null("SemanticLocationDebug")
	if old != null:
		old.free()
	if current_plan == null or current_plan.semantic_locations.is_empty() or modules == null:
		return
	var root := Node3D.new()
	root.name = "SemanticLocationDebug"
	add_child(root)
	for location in current_plan.semantic_locations:
		var module := modules.get_node_or_null(NodePath(String(location.node_id))) as Node3D
		if module == null:
			continue
		location.global_transform = Transform3D(module.global_transform.basis, module.global_position + Vector3(0, 0.35, 0))
		var marker := MeshInstance3D.new()
		marker.name = String(location.get_id()).replace(":", "_")
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.75, 0.25, 0.75)
		marker.mesh = mesh
		marker.material_override = _debug_material(_semantic_color(location.definition.semantic_id))
		marker.global_transform = location.global_transform
		marker.set_meta("semantic_id", location.definition.semantic_id)
		marker.set_meta("node_id", location.node_id)
		root.add_child(marker)


func _semantic_color(semantic_id: StringName) -> Color:
	match semantic_id:
		&"AIRLOCK_SHIP_EXIT": return Color(0.2, 0.8, 1.0, 1.0)
		&"CARGO_HOLD": return Color(1.0, 0.78, 0.1, 1.0)
		&"BRIDGE": return Color(0.35, 1.0, 0.45, 1.0)
		&"MEDBAY": return Color(1.0, 0.35, 0.35, 1.0)
		&"LABORATORY": return Color(0.75, 0.25, 1.0, 1.0)
		_: return Color(0.95, 0.95, 0.95, 1.0)


func _assemble_plan(plan: DungeonPlan) -> Dictionary:
	assembly_trace.clear()
	if plan == null or not plan.is_valid():
		return {"success": false, "error": "invalid DungeonPlan"}
	plan.assembly_transforms.clear()
	var result := _assemble_plan_attempt(plan, 0)
	placement_stats = result.get("placement_stats", {})
	if bool(result.get("success", false)):
		return result
	var failed_root: Node3D = result.get("root", null)
	if failed_root != null and is_instance_valid(failed_root):
		failed_root.free()
	return result


func _assemble_plan_attempt(plan: DungeonPlan, placement_attempt: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "AssembledModules"
	add_child(root)
	var placed: Dictionary = {}
	var used_connectors: Dictionary = {}
	var seams: Array[Dictionary] = []
	if not plan.module_ids.has(&"START"):
		return {"success": false, "error": "plan does not begin at START", "root": root}
	var start_definition: ModuleDefinitionResource = plan.module_definitions.get(&"START")
	var start := _make_module(&"START", &"START", start_definition)
	root.add_child(start)
	placed[&"START"] = start
	assembly_trace.append({"id": &"START", "parent": &"", "status": "PLACED", "role": &"START", "transform": start.global_transform, "bounds": _world_bounds(start)})
	used_connectors[&"START"] = {}
	var steps := _assembly_steps(plan)
	if steps.is_empty() and plan.module_ids.size() > 1:
		return {"success": false, "error": "plan has no assembly steps", "root": root}
	var budget := active_template.max_spatial_backtrack_depth if active_template != null else 0
	var stats: Dictionary = {
		"attempt": placement_attempt,
		"candidate_checks": 0,
		"alternate_candidates": 0,
		"backtracks": 0,
		"backtrack_nodes": [],
		"backtrack_budget": budget,
	}
	var placement_result := _place_steps_with_backtracking(plan, root, steps, 0, placed, used_connectors, seams, budget, stats)
	if not bool(placement_result.get("success", false)):
		return {"success": false, "error": str(placement_result.get("error", "no spatially valid placement")), "root": root, "placement_stats": stats}
	# 6K.4A: una reconexión es una arista adicional del mismo DungeonPlan. El
	# árbol base se coloca primero; después el módulo RECONNECT debe cerrar dos
	# conectores ya libres. Nunca duplica el target ni acepta una proximidad sin
	# ambos seams físicos válidos.
	var closure_result := _place_reconnection_closures(plan, root, placed, used_connectors, seams, stats)
	if not bool(closure_result.get("success", false)):
		return {"success": false, "error": str(closure_result.get("error", "no spatially valid reconnection")), "root": root, "placement_stats": stats}
	if active_template != null and active_template.enforce_walkable_containment:
		_seal_unused_connector_openings(placed, used_connectors)
	plan.assembly_transforms[&"START"] = start.global_transform
	var exit_module: Node3D = placed.get(&"EXIT")
	if exit_module == null:
		return {"success": false, "error": "EXIT missing", "root": root, "placement_stats": stats}
	var signature_parts: Array[String] = []
	var placed_ids: Array[StringName] = []
	for id_variant in placed: placed_ids.append(id_variant)
	placed_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in placed_ids:
		var module: Node3D = placed[id]
		signature_parts.append("%s:%s:%d,%d,%d" % [id, module.get_meta("module_kind", plan.module_types.get(id, &"")), roundi(module.position.x * 100), roundi(module.position.z * 100), roundi(rad_to_deg(module.rotation.y))])
	return {
		"success": true,
		"root": root,
		"module_count": placed.size(),
		"start_point": (start.get_node("PlayerSpawn") as Marker3D).global_position,
		"exit_point": exit_module.global_position + Vector3(0, 0.9, 0),
		"signature": "|".join(signature_parts),
		"topology_signature": plan.get_topology_signature(),
		"seams": seams,
		"enclosure": enclosure_results,
		"placement_stats": stats,
	}


## Orden estable equivalente al recorrido breadth-first previo. La búsqueda
## sólo explora transforms/conectores de estos pasos: no cambia roles, links ni
## semántica del DungeonPlan.
func _assembly_steps(plan: DungeonPlan) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var queue: Array[StringName] = [&"START"]
	var seen: Dictionary = {&"START": true}
	while not queue.is_empty():
		var parent_id: StringName = queue.pop_front()
		for id_variant in plan.links.get(parent_id, []):
			var id: StringName = id_variant
			# RECONNECT se materializa al final como cierre entre source/target.
			if plan.reconnection_nodes.has(id):
				continue
			if seen.has(id):
				# Un DAG puede llegar a un nodo por dos enlaces. El nodo ya colocado
				# no se duplica; la segunda arista es validada por el cierre anterior.
				continue
			seen[id] = true
			result.append({"id": id, "parent": parent_id, "role": plan.module_types.get(id, &"STRAIGHT")})
			queue.append(id)
	return result


func _place_reconnection_closures(plan: DungeonPlan, root: Node3D, placed: Dictionary, used_connectors: Dictionary, seams: Array[Dictionary], stats: Dictionary) -> Dictionary:
	for reconnect in plan.reconnections:
		var id: StringName = reconnect.id
		var source_id: StringName = reconnect.source
		var target_id: StringName = reconnect.target
		if not placed.has(source_id) or not placed.has(target_id):
			return {"success": false, "error": "reconnection endpoints missing for %s" % id}
		var source: Node3D = placed[source_id]
		var target: Node3D = placed[target_id]
		var sources := _available_connectors(source, "out", used_connectors[source_id], 0)
		var targets := _available_connectors(target, "out", used_connectors[target_id], 0)
		var placed_closure := false
		var winning_route: Array[Dictionary] = []
		for source_connector in sources:
			if placed_closure: break
			for target_connector in targets:
				var route: Array[Dictionary] = []
				for pattern in _reconnection_route_patterns():
					if _place_reconnection_route_recursive(id, source_id, target_id, root, pattern, 0, source_connector, target_connector, placed, route, stats):
						route[0]["source_connector"] = source_connector
						route[route.size() - 1]["target_connector"] = target_connector
						winning_route = route
						placed_closure = true
						break
				if placed_closure: break
		if not placed_closure:
			return {"success": false, "error": "no spatially valid reconnection %s between %s and %s" % [id, source_id, target_id]}
		used_connectors[source_id][winning_route[0].source_connector.get_instance_id()] = true
		used_connectors[target_id][winning_route.back().target_connector.get_instance_id()] = true
		# El route ganador ya tiene todos los seams. Se registra como geometría
		# auxiliar de la arista, sin añadir nodos semánticos al DungeonPlan.
		for segment_index in range(winning_route.size()):
			var segment: Dictionary = winning_route[segment_index]
			var aux_id := StringName("%s_ROUTE_%d" % [id, segment_index])
			var module: Node3D = segment.module
			module.name = String(aux_id)
			placed[aux_id] = module
			used_connectors[aux_id] = {segment.incoming.get_instance_id(): true, segment.outgoing.get_instance_id(): true}
			seams.append(segment.seam)
			assembly_trace.append({"id": aux_id, "logical_edge": id, "parent": source_id, "target": target_id, "status": "RECONNECT_ROUTE_PLACED", "role": segment.role, "definition": segment.definition.stable_id, "transform": module.global_transform})
		seams.append(winning_route.back().final_seam)
		plan.assembly_transforms[id] = (winning_route[0].module as Node3D).global_transform
	return {"success": true}


func _reconnection_route_patterns() -> Array[Array]:
	var template := active_template
	var allowed: Array[StringName] = [&"CORRIDOR"]
	if template != null: allowed = template.reconnection_route_roles
	var maximum_segments := template.max_reconnection_route_segments if template != null else 1
	var maximum_turns := template.max_reconnection_route_turns if template != null else 0
	var patterns: Array[Array] = []
	_build_reconnection_patterns([], allowed, maximum_segments, maximum_turns, patterns)
	patterns.sort_custom(func(a: Array, b: Array) -> bool:
		# El contrato de rutas favorece trazados legibles: menos segmentos,
		# luego menos giros y, a igualdad, orden estable de roles/variantes.
		if a.size() != b.size(): return a.size() < b.size()
		var a_turns := a.count(&"TURN_LEFT") + a.count(&"TURN_RIGHT")
		var b_turns := b.count(&"TURN_LEFT") + b.count(&"TURN_RIGHT")
		if a_turns != b_turns: return a_turns < b_turns
		return ",".join(a) < ",".join(b)
	)
	return patterns


func _build_reconnection_patterns(prefix: Array[StringName], allowed: Array[StringName], maximum_segments: int, maximum_turns: int, output: Array[Array]) -> void:
	if not prefix.is_empty() and prefix.back() == &"CORRIDOR": output.append(prefix.duplicate())
	if prefix.size() >= maximum_segments: return
	for role in allowed:
		if prefix.is_empty() and role != &"CORRIDOR": continue
		if not prefix.is_empty() and role != &"CORRIDOR" and prefix.back() != &"CORRIDOR": continue
		var turns := 0
		for existing in prefix:
			if existing in [&"TURN_LEFT", &"TURN_RIGHT"]: turns += 1
		if role in [&"TURN_LEFT", &"TURN_RIGHT"]: turns += 1
		if turns > maximum_turns: continue
		var next: Array[StringName] = prefix.duplicate()
		next.append(role)
		_build_reconnection_patterns(next, allowed, maximum_segments, maximum_turns, output)


func _route_definitions(role: StringName) -> Array[ModuleDefinitionResource]:
	var result: Array[ModuleDefinitionResource] = []
	if active_template == null: return result
	for rule in active_template.grammar_rules:
		if rule == null or rule.role != role: continue
		if rule.module_definition != null: result.append(rule.module_definition)
		for variant in rule.module_variants:
			if variant != null and not result.has(variant): result.append(variant)
	result.sort_custom(func(a: ModuleDefinitionResource, b: ModuleDefinitionResource) -> bool:
		if a.placement_priority != b.placement_priority:
			return a.placement_priority > b.placement_priority
		return String(a.stable_id) < String(b.stable_id)
	)
	return result


func _place_reconnection_route_recursive(logical_id: StringName, source_id: StringName, target_id: StringName, root: Node3D, pattern: Array, index: int, source_connector: Marker3D, target_connector: Marker3D, occupied: Dictionary, route: Array[Dictionary], stats: Dictionary) -> bool:
	if index >= pattern.size():
		if route.is_empty(): return false
		var last: Dictionary = route.back()
		var final_seam := _validate_connector_contract(last.outgoing, target_connector)
		if bool(final_seam.valid):
			last.final_seam = final_seam
			route[route.size() - 1] = last
			return true
		return false
	var role: StringName = pattern[index]
	var parent_connector: Marker3D = source_connector if index == 0 else route.back().outgoing
	for definition in _route_definitions(role):
		var candidate := _make_module(StringName("%s_ROUTE_TMP_%d" % [logical_id, index]), role, definition)
		var incoming := _find_available_connector(candidate, "in", {})
		if incoming == null:
			candidate.free()
			continue
		root.add_child(candidate)
		_align_connectors(candidate, incoming, parent_connector)
		var outgoing := _find_available_connector(candidate, "out", {incoming.get_instance_id(): true})
		var seam := _validate_connector_contract(parent_connector, incoming)
		var conflicts := _overlap_details(candidate, occupied)
		stats.candidate_checks = int(stats.candidate_checks) + 1
		if outgoing == null or not bool(seam.valid) or not conflicts.is_empty():
			root.remove_child(candidate)
			candidate.free()
			continue
		var temp_id := StringName("__ROUTE_%d" % index)
		occupied[temp_id] = candidate
		route.append({"module": candidate, "incoming": incoming, "outgoing": outgoing, "seam": seam, "role": role, "definition": definition})
		if _place_reconnection_route_recursive(logical_id, source_id, target_id, root, pattern, index + 1, source_connector, target_connector, occupied, route, stats):
			# El caller promueve este módulo con su ID auxiliar estable. No dejar
			# el identificador temporal en `occupied`, o contaría dos veces la
			# misma geometría al construir proxies/telemetría.
			occupied.erase(temp_id)
			return true
		route.pop_back()
		occupied.erase(temp_id)
		root.remove_child(candidate)
		candidate.free()
	return false


func _place_steps_with_backtracking(plan: DungeonPlan, root: Node3D, steps: Array[Dictionary], step_index: int, placed: Dictionary, used_connectors: Dictionary, seams: Array[Dictionary], remaining_budget: int, stats: Dictionary) -> Dictionary:
	if step_index >= steps.size():
		return {"success": true, "remaining_budget": remaining_budget}
	var step: Dictionary = steps[step_index]
	var id: StringName = step.id
	var parent_id: StringName = step.parent
	var kind: StringName = step.role
	if placed.has(id) or not placed.has(parent_id):
		return {"success": false, "remaining_budget": remaining_budget, "error": "invalid placement dependency for %s" % id}
	var parent: Node3D = placed[parent_id]
	var options := _placement_options(plan, id, kind, parent, used_connectors[parent_id])
	var original_definition: ModuleDefinitionResource = plan.module_definitions.get(id, null)
	var budget := remaining_budget
	var last_error := "no spatially valid placement for %s after %s" % [id, parent_id]
	for option_index in range(options.size()):
		var option: Dictionary = options[option_index]
		var definition: ModuleDefinitionResource = option.definition
		var source: Marker3D = option.source
		var candidate := _make_module(id, kind, definition)
		var incoming := _find_available_connector(candidate, "in", {})
		if incoming == null:
			candidate.free()
			continue
		root.add_child(candidate)
		_align_connectors(candidate, incoming, source)
		var seam := _validate_connector_contract(source, incoming)
		var conflicts := _overlap_details(candidate, placed)
		stats.candidate_checks = int(stats.candidate_checks) + 1
		var trace_index := assembly_trace.size()
		assembly_trace.append({
			"id": id, "parent": parent_id, "status": "CANDIDATE", "role": kind,
			"definition": definition.stable_id, "source_connector": source.name, "incoming_connector": incoming.name,
			"transform": candidate.global_transform, "bounds": _world_bounds(candidate),
			"seam_valid": seam.valid, "seam_error": seam.error, "conflicts": conflicts,
			"placement_attempt": 0, "candidate_index": option_index,
		})
		if not bool(seam.valid) or not conflicts.is_empty():
			root.remove_child(candidate)
			candidate.free()
			continue
		placed[id] = candidate
		used_connectors[parent_id][source.get_instance_id()] = true
		used_connectors[id] = {incoming.get_instance_id(): true}
		plan.module_definitions[id] = definition
		plan.assembly_transforms[id] = candidate.global_transform
		seams.append(seam)
		assembly_trace[trace_index]["status"] = "PLACED"
		var child_result := _place_steps_with_backtracking(plan, root, steps, step_index + 1, placed, used_connectors, seams, budget, stats)
		if bool(child_result.get("success", false)):
			if option_index > 0:
				stats.alternate_candidates = int(stats.alternate_candidates) + 1
			return child_result
		budget = int(child_result.get("remaining_budget", budget))
		seams.pop_back()
		used_connectors[parent_id].erase(source.get_instance_id())
		used_connectors.erase(id)
		placed.erase(id)
		plan.assembly_transforms.erase(id)
		if original_definition != null:
			plan.module_definitions[id] = original_definition
		else:
			plan.module_definitions.erase(id)
		root.remove_child(candidate)
		candidate.free()
		assembly_trace[trace_index]["status"] = "BACKTRACKED"
		# Deshacer un nodo sin otra alternativa no consume presupuesto: no fue
		# una decisión espacial reconsiderable. Sólo se cobra al probar otra
		# opción válida del mismo nodo.
		if option_index + 1 < options.size():
			if budget <= 0:
				return {"success": false, "remaining_budget": 0, "error": str(child_result.get("error", last_error))}
			budget -= 1
			stats.backtracks = int(stats.backtracks) + 1
			stats.backtrack_nodes.append(id)
		else:
			return {"success": false, "remaining_budget": budget, "error": str(child_result.get("error", last_error))}
	return {"success": false, "remaining_budget": budget, "error": last_error}


func _placement_options(plan: DungeonPlan, id: StringName, kind: StringName, parent: Node3D, used: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var max_candidates := active_template.max_placement_candidates_per_node if active_template != null else 1
	var sources := _available_connectors(parent, "out", used, 0)
	var definitions := _placement_definitions(plan, id, kind, 0)
	for definition in definitions:
		for source in sources:
			if result.size() >= max_candidates:
				return result
			result.append({"definition": definition, "source": source})
	return result


func _make_module(id: StringName, kind: StringName, definition: ModuleDefinitionResource = null) -> Node3D:
	var root := Node3D.new()
	root.name = String(id)
	root.set_meta("module_kind", kind)
	var dimensions := _module_dimensions(kind, definition)
	root.set_meta("footprint_size", dimensions)
	var legacy_openings: Array = {
		&"START": [&"east"], &"EXIT": [&"west"], &"STRAIGHT": [&"west", &"east"], &"CORRIDOR": [&"west", &"east"],
		&"ROOM": [&"west", &"east"], &"TURN_LEFT": [&"west", &"north"],
		&"TURN_RIGHT": [&"west", &"south"], &"JUNCTION": [&"west", &"east", &"north"],
		&"SIDE_ROOM": [&"west"], &"DEAD_END": [&"west"], &"SPECIAL": [&"west", &"east"],
	}.get(kind, [&"west", &"east"])
	var openings: Array = definition.connector_sides if definition != null and not definition.connector_sides.is_empty() else legacy_openings
	var floor := CSGBox3D.new()
	floor.name = "Floor"
	floor.size = Vector3(dimensions.x, 0.2, dimensions.y)
	floor.position.y = -0.1
	floor.use_collision = true
	floor.material = _debug_material(_floor_debug_color(kind))
	root.add_child(floor)
	for side in [&"west", &"east", &"north", &"south"]:
		_add_wall(root, side, openings.has(side), dimensions)
	for side in openings:
		_add_connector(root, "in" if side == &"west" and kind != &"START" else "out", side, dimensions)
	if kind == &"START":
		var spawn := Marker3D.new()
		spawn.name = "PlayerSpawn"
		spawn.position = Vector3(0, 0.9, 0)
		# El único acceso del START TEST está al este: orientar el cuerpo hacia
		# esa boca hace que el primer avance manual no choque con la pared norte.
		spawn.rotation.y = -PI / 2.0
		root.add_child(spawn)
	return root


func _module_dimensions(kind: StringName, definition: ModuleDefinitionResource) -> Vector2:
	if definition != null and definition.footprint_size.x > 0.0 and definition.footprint_size.y > 0.0:
		return definition.footprint_size
	match kind:
		&"CORRIDOR": return Vector2(12.0, 4.0)
		&"ROOM": return Vector2(10.0, 10.0)
		_: return Vector2(TILE_SIZE, TILE_SIZE)


func _add_wall(root: Node3D, side: StringName, has_opening: bool, dimensions: Vector2) -> void:
	if has_opening:
		_add_door_frame(root, side, dimensions)
		return
	var wall := CSGBox3D.new()
	wall.name = "Wall_%s" % side
	wall.use_collision = true
	wall.material = _debug_material(Color(0.34, 0.38, 0.48, 1.0))
	if side == &"west" or side == &"east":
		wall.size = Vector3(0.3, DOOR_HEIGHT, dimensions.y)
		wall.position = Vector3(-dimensions.x / 2.0 if side == &"west" else dimensions.x / 2.0, DOOR_HEIGHT / 2.0, 0)
	else:
		wall.size = Vector3(dimensions.x, DOOR_HEIGHT, 0.3)
		wall.position = Vector3(0, DOOR_HEIGHT / 2.0, -dimensions.y / 2.0 if side == &"north" else dimensions.y / 2.0)
	root.add_child(wall)


func _add_door_frame(root: Node3D, side: StringName, dimensions: Vector2) -> void:
	# Dos segmentos exactos dejan una abertura canónica; no se ensancha la pieza
	# para ocultar seams. Todos los conectores exponen el mismo volumen útil.
	var span := dimensions.y if side == &"west" or side == &"east" else dimensions.x
	var segment_length := (span - DOOR_WIDTH) / 2.0
	var segment_offset := DOOR_WIDTH / 2.0 + segment_length / 2.0
	for sign in [-1.0, 1.0]:
		var wall := CSGBox3D.new()
		wall.name = "DoorFrame_%s_%d" % [side, sign]
		wall.use_collision = true
		wall.material = _debug_material(Color(0.34, 0.38, 0.48, 1.0))
		if side == &"west" or side == &"east":
			wall.size = Vector3(0.3, DOOR_HEIGHT, segment_length)
			wall.position = Vector3(-dimensions.x / 2.0 if side == &"west" else dimensions.x / 2.0, DOOR_HEIGHT / 2.0, sign * segment_offset)
		else:
			wall.size = Vector3(segment_length, DOOR_HEIGHT, 0.3)
			wall.position = Vector3(sign * segment_offset, DOOR_HEIGHT / 2.0, -dimensions.y / 2.0 if side == &"north" else dimensions.y / 2.0)
		root.add_child(wall)


func _floor_debug_color(kind: StringName) -> Color:
	match kind:
		&"START": return Color(0.05, 0.65, 0.95, 1.0)
		&"EXIT": return Color(0.15, 0.9, 0.32, 1.0)
		&"TURN_LEFT", &"TURN_RIGHT": return Color(0.62, 0.32, 0.92, 1.0)
		&"JUNCTION": return Color(0.95, 0.55, 0.12, 1.0)
		&"SIDE_ROOM": return Color(0.88, 0.42, 0.18, 1.0)
		&"ROOM": return Color(0.15, 0.72, 0.72, 1.0)
		&"CORRIDOR": return Color(0.30, 0.50, 0.82, 1.0)
		_: return Color(0.14, 0.48, 0.68, 1.0)


func _debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _add_connector(root: Node3D, role: String, side: StringName, dimensions: Vector2) -> void:
	var marker := Marker3D.new()
	marker.name = "Connector_%s_%s" % [role, side]
	marker.set_meta("role", role)
	marker.set_meta("side", side)
	marker.set_meta("tag", &"door")
	marker.set_meta("usable_width_m", DOOR_WIDTH)
	marker.set_meta("usable_height_m", DOOR_HEIGHT)
	match side:
		&"west": marker.position = Vector3(-dimensions.x / 2.0, 0, 0); marker.rotation.y = PI / 2.0
		&"east": marker.position = Vector3(dimensions.x / 2.0, 0, 0); marker.rotation.y = -PI / 2.0
		&"north": marker.position = Vector3(0, 0, -dimensions.y / 2.0); marker.rotation.y = 0.0
		&"south": marker.position = Vector3(0, 0, dimensions.y / 2.0); marker.rotation.y = PI
	root.add_child(marker)


## Cierra únicamente una boca declarada por una ModuleDefinition que quedó sin
## par físico. Los conectores se mantienen como contrato de catálogo, pero la
## instancia final no expone un hueco caminable hacia el exterior.
func _seal_unused_connector_openings(placed: Dictionary, used_connectors: Dictionary) -> void:
	enclosure_results.clear()
	enclosure_valid = false
	var ids: Array[StringName] = []
	for id_variant in placed:
		ids.append(id_variant)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id in ids:
		var module: Node3D = placed[id]
		var used: Dictionary = used_connectors.get(id, {})
		var dimensions := Vector2(module.get_meta("footprint_size", Vector2(TILE_SIZE, TILE_SIZE)))
		for child in module.get_children():
			if not child is Marker3D:
				continue
			var connector := child as Marker3D
			if not connector.has_meta("side"):
				continue
			var side: StringName = connector.get_meta("side", &"")
			var connected := used.has(connector.get_instance_id())
			var sealed := false
			if not connected:
				_close_unpaired_opening(module, side, dimensions)
				connector.set_meta("sealed_unused", true)
				sealed = true
			enclosure_results.append({
				"module": id, "connector": connector, "side": side,
				"connected": connected, "sealed": sealed,
			})


func _close_unpaired_opening(module: Node3D, side: StringName, dimensions: Vector2) -> void:
	for child in module.get_children().duplicate():
		if String(child.name).begins_with("DoorFrame_%s_" % side):
			module.remove_child(child)
			child.free()
	# Una pared completa con la misma altura y layer de colisión que el resto
	# del módulo: no hay muro global ni piso de seguridad fuera de la dungeon.
	_add_wall(module, side, false, dimensions)


func _find_available_connector(module: Node3D, role: String, used: Dictionary) -> Marker3D:
	for child in module.get_children():
		if child is Marker3D and child.get_meta("role", "") == role and not used.has(child.get_instance_id()):
			return child
	return null


func _available_connectors(module: Node3D, role: String, used: Dictionary, placement_attempt: int) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child in module.get_children():
		if child is Marker3D and child.get_meta("role", "") == role and not used.has(child.get_instance_id()):
			result.append(child)
	result.sort_custom(func(a: Marker3D, b: Marker3D) -> bool: return String(a.name) < String(b.name))
	if result.size() > 1 and placement_attempt > 0:
		var offset := placement_attempt % result.size()
		var rotated: Array[Marker3D] = []
		for index in range(result.size()):
			rotated.append(result[(index + offset) % result.size()])
		return rotated
	return result


func _placement_definitions(plan: DungeonPlan, id: StringName, kind: StringName, placement_attempt: int) -> Array[ModuleDefinitionResource]:
	var definitions: Array[ModuleDefinitionResource] = []
	for definition in plan.module_definition_variants.get(id, []):
		if definition != null and not definitions.has(definition):
			definitions.append(definition)
	if definitions.is_empty():
		var fallback: ModuleDefinitionResource = plan.module_definitions.get(id, null)
		if fallback != null:
			definitions.append(fallback)
	definitions.sort_custom(func(a: ModuleDefinitionResource, b: ModuleDefinitionResource) -> bool:
		if a.placement_priority != b.placement_priority:
			return a.placement_priority > b.placement_priority
		return String(a.stable_id) < String(b.stable_id)
	)
	return definitions


func _align_connectors(module: Node3D, incoming: Marker3D, source: Marker3D) -> void:
	var incoming_dir := -incoming.transform.basis.z.normalized()
	var desired_dir := -_connector_outward(source)
	module.rotation.y = atan2(desired_dir.x, desired_dir.z) - atan2(incoming_dir.x, incoming_dir.z)
	module.position = source.global_position - module.global_transform.basis * incoming.position


func _connector_outward(connector: Marker3D) -> Vector3:
	return -connector.global_transform.basis.z.normalized()


func _validate_connector_contract(source: Marker3D, incoming: Marker3D) -> Dictionary:
	var position_error := source.global_position.distance_to(incoming.global_position)
	var facing_dot := _connector_outward(source).dot(_connector_outward(incoming))
	var up_dot := source.global_transform.basis.y.normalized().dot(incoming.global_transform.basis.y.normalized())
	var width_error := absf(float(source.get_meta("usable_width_m", 0.0)) - float(incoming.get_meta("usable_width_m", 0.0)))
	var height_error := absf(float(source.get_meta("usable_height_m", 0.0)) - float(incoming.get_meta("usable_height_m", 0.0)))
	var valid := position_error <= 0.01 and facing_dot <= -0.999 and up_dot >= 0.999 and width_error <= 0.001 and height_error <= 0.001
	return {
		"valid": valid, "error": "pos=%.4f facing=%.4f up=%.4f width=%.4f height=%.4f" % [position_error, facing_dot, up_dot, width_error, height_error],
		"position": source.global_position, "source": source, "incoming": incoming,
	}


func _overlaps_placed(candidate: Node3D, modules: Array) -> bool:
	var candidate_bounds := _world_bounds(candidate)
	for module in modules:
		var intersection := candidate_bounds.intersection(_world_bounds(module))
		if intersection.size.x > 0.05 and intersection.size.y > 0.05 and intersection.size.z > 0.05:
			return true
	return false


func _overlap_details(candidate: Node3D, placed: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var candidate_bounds := _world_bounds(candidate)
	for id in placed:
		var module: Node3D = placed[id]
		var intersection := candidate_bounds.intersection(_world_bounds(module))
		if intersection.size.x > 0.05 and intersection.size.y > 0.05 and intersection.size.z > 0.05:
			result.append({"id": id, "bounds": _world_bounds(module), "intersection": intersection})
	return result


func _world_bounds(module: Node3D) -> AABB:
	var dimensions := Vector2(module.get_meta("footprint_size", Vector2(TILE_SIZE, TILE_SIZE)))
	var basis := module.global_transform.basis
	var world_x := absf(basis.x.x) * dimensions.x + absf(basis.z.x) * dimensions.y
	var world_z := absf(basis.x.z) * dimensions.x + absf(basis.z.z) * dimensions.y
	return AABB(Vector3(module.global_position.x - world_x / 2.0, -0.1, module.global_position.z - world_z / 2.0), Vector3(world_x, 2.1, world_z))


func _validate_physical_seams() -> bool:
	# El contrato de transforms comprueba la alineación matemática. Esta segunda
	# pasada consulta la física real en el centro de cada boca con la cápsula que
	# se usa en las auditorías B+C: detecta una pared residual o un gap bloqueante.
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	for seam in _seam_results:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, Vector3(seam.position.x, 0.9, seam.position.z))
		query.collision_mask = 1
		var blocked := false
		for hit in space.intersect_shape(query, 16):
			var collider: Variant = hit.get("collider")
			if collider is CSGBox3D and (collider as CSGBox3D).size.y > 0.5:
				blocked = true
				break
		seam["physical_clear"] = not blocked
		if blocked:
			return false
	return true


## Verificación estructural previa a B+C: cada apertura sellada debe haber
## quedado cubierta por una pared local con collision. La cápsula real se
## ejercita desde los harnesses una vez sincronizado el árbol físico.
func _validate_walkable_containment() -> bool:
	for result in enclosure_results:
		if bool(result.get("connected", false)):
			continue
		var connector: Marker3D = result.get("connector", null)
		if connector == null or not is_instance_valid(connector):
			return false
		var module := connector.get_parent() as Node3D
		var wall := module.get_node_or_null("Wall_%s" % result.get("side", &"")) as CSGBox3D
		var blocked := wall != null and wall.use_collision and wall.size.y >= DOOR_HEIGHT - 0.001
		result["local_collision_wall"] = blocked
		if not blocked:
			print("6K.4C containment failure module=%s side=%s connector=%s" % [result.get("module", &""), result.get("side", &""), connector.name])
			return false
	enclosure_valid = true
	return true


func _bake(source: Node3D) -> void:
	var proxy_root := Node3D.new()
	proxy_root.name = "NavigationBakeProxies"
	add_child(proxy_root)
	for csg in _collect(source):
		var proxy := StaticBody3D.new()
		proxy.global_transform = csg.global_transform
		proxy.collision_layer = LAYER
		proxy.collision_mask = 0
		proxy.add_to_group(GROUP)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = csg.size
		shape.shape = box
		proxy.add_child(shape)
		proxy_root.add_child(proxy)
		var module_id := _source_module_id(csg, source)
		proxy.name = "Proxy_%s_%s" % [module_id, csg.name]
		proxy.set_meta("source_module", module_id)
		bake_proxy_reports.append({
			"module": module_id,
			"source": csg.get_path(),
			"transform": proxy.global_transform,
			"bounds": _box_world_bounds(proxy.global_transform, box.size),
			"layer": proxy.collision_layer,
			"mask": proxy.collision_mask,
		})
		proxies += 1
	await get_tree().physics_frame
	nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	nav_mesh.geometry_source_group_name = GROUP
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 0.55
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_max_climb = 0.2
	nav_mesh.agent_max_slope = 1.0
	nav_mesh.cell_size = 0.05
	nav_mesh.cell_height = 0.1
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.parse_source_geometry_data(nav_mesh, data, self, Callable())
	var source_vertices: PackedFloat32Array = data.get_vertices()
	bake_source_vertex_count = source_vertices.size() / 3
	bake_source_index_count = data.get_indices().size()
	bake_source_bounds = _float_points_bounds(source_vertices)
	NavigationMeshGenerator.bake_from_source_geometry_data(nav_mesh, data, Callable())
	nav_region = NavigationRegion3D.new()
	nav_region.name = "BakedNavigationRegion"
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	NavigationServer3D.map_force_update(nav_region.get_navigation_map())


func _await_navigation_ready(max_attempts: int = 120) -> bool:
	# NavigationServer registra regiones y edge data de forma asíncrona. El gate
	# usa evidencia del mapa actual, no un conteo fijo de frames; el límite sólo
	# evita una espera infinita frente a un bake realmente inválido.
	if nav_region == null or nav_mesh == null or nav_mesh.get_polygon_count() == 0:
		return false
	var map := nav_region.get_navigation_map()
	for attempt in max_attempts:
		nav_sync_attempts = attempt + 1
		NavigationServer3D.map_force_update(map)
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			await get_tree().physics_frame
			continue
		var start := NavigationServer3D.map_get_closest_point(map, start_point)
		var finish := NavigationServer3D.map_get_closest_point(map, exit_point)
		var start_valid := _horizontal_distance(start, start_point) <= 0.25
		var exit_valid := _horizontal_distance(finish, exit_point) <= 0.25
		var path_valid := false
		if start_valid and exit_valid:
			path_valid = NavigationServer3D.map_get_path(map, start, finish, true).size() > 1
		if start_valid and exit_valid and path_valid:
			return true
		await get_tree().physics_frame
	return false


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _collect(node: Node) -> Array[CSGBox3D]:
	var result: Array[CSGBox3D] = []
	if node is CSGBox3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect(child))
	return result


func _source_module_id(csg: CSGBox3D, source: Node3D) -> StringName:
	var cursor: Node = csg
	while cursor.get_parent() != null and cursor.get_parent() != source:
		cursor = cursor.get_parent()
	return StringName(cursor.name)


func _box_world_bounds(transform: Transform3D, size: Vector3) -> AABB:
	var result := AABB(transform * (-size / 2.0), Vector3.ZERO)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				result = result.expand(transform * Vector3(size.x * x / 2.0, size.y * y / 2.0, size.z * z / 2.0))
	return result


func _points_bounds(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _float_points_bounds(points: PackedFloat32Array) -> AABB:
	if points.size() < 3:
		return AABB()
	var result := AABB(Vector3(points[0], points[1], points[2]), Vector3.ZERO)
	for index in range(0, points.size() - 2, 3):
		result = result.expand(Vector3(points[index], points[index + 1], points[index + 2]))
	return result


func _has_connected_path() -> bool:
	if nav_region == null:
		return false
	var map := nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, start_point)
	var finish := NavigationServer3D.map_get_closest_point(map, exit_point)
	var path := NavigationServer3D.map_get_path(map, start, finish, true)
	if path.size() <= 1:
		print("6G NAV DISCONNECTED seed=%d start=%s closest=%s exit=%s closest=%s polygons=%d" % [seed, start_point, start, exit_point, finish, nav_mesh.get_polygon_count()])
	return path.size() > 1


func _clear_previous_assembly() -> void:
	for name in [&"AssembledModules", &"NavigationBakeProxies", &"BakedNavigationRegion", &"ContentSlotDebug", &"RuntimeContent", &"SectorTransitionDebug", &"SemanticLocationDebug"]:
		var old := get_node_or_null(NodePath(name))
		if old != null:
			if old == nav_region:
				nav_region.enabled = false
				nav_region.navigation_mesh = null
			old.queue_free()
	proxies = 0
	bake_source_vertex_count = 0
	bake_source_index_count = 0
	bake_source_bounds = AABB()
	bake_proxy_reports.clear()
	current_content_plan = null
	current_content_profile = null
	current_runtime_content_report.clear()
	module_count = 0
	nav_mesh = null
	nav_region = null
	# NavigationServer actualiza el mapa en física; esperar ambos frames evita
	# que la nueva región coexista un tick con la anterior durante un reset.
	await get_tree().process_frame
	await get_tree().physics_frame


func _reposition_player() -> void:
	var player := get_node_or_null("Player") as CharacterBody3D
	if player != null:
		player.global_position = start_point
		var spawn := get_node_or_null("AssembledModules/START/PlayerSpawn") as Marker3D
		if spawn != null:
			player.rotation.y = spawn.global_rotation.y
		player.velocity = Vector3.ZERO


func _update_debug() -> void:
	var label := get_node_or_null("Stage6GDebug") as Label
	if label == null:
		var layer := CanvasLayer.new()
		layer.name = "Stage6GDebugLayer"
		label = Label.new()
		label.name = "Stage6GDebug"
		label.position = Vector2(20, 20)
		label.add_theme_font_size_override("font_size", 18)
		layer.add_child(label)
		add_child(layer)
	var nav_label := nav_sync_state if nav_sync_state == "SYNCING" else ("OK" if nav_ready else "FAIL")
	var slot_count := current_content_plan.selected_slots.size() if current_content_plan != null else 0
	if archetype_mode and active_archetype != null and sector_run != null:
		var sector := sector_run.get_sector(current_sector_index)
		var transition := "DUNGEON COMPLETE" if current_sector_index >= sector_run.sector_count() - 1 else "%s -> %s" % [sector.display_name, sector_run.get_sector(current_sector_index + 1).display_name]
		label.text = "ARCHETYPE: %s | SECTOR: %s %d/%d | SEED: %d | RETRY: %d | EFFECTIVE: %d\nTEMPLATE: %s | MODULES: %d | ASSEMBLY: %s | NAV: %s\nFACTION: %s | LIGHT: %s | POPULATION: %s | TRANSITION: %s" % [active_archetype.archetype_id, sector.sector_id, current_sector_index + 1, sector_run.sector_count(), seed, sector_retry_index, sector_effective_seed, get_active_template_id(), module_count, "VALID" if assembly_valid else "INVALID", nav_label, sector_run.selected_faction, sector.light_profile_id, sector.population_profile_id, transition]
		return
	label.text = "TEMPLATE: %s | PROFILE: %s | SEED: %d | MODULES: %d | ASSEMBLY: %s | NAV: %s\nSLOTS: %d | ENCOUNTER=RED LOOT=GOLD EVENT=VIOLET INTERACTION=CYAN SPECIAL=WHITE" % [get_active_template_id(), get_active_content_profile_id(), seed, module_count, "VALID" if assembly_valid else "INVALID", nav_label, slot_count]


func get_assembly_signature() -> String:
	return _assembly_signature


func get_topology_signature() -> String:
	return _topology_signature


func get_topology_metrics() -> Dictionary:
	var metrics := {"turns": 0, "rooms": 0, "corridors": 0, "junctions": 0, "branches": 0, "side_rooms": 0, "dead_ends": 0}
	if current_plan == null:
		return metrics
	for kind_variant in current_plan.module_types.values():
		match StringName(kind_variant):
			&"TURN_LEFT", &"TURN_RIGHT": metrics.turns += 1
			&"ROOM": metrics.rooms += 1
			&"CORRIDOR": metrics.corridors += 1
			&"JUNCTION": metrics.junctions += 1; metrics.branches += 1
			&"SIDE_ROOM": metrics.side_rooms += 1
			&"DEAD_END": metrics.dead_ends += 1
	return metrics


func get_branch_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var root := get_node_or_null("AssembledModules")
	if root == null or current_plan == null:
		return result
	for id in current_plan.module_ids:
		if current_plan.module_types.get(id, &"") == &"SIDE_ROOM":
			var module := root.get_node_or_null(NodePath(String(id))) as Node3D
			if module != null:
				result.append(module.global_position + Vector3(0, 0.9, 0))
	return result


func get_selected_module_definitions() -> Dictionary:
	var result: Dictionary = {}
	if current_plan == null:
		return result
	for id in current_plan.module_ids:
		var definition: ModuleDefinitionResource = current_plan.module_definitions.get(id, null)
		result[id] = definition.stable_id if definition != null else &"NONE"
	return result


func get_content_slot_metrics() -> Dictionary:
	var categories: Dictionary = {}
	if current_content_plan != null:
		for slot in current_content_plan.selected_slots:
			categories[slot.category] = int(categories.get(slot.category, 0)) + 1
	return {
		"profile": get_active_content_profile_id(),
		"selected": current_content_plan.selected_slots.size() if current_content_plan != null else 0,
		"all": current_content_plan.all_slots.size() if current_content_plan != null else 0,
		"signature": current_content_plan.get_signature() if current_content_plan != null else "",
		"categories": categories,
	}


func get_semantic_location_metrics() -> Dictionary:
	var result: Dictionary = {"count": 0, "locations": []}
	if current_plan == null:
		return result
	for location in current_plan.semantic_locations:
		result.locations.append({"id": location.definition.semantic_id, "node": location.node_id, "depth": location.depth_from_start, "branch": location.is_branch})
	result.count = result.locations.size()
	return result


func _rebuild_content_placement() -> void:
	var old := get_node_or_null("ContentSlotDebug")
	if old != null:
		old.free()
	var old_runtime := get_node_or_null("RuntimeContent")
	if old_runtime != null:
		old_runtime.free()
	current_runtime_content_report.clear()
	if current_plan == null or not assembly_valid:
		return
	var profile := _active_content_profile()
	current_content_profile = profile
	current_content_plan = CONTENT_DIRECTOR.build(current_plan, profile, seed)
	if not current_content_plan.is_valid():
		push_error("6I content placement failed: %s" % current_content_plan.generation_error)
		return
	var root := Node3D.new()
	root.name = "ContentSlotDebug"
	add_child(root)
	var modules := get_node_or_null("AssembledModules") as Node3D
	for slot in current_content_plan.selected_slots:
		if not _content_slot_is_safe(slot, modules):
			current_content_plan.generation_error = "unsafe slot %s" % slot.unique_id
			push_error("6I content placement failed: %s" % current_content_plan.generation_error)
			root.free()
			return
		var marker := MeshInstance3D.new()
		marker.name = String(slot.unique_id).replace(":", "_")
		var mesh := SphereMesh.new()
		mesh.radius = 0.34
		mesh.height = 0.68
		marker.mesh = mesh
		marker.material_override = _debug_material(_content_slot_color(slot.category))
		marker.global_transform = slot.global_transform
		marker.set_meta("content_slot_id", slot.unique_id)
		marker.set_meta("category", slot.category)
		root.add_child(marker)
	_rebuild_runtime_content(profile)


func _active_content_profile() -> ContentPlacementProfileResource:
	if active_template != null and active_template.content_placement_profile != null:
		return active_template.content_placement_profile
	return TEST_CONTENT_PROFILE_A if test_content_profile_index == 0 else TEST_CONTENT_PROFILE_B


func _rebuild_runtime_content(profile: ContentPlacementProfileResource) -> void:
	if current_content_plan == null or profile == null:
		return
	var root := Node3D.new()
	root.name = "RuntimeContent"
	add_child(root)
	current_runtime_content_report = CONTENT_RUNTIME_CONSUMER.consume(current_content_plan, profile, root)


func _validate_runtime_content_navigation() -> void:
	var root := get_node_or_null("RuntimeContent") as Node3D
	if root == null or nav_region == null:
		return
	var map := nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, start_point)
	var rejected: Array[String] = []
	for child in root.get_children():
		if not child is Enemy:
			continue
		var target := NavigationServer3D.map_get_closest_point(map, (child as Node3D).global_position)
		var path := NavigationServer3D.map_get_path(map, start, target, true)
		if path.size() <= 1:
			rejected.append(String(child.get_meta("content_slot_id", &"")))
			child.queue_free()
	if not rejected.is_empty():
		current_runtime_content_report["navigation_rejected"] = rejected


func get_runtime_content_metrics() -> Dictionary:
	return current_runtime_content_report.duplicate(true)


func _content_slot_is_safe(slot: DungeonContentSlot, modules: Node3D) -> bool:
	var role: StringName = current_plan.module_types.get(slot.node_id, &"")
	if role in [&"START", &"EXIT"] or modules == null:
		return false
	var module := modules.get_node_or_null(NodePath(String(slot.node_id))) as Node3D
	if module == null:
		return false
	for child in module.get_children():
		if child is Marker3D and slot.global_transform.origin.distance_to((child as Marker3D).global_position) < slot.connector_clearance_m:
			return false
	return true


func _content_slot_color(category: StringName) -> Color:
	match category:
		&"ENCOUNTER": return Color(0.95, 0.18, 0.15, 1.0)
		&"LOOT": return Color(1.0, 0.78, 0.12, 1.0)
		&"EVENT": return Color(0.75, 0.25, 0.95, 1.0)
		&"INTERACTION": return Color(0.12, 0.85, 0.95, 1.0)
		&"SPECIAL": return Color(0.95, 0.95, 0.95, 1.0)
		_: return Color(0.7, 0.7, 0.7, 1.0)


func get_runtime_counts() -> Dictionary:
	var assembled := get_node_or_null("AssembledModules")
	var proxy_root := get_node_or_null("NavigationBakeProxies")
	var region_count := 0
	var sealed_unused := 0
	var unsealed_unused := 0
	for child in get_children():
		if child is NavigationRegion3D:
			region_count += 1
	for result in enclosure_results:
		if bool(result.get("sealed", false)):
			sealed_unused += 1
		elif not bool(result.get("connected", false)):
			unsealed_unused += 1
	return {
		"modules": assembled.get_child_count() if assembled != null else 0,
		"proxies": proxy_root.get_child_count() if proxy_root != null else 0,
		"regions": region_count,
		"sync_state": nav_sync_state,
		"sync_cycles": nav_sync_cycles,
		"sync_attempts": nav_sync_attempts,
		"placement_attempt": int(placement_stats.get("attempt", 0)),
		"placement_candidates": int(placement_stats.get("candidate_checks", 0)),
		"placement_alternates": int(placement_stats.get("alternate_candidates", 0)),
		"placement_backtracks": int(placement_stats.get("backtracks", 0)),
		"placement_backtrack_nodes": placement_stats.get("backtrack_nodes", []),
		"sector_retry_index": sector_retry_index,
		"sector_effective_seed": sector_effective_seed,
		"sector_generation_attempts": sector_generation_attempts,
		"sector_attempt_reports": sector_attempt_reports.duplicate(true),
		"enclosure_openings": enclosure_results.size(),
		"enclosure_sealed_unused": sealed_unused,
		"enclosure_unsealed_unused": unsealed_unused,
		"enclosure_valid": enclosure_valid,
	}
