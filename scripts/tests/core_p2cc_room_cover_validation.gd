extends "res://scripts/tests/core_p2cb_hub_cover_validation.gd"

var legacy_configured := false
var room_metrics := {}

class IsolatedStage extends "res://scripts/world/Stage6GProceduralPrototype.gd":
	func _ready() -> void: pass

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--food-fixture"):
		await _food_fixture()
		return
	if OS.get_cmdline_user_args().has("--find-food"):
		for seed in range(65007,65101):
			var run := DungeonArchetypeDirector.new().create_sector_run(ARCHETYPE,seed)
			for sector in run.sector_plans.size():
				for location in run.sector_plans[sector].semantic_locations:
					if location.definition.semantic_id == &"FOOD_STORAGE":
						print("P2CC_FOOD_SEED="+JSON.stringify({"seed":seed,"sector":sector}))
						get_tree().quit(0)
						return
		print("P2CC_FOOD_SEED=NOT_FOUND")
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--configuration"):
		var profile: RoomEnvironmentProfileResource = load("res://resources/run/VarkhemRoomEnvironment.tres")
		var valid: bool = profile.room_cover_candidates.size() == 6 and profile.duplicate(true).room_cover_candidates.size() == 6 and RoomEnvironmentProfileResource.new().room_cover_candidates.is_empty()
		print("P2CC_CONFIG="+JSON.stringify({"valid":valid,"candidates":profile.room_cover_candidates,"script":profile.get_script().resource_path}))
		get_tree().quit(0 if valid else 1)
		return
	await super._ready()

## Existing, optional catalogue room absent from the reference nine sectors.
## Real module factory, definition/slots, floor/walls, cover factory and B+C bake;
## this is an isolated module test, not a claimed procedural FOOD occurrence.
func _food_fixture() -> void:
	var food: SemanticLocationResource
	for sector in ARCHETYPE.sectors:
		for location in sector.semantic_locations:
			if location.semantic_id == &"FOOD_STORAGE": food = location
	if food == null:
		print("P2CC_FOOD_FIXTURE="+JSON.stringify({"valid":false,"reason":"missing real semantic resource"}))
		get_tree().quit(1)
		return
	var definition: ModuleDefinitionResource = food.physical_module_variants[0]
	var stage := IsolatedStage.new()
	add_child(stage)
	var modules := Node3D.new()
	stage.add_child(modules)
	var module: Node3D = stage._make_module(&"FOOD_FIXTURE",&"ROOM",definition)
	modules.add_child(module)
	var plan := DungeonPlan.new()
	plan.module_types[&"FOOD_FIXTURE"] = &"ROOM"
	plan.module_definitions[&"FOOD_FIXTURE"] = definition
	plan.links[&"FOOD_FIXTURE"] = []
	var semantic := DungeonSemanticLocation.new()
	semantic.definition = food
	semantic.node_id = &"FOOD_FIXTURE"
	plan.semantic_locations.append(semantic)
	var profile: RoomEnvironmentProfileResource = ARCHETYPE.room_environment_profile
	var report := BUILDER.build(plan,modules,profile,65001)
	await stage._bake(modules)
	var valid: bool = await stage._await_navigation_ready()
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector3(100,1,100)
	var pockets: Array = []
	for cover in module.get_children():
		if not cover is LogicalCover: continue
		var access := BUILDER.room_access_positions(module,cover,stage.nav_region.get_navigation_map(),player.get_node("CollisionShape3D").shape)
		valid = valid and access.any(func(p): return p.accessible)
		var floor_point: Vector3 = cover.global_position
		floor_point.y = module.global_position.y
		var projected := NavigationServer3D.map_get_closest_point(stage.nav_region.get_navigation_map(),floor_point)
		valid = valid and Vector2(projected.x-floor_point.x,projected.z-floor_point.z).length() >= 0.45
		pockets.append({"category":cover.category,"positions":access})
	valid = valid and definition.footprint_size == Vector2(10,8) and report.covers.size() == 2 and report.rooms[0].interior == 1 and report.rooms[0].lateral == 1
	print("P2CC_FOOD_FIXTURE="+JSON.stringify({"valid":valid,"module":definition.stable_id,"footprint":definition.footprint_size,"report":report,"pockets":pockets,"dynamic":"INCOMPLETE"}))
	get_tree().quit(0 if valid else 1)

