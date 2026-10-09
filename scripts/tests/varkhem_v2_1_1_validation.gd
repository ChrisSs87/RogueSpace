extends "res://scripts/tests/varkhem_v2_1_validation.gd"

class ComparisonStage extends "res://scripts/world/Stage6GProceduralPrototype.gd":
	var comparison_archetype: DungeonArchetypeResource
	func _selected_archetype() -> DungeonArchetypeResource:
		return comparison_archetype

var comparison: DungeonArchetypeResource


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--inspection"):
		await _inspection_smoke()
		return
	await super._ready()


func _test_archetype() -> DungeonArchetypeResource:
	if comparison != null:
		return comparison
	comparison = ARCHETYPE
	# Read-only comparison with the approved V2.1 worktree, never edit it.
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--baseline-root="):
			continue
		var root := argument.trim_prefix("--baseline-root=")
		comparison = load(root + "/resources/run/test_archetypes/VarkhemBase.tres").duplicate(true)
		for sector in comparison.sectors:
			sector.template_pool = [load(root + "/resources/run/test_templates/TestVarkhemBaseSemantic.tres"), load(root + "/resources/run/test_templates/TestVarkhemLateWing.tres")]
		for path in comparison.sector_paths:
			for sector in path.sectors:
				sector.template_pool = [load(root + "/resources/run/test_templates/TestVarkhemBaseSemantic.tres"), load(root + "/resources/run/test_templates/TestVarkhemLateWing.tres")]
	return comparison


func _new_dungeon() -> Node3D:
	var result := ComparisonStage.new()
	result.comparison_archetype = _test_archetype()
	return result


func _row(plan: DungeonPlan, run: DungeonSectorRun, index: int) -> Dictionary:
	var row := super._row(plan,run,index)
	var decisions := 0
	for id in plan.module_ids:
		if plan.links.get(id,[]).size() > 1:
			decisions += 1
	row["decisions"] = decisions
	row["reconnections"] = plan.reconnections.size()
	return row


func _additional_physical_metrics(dungeon: Node3D) -> Dictionary:
	var plan: DungeonPlan = dungeon.current_plan
	var modules: Node3D = dungeon.get_node("AssembledModules")
	var bounds: AABB = dungeon._world_bounds(modules.get_child(0))
	var neighbors := {}
	for id in plan.module_ids:
		neighbors[id] = []
	for parent in plan.links:
		for child in plan.links[parent]:
			neighbors[parent].append(child)
			neighbors[child].append(parent)
	for module in modules.get_children():
		bounds = bounds.merge(dungeon._world_bounds(module))
	var longest := 0.0
	for start in neighbors:
		if neighbors[start].size() == 2:
			continue
		for next in neighbors[start]:
			var previous: StringName = start
			var current: StringName = next
			var length := 0.0
			while true:
				var a: Vector3 = modules.get_node(NodePath(String(previous))).global_position
				var b: Vector3 = modules.get_node(NodePath(String(current))).global_position
				length += _meters(NavigationServer3D.map_get_path(dungeon.nav_region.get_navigation_map(),a,b,true))
				if neighbors[current].size() != 2:
					break
				var following: StringName = neighbors[current][0] if neighbors[current][0] != previous else neighbors[current][1]
				previous = current
				current = following
			longest = maxf(longest,length)
	var command_presentations := 0
	for location in plan.semantic_locations:
		if location.definition.semantic_id == &"COMMAND_ROOM":
			var module := modules.get_node(NodePath(String(location.node_id)))
			command_presentations += int(module.has_node("SemanticPresentation"))
	return {"footprint_x":bounds.size.x,"footprint_z":bounds.size.z,"footprint_rect_area":bounds.size.x*bounds.size.z,"longest_unbranched_m":longest,"command_presentations":command_presentations}


func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors: Array = []
	for location in dungeon.current_plan.semantic_locations:
		if location.definition.visual_presentation == null:
			continue
		var module: Node3D = dungeon.get_node("AssembledModules").get_node(NodePath(String(location.node_id)))
		var visual := module.get_node_or_null("SemanticPresentation")
		if visual == null:
			errors.append("missing semantic presentation")
			continue
		for node in visual.find_children("*","",true,false):
			if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is CSGShape3D or node.get_script() != null:
				errors.append("non-visual semantic presentation node")
			if node.has_meta("connector_side"):
				var connected := false
				for opening in dungeon.enclosure_results:
					if opening.module == location.node_id and opening.side == node.get_meta("connector_side"):
						connected = bool(opening.connected)
				if node.visible != connected:
					errors.append("entry trim on unused opening")
	return errors


