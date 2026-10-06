extends Node

const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")

const CASES := [
	{"seed": 65001, "path": &"GROUND_ONLY"},
	{"seed": 65003, "path": &"GROUND_BASEMENT"},
	{"seed": 65005, "path": &"GROUND_UPPER"},
	{"seed": 65012, "path": &"JUNCTION_SOUTH"},
]
const EXPECTED := {
	&"CENTRAL_HUB": {"definition": &"base_central_hub_large", "size": Vector2(16, 16)},
	&"BARRACKS": {"definition": &"base_barracks", "size": Vector2(14, 10)},
	&"VARKHEM_ROOM": {"definition": &"base_varkhem_private_room", "size": Vector2(6, 6)},
	&"COMMAND_ROOM": {"definition": &"base_command_room", "size": Vector2(14, 12)},
	&"PRISON": {"definition": &"base_prison", "size": Vector2(12, 10)},
	&"ARMORY": {"definition": &"base_armory", "size": Vector2(10, 10)},
	&"FOOD_STORAGE": {"definition": &"base_food_storage", "size": Vector2(10, 8)},
}

func _ready() -> void:
	var dungeon: Node3D = STAGE.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65001
	add_child(dungeon)
	var valid := true
	var cases := CASES
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		cases = []
		for item in CASES:
			if int(item.seed) == int(args[0]): cases.append(item)
	for item in cases:
		await dungeon.regenerate(int(item.seed))
		await _await_result(dungeon)
		var case_valid := await _validate_run(dungeon, StringName(item.path))
		print("6K.4B DIRECTED seed=%d path=%s valid=%s error=%s" % [item.seed, item.path, case_valid, dungeon.assembly_error])
		valid = valid and case_valid
	if valid:
		print("Stage6K.4B Varkhem hierarchy physical directed: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6K.4B Varkhem hierarchy physical directed: FAIL")
		get_tree().quit(1)


func _await_result(dungeon: Node3D) -> void:
	for _frame in 800:
		if dungeon.nav_ready or not dungeon.assembly_error.is_empty(): return
		await get_tree().physics_frame


func _validate_run(dungeon: Node3D, expected_path: StringName) -> bool:
	if not dungeon.assembly_valid or not dungeon.nav_ready or dungeon.nav_region == null:
		return false
	var first_sector_valid := await _validate_sector(dungeon)
	var valid := first_sector_valid
	if expected_path == &"JUNCTION_SOUTH":
		valid = valid and dungeon.get_selected_module_definitions().values().has(&"base_hub_junction_south")
	if dungeon.sector_run.sector_count() > 1:
		var hp := RunState.player_health
		var oxygen := RunState.oxygen_current
		var stats: Variant = RunState.character_stats
		var dna := DNAManager.dna.duplicate(true)
		var loadout := RunState.equipped_loadout
		var counts_before: Dictionary = dungeon.get_runtime_counts()
		await dungeon.advance_sector_from_debug()
		await _await_result(dungeon)
		var nav_valid: bool = dungeon.assembly_valid and dungeon.nav_ready
		var persistence_valid: bool = RunState.player_health == hp and is_equal_approx(RunState.oxygen_current, oxygen) and RunState.character_stats == stats and DNAManager.dna == dna and RunState.equipped_loadout == loadout
		var counts_after: Dictionary = dungeon.get_runtime_counts()
		var cleanup_valid := int(counts_before.regions) == 1 and int(counts_after.regions) == 1 and int(counts_after.assembled_modules) > 0
		var next_sector_valid := await _validate_sector(dungeon)
		print("6K.4B TRANSITION first=%s nav=%s persistence=%s cleanup=%s second=%s counts=%s" % [first_sector_valid, nav_valid, persistence_valid, cleanup_valid, next_sector_valid, counts_after])
		valid = valid and nav_valid and persistence_valid and cleanup_valid and next_sector_valid
	return valid


