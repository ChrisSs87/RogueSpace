extends Node3D

func _ready() -> void:
	var dungeon: Node3D = $Stage6GProceduralPrototype
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	dungeon.test_template_index = 1
	for seed in [62001, 62006, 62016, 62017, 62019]:
		await dungeon.regenerate(seed)
		_report_plan("CASE_%d" % seed, dungeon)
		_report_alternatives(dungeon)
	get_tree().quit(0)


func _report_plan(label: String, dungeon: Node3D) -> void:
	var plan: DungeonPlan = dungeon.current_plan
	print("6H DIAG %s seed=%d assembly=%s error=%s signature=%s" % [label, dungeon.seed, dungeon.assembly_valid, dungeon.assembly_error, plan.get_topology_signature()])
	var parents: Dictionary = {}
	for parent_id in plan.links:
		for child_id in plan.links[parent_id]:
			parents[child_id] = parent_id
	var trace_by_id: Dictionary = {}
	for entry in dungeon.assembly_trace:
		trace_by_id[entry.id] = entry
	for id in plan.module_ids:
		var definition: ModuleDefinitionResource = plan.module_definitions.get(id)
		var definition_id := definition.stable_id if definition != null else &"NONE"
		var entry: Dictionary = trace_by_id.get(id, {})
		print("6H NODE id=%s role=%s parent=%s children=%s main=%s branch=%s definition=%s connector_parent=%s connector_child=%s transform=%s bounds=%s status=%s conflicts=%s seam=%s" % [id, plan.module_types.get(id, &""), parents.get(id, &""), plan.links.get(id, []), plan.main_path_nodes.has(id), plan.branch_nodes.has(id), definition_id, entry.get("source_connector", ""), entry.get("incoming_connector", ""), entry.get("transform", "UNPLACED"), entry.get("bounds", "UNPLACED"), entry.get("status", "UNPROCESSED"), entry.get("conflicts", []), entry.get("seam_error", "N/A")])


func _report_alternatives(dungeon: Node3D) -> void:
	var failed: Dictionary = {}
	for entry in dungeon.assembly_trace:
		if entry.status == "CANDIDATE" and not Array(entry.conflicts).is_empty():
			failed = entry
			break
	if failed.is_empty():
		print("6H ALTERNATIVE none: no failed candidate trace")
		return
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	var parent := root.get_node_or_null(NodePath(String(failed.parent))) as Node3D
	var plan: DungeonPlan = dungeon.current_plan
	var placed: Dictionary = {}
	for child in root.get_children():
		if child is Node3D:
			placed[StringName(child.name)] = child
	var used_sources: Dictionary = {}
	for entry in dungeon.assembly_trace:
		if entry.get("parent", &"") == failed.parent and entry.get("status", "") == "PLACED":
			used_sources[entry.get("source_connector", "")] = true
	var alternatives := 0
	for source_candidate in parent.get_children():
		if not source_candidate is Marker3D or source_candidate.get_meta("role", "") != "out" or used_sources.has(source_candidate.name):
			continue
		var candidate: Node3D = dungeon._make_module(failed.id, failed.role, plan.module_definitions.get(failed.id))
		root.add_child(candidate)
		var incoming: Marker3D = dungeon._find_available_connector(candidate, "in", {})
		dungeon._align_connectors(candidate, incoming, source_candidate)
		var seam: Dictionary = dungeon._validate_connector_contract(source_candidate, incoming)
		var conflicts: Array = dungeon._overlap_details(candidate, placed)
		print("6H ALTERNATIVE node=%s source=%s transform=%s bounds=%s seam=%s conflicts=%s" % [failed.id, source_candidate.name, candidate.global_transform, dungeon._world_bounds(candidate), seam.error, conflicts])
		alternatives += 1
		candidate.queue_free()
	if alternatives == 0:
		print("6H ALTERNATIVE node=%s none: parent has no unused compatible out connector" % failed.id)