func _test_archetype() -> DungeonArchetypeResource:
	var resource := super._test_archetype()
	if OS.get_cmdline_user_args().has("--legacy") and not legacy_configured:
		comparison = resource.duplicate(true)
		comparison.room_environment_profile.room_cover_candidates = []
		legacy_configured = true
	return comparison

func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	var profile: RoomEnvironmentProfileResource = dungeon.active_archetype.room_environment_profile
	if not OS.get_cmdline_user_args().has("--legacy") and profile.room_cover_candidates.size() != 6: errors.append("room candidate configuration not consumed")
	var modules: Node3D = dungeon.get_node("AssembledModules")
	var map: RID = dungeon.nav_region.get_navigation_map()
	room_metrics = {"rooms":dungeon.current_room_environment_report.get("rooms",[]).size(),"rooms_with_cover":0,"objects":0,"interior":0,"lateral":0,"accessible_positions":0,"los_positions":0,"nav_errors":0,"rooms_audit":[],"dynamic_tactics":"INCOMPLETE"}
	var visited := {}
	for row in dungeon.current_room_environment_report.covers:
		if row.semantic == &"CENTRAL_HUB": continue
		if row.semantic not in [&"BARRACKS",&"ARMORY",&"FOOD_STORAGE"]: errors.append("unsupported room furnished")
		var module: Node3D = modules.get_node(NodePath(String(row.node)))
		var definition: ModuleDefinitionResource = dungeon.current_plan.module_definitions[row.node]
		var cover: LogicalCover = null
		for child in module.get_children():
			if child is LogicalCover and child.position == row.position: cover = child
		if cover == null:
			errors.append("missing actual room cover")
			continue
		visited[row.node] = true
		room_metrics.objects += 1
		room_metrics["interior" if row.placement == "INTERIOR" else "lateral"] += 1
		var bounds := AABB(row.position-row.size*0.5,row.size)
		if not BUILDER._distribution_rejection(definition,definition.footprint_size,bounds,profile).is_empty(): errors.append("accepted unsafe room candidate")
		for other in module.get_children():
			if other is LogicalCover and other != cover:
				var other_size: Vector3 = other.get_child(0).shape.size
				if bounds.grow(0.55).intersects(AABB(other.position-other_size*0.5,other_size)): errors.append("room prop reserve overlap")
		# Same static walk and LOS sampling for baseline and candidate builds.
		var player: CharacterBody3D = PLAYER.instantiate()
		add_child(player)
		player.set_physics_process(false)
		var pockets := BUILDER.room_access_positions(module,cover,map,player.get_node("CollisionShape3D").shape)
		var los_positions := 0
		var accessible := 0
		var observations: Array = []
		for pocket in pockets:
			if not pocket.accessible: continue
			accessible += 1
			player.movement_state = player.MovementState.WALK
			player._update_posture(1.0)
			player.global_position = pocket.world+Vector3.UP*0.86
			var samples := _sample_routes(dungeon,cover,player)
			if samples.blocked_samples > 0: los_positions += 1
			observations.append({"position":pocket.world,"route_samples":samples})
		player.free()
		if accessible == 0:
			room_metrics.nav_errors += 1
			errors.append("room cover has no accessible pocket")
		room_metrics.accessible_positions += accessible
		room_metrics.los_positions += los_positions
		room_metrics.rooms_audit.append({"node":row.node,"semantic":row.semantic,"placement":row.placement,"position":row.position,"category":row.category,"pockets":pockets,"los_posture":observations,"dynamic_tactics":"INCOMPLETE"})
		# Invalid declared positions must fail and preserve fallback, never force.
		var invalid: RoomEnvironmentProfileResource = profile.duplicate(true)
		invalid.room_cover_candidates = [{"id":"axis_probe","semantic":row.semantic,"position_fraction":Vector2.ZERO}]
		var location: DungeonSemanticLocation
		for semantic in dungeon.current_plan.semantic_locations:
			if semantic.node_id == row.node: location = semantic
		var occupied: Array[AABB] = []
		var audit := {"examined":[]}
		if not BUILDER._room_candidate(definition,definition.footprint_size,row.size,invalid,dungeon.seed,location,0,occupied,audit).is_empty(): errors.append("invalid interior candidate forced")
		if audit.examined.is_empty() or audit.examined[0].reason != "reserved circulation/access cross": errors.append("missing explicit axis rejection")
	room_metrics.rooms_with_cover = visited.size()
	print("P2CC_ROOMS="+JSON.stringify({"seed":dungeon.seed,"sector":dungeon.current_sector_index,"legacy":OS.get_cmdline_user_args().has("--legacy"),"metrics":room_metrics,"errors":errors}))
	return errors