func _validate_sector(dungeon: Node3D) -> bool:
	var plan: DungeonPlan = dungeon.current_plan
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	if plan == null or root == null: return false
	var map: RID = dungeon.nav_region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, dungeon.start_point)
	var valid: bool = dungeon._seam_results.size() > 0
	var by_semantic: Dictionary = {}
	for location in plan.semantic_locations:
		by_semantic[location.definition.semantic_id] = location
		if EXPECTED.has(location.definition.semantic_id):
			var expected: Dictionary = EXPECTED[location.definition.semantic_id]
			var placed_definition: ModuleDefinitionResource = plan.module_definitions.get(location.node_id, null)
			var module := root.get_node_or_null(NodePath(String(location.node_id))) as Node3D
			var actual_size: Vector2 = module.get_meta("footprint_size", Vector2.ZERO) if module != null else Vector2.ZERO
			var trace_definition := _trace_definition(dungeon, location.node_id)
			var correct: bool = placed_definition != null and placed_definition.stable_id == expected.definition and trace_definition == expected.definition and actual_size == expected.size
			print("6K.4B SEMANTIC id=%s node=%s definition=%s trace=%s footprint=%s transform=%s correct=%s" % [location.definition.semantic_id, location.node_id, placed_definition.stable_id if placed_definition != null else "NONE", trace_definition, actual_size, module.global_transform if module != null else Transform3D.IDENTITY, correct])
			valid = valid and correct
			if module != null:
				var point := NavigationServer3D.map_get_closest_point(map, module.global_position + Vector3(0, 0.9, 0))
				valid = valid and _has_path(map, start, point) and _has_path(map, point, start)
	if by_semantic.has(&"CENTRAL_HUB"):
		var hub_location: DungeonSemanticLocation = by_semantic[&"CENTRAL_HUB"]
		var hub := root.get_node_or_null(NodePath(String(hub_location.node_id))) as Node3D
		var neighbors := _neighbors(plan, hub_location.node_id)
		valid = valid and hub_location.definition.space_kind == SemanticLocationResource.SpaceKind.TRANSIT and neighbors.size() >= 3
		var hub_point := NavigationServer3D.map_get_closest_point(map, hub.global_position + Vector3(0, 0.9, 0))
		for neighbor_id in neighbors:
			var neighbor := root.get_node_or_null(NodePath(String(neighbor_id))) as Node3D
			if neighbor == null: valid = false; continue
			var neighbor_point := NavigationServer3D.map_get_closest_point(map, neighbor.global_position + Vector3(0, 0.9, 0))
			valid = valid and _has_path(map, hub_point, neighbor_point) and _has_path(map, neighbor_point, hub_point)
		print("6K.4B HUB node=%s footprint=%s functional_neighbors=%s" % [hub_location.node_id, hub.get_meta("footprint_size", Vector2.ZERO), neighbors])
	for semantic_id in [&"CENTRAL_HUB", &"COMMAND_ROOM", &"PRISON"]:
		if not by_semantic.has(semantic_id): continue
		var location: DungeonSemanticLocation = by_semantic[semantic_id]
		var module := root.get_node_or_null(NodePath(String(location.node_id))) as Node3D
		if module == null: valid = false; continue
		var point := NavigationServer3D.map_get_closest_point(map, module.global_position + Vector3(0, 0.9, 0))
		valid = valid and await _walk(map, start, point) and await _walk(map, point, start)
	return valid


func _neighbors(plan: DungeonPlan, node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for child in plan.links.get(node_id, []):
		if not result.has(child): result.append(child)
	for parent in plan.links:
		if (plan.links[parent] as Array).has(node_id) and not result.has(parent): result.append(parent)
	return result


func _trace_definition(dungeon: Node3D, node_id: StringName) -> StringName:
	for entry in dungeon.assembly_trace:
		if entry.get("id", &"") == node_id: return entry.get("definition", &"")
	return &""


func _walk(map: RID, start: Vector3, target: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(map, start, target, true)
	if path.size() < 2: return false
	var body := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4; capsule.height = 1.8; collision.shape = capsule
	body.add_child(collision); add_child(body); body.global_position = Vector3(start.x, 0.9, start.z)
	var index := 1
	for _tick in 2000:
		while index < path.size() and Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(path[index].x, path[index].z)) < 0.7: index += 1
		var goal: Vector3 = target if index >= path.size() else path[index]
		var direction := goal - body.global_position; direction.y = 0.0
		body.velocity = direction.normalized() * 25.0 if direction.length() > 0.01 else Vector3.ZERO
		body.move_and_slide()
		if Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) < 0.35:
			body.queue_free(); return true
		await get_tree().physics_frame
	body.queue_free()
	return false


func _has_path(map: RID, start: Vector3, target: Vector3) -> bool:
	return NavigationServer3D.map_get_path(map, start, target, true).size() >= 2