func _inspection_smoke() -> void:
	var stage = load(_inspection_scene_path()).instantiate()
	stage.initial_seed = 65002
	add_child(stage)
	await _await_sector(stage)
	await get_tree().process_frame
	var inspector = stage.get_node("Inspection")
	inspector.refresh_geometry()
	inspector.fit()
	var player: Node3D = stage.get_node("Player")
	var player_transform := player.global_transform
	var head_transform: Transform3D = player.get_node("Head").transform
	var oxygen: float = RunState.oxygen_current
	var expected_edges := 0
	for id in stage.current_plan.links:
		expected_edges += stage.current_plan.links[id].size()
	var valid: bool = stage.nav_ready and stage.assembly_valid
	valid = valid and stage.get_node("CombatUI").layer > inspector.layer and stage.get_node("RewardUI").layer > inspector.layer
	valid = valid and inspector.logical_map.nodes.size() == stage.module_count and inspector.logical_map.edges.size() == expected_edges
	inspector.top_view()
	valid = valid and inspector.top_camera.current and inspector.top_camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var camera_size: float = inspector.top_camera.size
	inspector.zoom(0.8)
	valid = valid and inspector.top_camera.size < camera_size
	inspector.fit()
	inspector.toggle_map()
	valid = valid and inspector.logical_map.visible
	inspector.player_view()
	valid = valid and inspector.player_camera.current and player.global_transform == player_transform and player.get_node("Head").transform == head_transform and RunState.oxygen_current == oxygen
	valid = valid and _test_room_passages(stage)
	inspector.new_seed.pressed.emit()
	await _await_sector(stage)
	await get_tree().process_frame
	valid = valid and stage.seed == 65003 and stage.nav_ready and stage.assembly_valid
	inspector.next_sector.pressed.emit()
	await _await_sector(stage)
	await get_tree().process_frame
	valid = valid and stage.current_sector_index == 1 and stage.nav_ready and stage.assembly_valid and _transition_errors(stage,65003,1).is_empty()
	inspector.refresh_geometry()
	valid = valid and inspector.logical_map.nodes.size() == stage.module_count
	# Real manual-scene composition, same public combat boundary as Stage6J gate.
	var enemy: Enemy = stage.get_node("RuntimeContent").get_child(0)
	EventBus.combat_ready.emit(player,[enemy])
	await get_tree().process_frame
	valid = valid and CombatManager.get_combatant_count() == 1 and player.is_frozen and stage.get_node("CombatUI").visible
	inspector.new_seed.pressed.emit()
	await _await_sector(stage)
	await get_tree().process_frame
	valid = valid and stage.seed == 65004 and stage.nav_ready and not player.is_frozen and CombatManager.get_combatant_count() == 0 and not CombatEncounterManager.is_encounter_active() and not is_instance_valid(enemy)
	valid = valid and _additional_inspection_check(stage)
	print("V211_INSPECTION_SMOKE=%s" % valid)
	if OS.get_cmdline_user_args().has("--screenshots"):
		inspector.top_view()
		inspector.logical_map.hide()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture_path("top_view.png"))
		inspector.toggle_map()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture_path("logical_map.png"))
		inspector.logical_map.hide()
		await stage.regenerate(65001)
		await _await_sector(stage)
		for frame in 3:
			await get_tree().process_frame
		inspector.assembly_key = "%d/%d/%s" % [stage.seed,stage.current_sector_index,stage.get_assembly_signature()]
		for location in stage.current_plan.semantic_locations:
			if location.definition.semantic_id != &"COMMAND_ROOM": continue
			var module: Node3D = stage.get_node("AssembledModules").get_node(NodePath(String(location.node_id)))
			inspector.top_active = false
			inspector.top_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			inspector.top_camera.global_position = module.to_global(Vector3(-6.4,1.6,0))
			inspector.top_camera.look_at(module.to_global(Vector3(0,1.2,0)))
			inspector.top_camera.make_current()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_capture_path("command_room.png"))
	get_tree().quit(0 if valid else 1)


func _inspection_scene_path() -> String:
	return "res://scenes/tests/VarkhemV211ExperienceTest.tscn"


func _additional_inspection_check(_stage: Node3D) -> bool:
	return true


func _capture_path(filename: String) -> String:
	var directory := "user://varkhem_v2_1_1_captures"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	return directory.path_join(filename)


func _test_room_passages(stage: Node3D) -> bool:
	# Move the REAL runtime Player/Enemy bodies across connected room thresholds.
	# AI is disabled only synchronously during this test and then restored.
	var bodies: Array[CharacterBody3D] = [stage.get_node("Player"),stage.get_node("RuntimeContent").get_child(0)]
	var valid := true
	var crossings := 0
	for body in bodies:
		var saved_transform := body.global_transform
		var saved_physics := body.is_physics_processing()
		body.set_physics_process(false)
		for opening in stage.enclosure_results:
			if not opening.connected or stage.current_plan.module_types[opening.module] not in [&"ROOM",&"SIDE_ROOM"]:
				continue
			var connector: Marker3D = opening.connector
			var outward := -connector.global_basis.z.normalized()
			var from: Vector3 = connector.global_position+outward*0.9+Vector3(0,0.95,0)
			body.global_position = from
			body.move_and_collide(-outward*1.8)
			valid = valid and body.global_position.distance_to(from-outward*1.8) < 0.05
			crossings += 1
		body.global_transform = saved_transform
		body.set_physics_process(saved_physics)
	print("V211_REAL_BODY_PASSAGES count=%d valid=%s" % [crossings,valid])
	return valid and crossings > 0