## Multiple endpoints/midpoints on both patrol directions, not one instantaneous
## guard pose. This proves static interposition opportunities, not timed evasion.
func _sample_routes(dungeon: Node3D, cover: LogicalCover, player: CharacterBody3D) -> Dictionary:
	var result := {"samples":0,"blocked_samples":0,"in_fov_blocked":0,"guards":[],"scope":"MULTI_ROUTE_STATIC_LOS","dynamic":"INCOMPLETE"}
	for guard: Enemy in dungeon.get_node("RuntimeContent").get_children():
		var points: Array = guard.get_meta("patrol_world_points",[])
		if points.size() < 2: continue
		var blocked := 0
		var eye_offset := guard.get_vision_origin()-guard.global_position
		for index in points.size():
			var from: Vector3 = points[index]
			var to: Vector3 = points[(index+1)%points.size()]
			for fraction in [0.0,0.5,1.0]:
				var origin := from.lerp(to,fraction)+eye_offset
				var toward := player.global_position-origin
				toward.y = 0.0
				if toward.length() > guard.get_debug_fov_range_m(): continue
				player.movement_state = player.MovementState.WALK
				player._update_posture(1.0)
				var stand_target: Vector3 = player.get_node("Head").global_position
				# Remove only logical props from the diagnostic baseline ray;
				# walls remain. No collider or production mask is changed.
				var excluded: Array[RID] = [guard.get_rid()]
				for prop: LogicalCover in get_tree().get_nodes_in_group("logical_cover"): excluded.append(prop.get_rid())
				var ray := PhysicsRayQueryParameters3D.create(origin,stand_target,1,excluded)
				if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
				result.samples += 1
				var stand_los := guard._has_clear_vision_line(origin,stand_target,player)
				player.movement_state = player.MovementState.STEALTH
				player._update_posture(1.0)
				var crouch_target: Vector3 = player.get_node("Head").global_position
				var crouch_los := guard._has_clear_vision_line(origin,crouch_target,player)
				var expected := not stand_los if cover.category == LogicalCover.Category.HIGH else stand_los and not crouch_los
				if expected and cover.interposes(origin,crouch_target):
					blocked += 1
					result.blocked_samples += 1
					var heading := to-from
					heading.y = 0.0
					if heading.angle_to(toward) <= deg_to_rad(guard.enemy_resource.vision_angle_deg*0.5): result.in_fov_blocked += 1
		if blocked > 0: result.guards.append({"slot":guard.get_meta("content_slot_id"),"blocked_samples":blocked})
	return result

func _additional_physical_metrics(dungeon: Node3D) -> Dictionary:
	var result := super._additional_physical_metrics(dungeon)
	result["room_tactics"] = room_metrics.duplicate(true)
	return result
