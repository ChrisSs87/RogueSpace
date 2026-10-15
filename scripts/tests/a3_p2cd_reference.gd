extends "res://scripts/tests/varkhem_v2_1_1_validation.gd"

## Observational audit only. Live AI follows its real routes. A second real
## Player, removed from the perception target group, supplies posture/LOS
## queries; it never feeds sensory events or moves the simulation's target.
## Therefore results are VISUAL COUNTERFACTUALS, not full stealth certification.
const BUILDER := preload("res://scripts/world/RoomEnvironmentBuilder.gd")
const PLAYER := preload("res://scenes/player/Player.tscn")
const SAMPLE_FRAMES := 12 # 0.2 s at the unchanged 60 Hz physics rate.
const SPACING_M := 0.4
var output := ""

func _ready() -> void:
	var first := 65001
	var last := 65006
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="): first = int(arg.trim_prefix("--from="))
		if arg.begins_with("--to="): last = int(arg.trim_prefix("--to="))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var stage: Node3D = load("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate()
	stage.archetype_mode = true
	stage.test_archetype_index = 1
	stage.initial_seed = first
	add_child(stage)
	await _await_sector(stage)
	var player: CharacterBody3D = stage.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-500,1,-500)
	if OS.get_cmdline_user_args().has("--replay"):
		await _replay(stage,player)
		return
	var probe: CharacterBody3D = PLAYER.instantiate()
	add_child(probe)
	probe.remove_from_group("player")
	probe.set_physics_process(false)
	probe.global_position = Vector3(-600,1,-600)
	var reports: Array = []
	for seed in range(first,last+1):
		await stage.regenerate(seed)
		await _await_sector(stage)
		player.global_position = Vector3(-500,1,-500)
		while true:
			if not stage.assembly_valid or not stage.nav_ready:
				reports.append({"seed":seed,"status":"INCOMPLETE","error":stage.assembly_error})
				break
			var row := await _observe(stage,probe)
			reports.append(row)
			print("P2CD_SECTOR="+JSON.stringify(row))
			if stage.current_sector_index == stage.sector_run.sector_count()-1: break
			await stage.advance_sector_from_debug()
			await _await_sector(stage)
			player.global_position = Vector3(-500,1,-500)
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(reports))
	print("P2CD_COMPLETE sectors=%d physics_hz=%d scope=OBSERVATIONAL_NOT_CERTIFICATION" % [reports.size(),Engine.physics_ticks_per_second])
	get_tree().quit(0)

func _seam(a: Node3D,b: Node3D) -> Vector3:
	for x in a.get_children():
		if not x is Marker3D or not x.has_meta("side"): continue
		for y in b.get_children():
			if y is Marker3D and y.has_meta("side") and x.global_position.distance_to(y.global_position) < 0.01:
				return x.global_position
	return Vector3.INF

func _route(stage: Node3D,probe: CharacterBody3D,id: String,from: Vector3,to: Vector3) -> Dictionary:
	probe.global_position = Vector3(-600,1,-600)
	probe.movement_state = probe.MovementState.WALK
	probe._update_posture(1.0)
	var map: RID = stage.nav_region.get_navigation_map()
	var a := NavigationServer3D.map_get_closest_point(map,from)
	var b := NavigationServer3D.map_get_closest_point(map,to)
	var path := NavigationServer3D.map_get_path(map,a,b,true)
	var row := {"id":id,"valid":true,"reason":"","points":[],"distance":0.0,"modes":[]}
	if from == Vector3.INF or to == Vector3.INF or path.size() < 2 or Vector2(a.x-from.x,a.z-from.z).length() > 0.12 or Vector2(b.x-to.x,b.z-to.z).length() > 0.12:
		row.valid = false
		row.reason = "missing physical seam / navigation projection / path"
		return row
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe.get_node("CollisionShape3D").shape
	query.collision_mask = 1
	query.margin = 0.0
	var points: Array[Vector3] = []
	for index in range(path.size()-1):
		var length := path[index].distance_to(path[index+1])
		query.transform = Transform3D(Basis.IDENTITY,path[index]+Vector3.UP*0.89)
		query.motion = path[index+1]-path[index]
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty() or get_world_3d().direct_space_state.cast_motion(query)[0] < 1.0:
			row.valid = false
			row.reason = "static real Player capsule sweep blocked"
		for n in maxi(1,ceili(length/SPACING_M)):
			points.append(path[index].lerp(path[index+1],float(n)/maxi(1,ceili(length/SPACING_M))))
		row.distance += length
	points.append(path[-1])
	row.points = points
	for mode in [probe.MovementState.WALK,probe.MovementState.STEALTH]:
		probe.movement_state = mode
		probe.global_position = Vector3(-600,1,-600)
		probe._update_posture(1.0)
		row.modes.append({"posture":"WALK" if mode == probe.MovementState.WALK else "STEALTH","speed":probe.get_current_speed_mps(),"exposure":[],"individual_exposure":[],"occupancy":[]})
	return row

func _observe(stage: Node3D,probe: CharacterBody3D) -> Dictionary:
	var modules: Node3D = stage.get_node("AssembledModules")
	var plan: DungeonPlan = stage.current_plan
	var guards := stage.get_node("RuntimeContent").get_children()
	var routes: Array = []
	var parents := {}
	for parent in plan.links:
		for child in plan.links[parent]: parents[child] = parent
	var spine: Array[StringName] = [&"START"]
	while spine[-1] != &"EXIT":
		var following: StringName = &""
		for child in plan.links.get(spine[-1],[]):
			if plan.main_path_nodes.has(child): following = child
		if following == &"": break
		spine.append(following)
	for index in range(1,spine.size()-1):
		var id: StringName = spine[index]
		var module: Node3D = modules.get_node(NodePath(String(id)))
		var before: Node3D = modules.get_node(NodePath(String(spine[index-1])))
		var after: Node3D = modules.get_node(NodePath(String(spine[index+1])))
		routes.append(_route(stage,probe,"MAIN/%s" % id,_seam(module,before),_seam(module,after)))
	for id in plan.module_ids:
		if plan.module_types[id] not in [&"ROOM",&"SIDE_ROOM"] or not parents.has(id): continue
		var module: Node3D = modules.get_node(NodePath(String(id)))
		var parent: Node3D = modules.get_node(NodePath(String(parents[id])))
		var entry := _seam(module,parent)
		routes.append(_route(stage,probe,"ROOM/%s/center" % id,entry,module.global_position))
		for cover in module.get_children():
			if not cover is LogicalCover: continue
			var pockets := BUILDER.room_access_positions(module,cover,stage.nav_region.get_navigation_map(),probe.get_node("CollisionShape3D").shape)
			for p in pockets.size():
				if pockets[p].accessible: routes.append(_route(stage,probe,"ROOM/%s/%s/p%d" % [id,cover.name,p],entry,pockets[p].world))
	for index in range(1,spine.size()-1):
		var module: Node3D = modules.get_node(NodePath(String(spine[index])))
		for cover in module.get_children():
			if not cover is LogicalCover: continue
			var pockets := BUILDER.room_access_positions(module,cover,stage.nav_region.get_navigation_map(),probe.get_node("CollisionShape3D").shape)
			for p in pockets.size():
				if not pockets[p].accessible: continue
				var before: Node3D = modules.get_node(NodePath(String(spine[index-1])))
				var after: Node3D = modules.get_node(NodePath(String(spine[index+1])))
				routes.append(_route(stage,probe,"HUB/%s/%s/p%d/in" % [module.name,cover.name,p],_seam(module,before),pockets[p].world))
				routes.append(_route(stage,probe,"HUB/%s/%s/p%d/out" % [module.name,cover.name,p],pockets[p].world,_seam(module,after)))
	var cycle := 0.0
	var guard_rows: Array = []
	for guard: Enemy in guards:
		var points: Array = guard.get_meta("patrol_world_points",[])
		var distance := 0.0
		for index in range(points.size()-1):
			distance += _meters(NavigationServer3D.map_get_path(stage.nav_region.get_navigation_map(),points[index],points[index+1],true))
		var speed := GameBalance.get_speed(guard.enemy_resource.patrol_speed_tier)
		var nominal := 2.0*distance/maxf(speed,0.01)+2.0*maxi(points.size()-1,1)*(guard.patrol_pause_sec+180.0/maxf(guard.patrol_turn_speed_deg,1.0))
		cycle = maxf(cycle,nominal)
		guard_rows.append({"slot":guard.get_meta("content_slot_id"),"kind":guard.get_meta("patrol_kind"),"points":points,"speed":speed,"nominal_cycle_sec":nominal,"distance_observed":0.0,"max_stall":0.0,"yaw_travel_deg":0.0,"indices":{},"states":{},"snapshots":[]})
	# Two conservative nominal cycles, including full 180-degree turn allowance
	# at every end; this is a bounded observation, never proof of impossibility.
	var dt := float(SAMPLE_FRAMES)/Engine.physics_ticks_per_second
	var count := ceili((2.0*cycle+2.0)/dt)
	var previous: Array = guards.map(func(g): return g.global_position)
	var yaw: Array = guards.map(func(g): return g.rotation.y)
	var min_pair := INF
	for tick in count:
		for frame in SAMPLE_FRAMES: await get_tree().physics_frame
		for index in guards.size():
			var guard: Enemy = guards[index]
			var debug := guard.get_patrol_runtime_debug()
			var row: Dictionary = guard_rows[index]
			row.distance_observed += guard.global_position.distance_to(previous[index])
			row.yaw_travel_deg += absf(rad_to_deg(angle_difference(yaw[index],guard.rotation.y)))
			previous[index] = guard.global_position
			yaw[index] = guard.rotation.y
			row.max_stall = maxf(row.max_stall,debug.stall_elapsed_sec)
			row.indices[debug.patrol_index] = true
			row.states[guard.get_debug_state_name()] = true
			row.snapshots.append({"position":guard.global_position,"forward":-guard.global_basis.z,"index":debug.patrol_index,"pause":debug.pause_remaining_sec,"state":guard.get_debug_state_name()})
			for other in range(index+1,guards.size()): min_pair = minf(min_pair,guard.global_position.distance_to(guards[other].global_position))
		for route in routes:
			if not route.valid: continue
			for mode in route.modes:
				probe.global_position = Vector3(-600,1,-600)
				probe.movement_state = probe.MovementState.WALK if mode.posture == "WALK" else probe.MovementState.STEALTH
				probe._update_posture(1.0)
				var visible := ""
				var occupied := ""
				var individual: Array = []
				for guard in guards: individual.append("")
				for point: Vector3 in route.points:
					probe.global_position = point+Vector3.UP*0.86
					var any_visible := false
					var any_occupied := false
					for index in guards.size():
						var guard: Enemy = guards[index]
						var seen := guard._passes_vision_baseline(probe)
						individual[index] += "1" if seen else "0"
						any_visible = any_visible or seen
						var delta := probe.global_position-guard.global_position
						delta.y = 0
						any_occupied = any_occupied or delta.length() < probe.get_node("CollisionShape3D").shape.radius+guard.get_node("CollisionShape3D").shape.radius
					visible += "1" if any_visible else "0"
					occupied += "1" if any_occupied else "0"
				mode.exposure.append(visible)
				mode.individual_exposure.append(individual)
				mode.occupancy.append(occupied)
		probe.global_position = Vector3(-600,1,-600)
	for route in routes:
		if not route.valid: continue
		for mode in route.modes: _windows(route,mode,dt)
	var semantics := {}
	for location in plan.semantic_locations: semantics[location.node_id] = location.definition.semantic_id
	return {"seed":stage.seed,"effective_seed":stage.sector_effective_seed,"sector":stage.sector_run.sector_definitions[stage.current_sector_index].sector_id,"size":stage.sector_run.sector_size_profiles[stage.current_sector_index].size_id,"duration_sec":count*dt,"sample_sec":dt,"routes":routes,"guards":guard_rows,"semantics":semantics,"closest_guards_m":min_pair,"assembly_valid":stage.assembly_valid,"navigation_ready":stage.nav_ready,"classification":"E: sampled visual counterfactual; full sensory traversal INCOMPLETE","limitations":["no Player movement/noise feedback into patrol observation","0.2 s poses and <=0.4 m route samples, not continuous collision/vision proof","guard response would change after seeing/hearing a real crossing","nominal two cycles do not prove globally impossible evasion"]}

func _windows(route: Dictionary,mode: Dictionary,dt: float) -> void:
	var times: Array = [0.0]
	for index in range(1,route.points.size()): times.append(times[-1]+route.points[index-1].distance_to(route.points[index])/mode.speed)
	mode.crossing_sec = times[-1]
	var valid: Array = []
	var wait_safe: Array = []
	var endpoint_run := 0
	var longest_endpoint := 0
	for start in mode.exposure.size():
		var endpoint_safe: bool = mode.exposure[start][0] == "0" and mode.occupancy[start][0] == "0"
		endpoint_run = endpoint_run+1 if endpoint_safe else 0
		longest_endpoint = maxi(longest_endpoint,endpoint_run)
		if start+ceili(mode.crossing_sec/dt)+1 >= mode.exposure.size(): break
		var safe := true
		for point in times.size():
			var tick: int = start+floori(times[point]/dt)
			# Both bracketing poses must agree: no favorable interpolation.
			for k in [tick,tick+1]:
				if mode.exposure[k][point] == "1" or mode.occupancy[k][point] == "1": safe = false
		if safe:
			valid.append(start*dt)
			# Waiting is checked for the full interval from observation start.
			if endpoint_run >= start+1: wait_safe.append(start*dt)
	mode.departures_sec = valid
	mode.departures_with_safe_wait_from_t0 = wait_safe
	mode.longest_start_safe_sec = longest_endpoint*dt
	var longest_departure := 0
	var departure_run := 0
	var previous := -2.0*dt
	for start: float in valid:
		departure_run = departure_run+1 if absf(start-previous-dt) < 0.001 else 1
		longest_departure = maxi(longest_departure,departure_run)
		previous = start
	mode.longest_departure_window_sec = longest_departure*dt
	mode.point_windows = []
	for point in [0,floori(route.points.size()/2.0),route.points.size()-1]:
		var runs: Array = []
		for guard in mode.individual_exposure[0].size()+1:
			var longest := 0
			var run := 0
			for tick in mode.exposure.size():
				var exposed: bool = mode.exposure[tick][point] == "1" if guard == mode.individual_exposure[0].size() else mode.individual_exposure[tick][guard][point] == "1"
				run = 0 if exposed else run+1
				longest = maxi(longest,run)
			runs.append(longest*dt)
		mode.point_windows.append({"point":point,"longest_unseen_by_each_guard_then_combined_sec":runs})
	mode.visual_class = "D_NO_SAMPLED_WHOLE_ROUTE_WINDOW" if valid.is_empty() else ("A_SAMPLED_ZERO_EXPOSURE" if valid[0] == 0.0 else ("B_SAMPLED_SAFE_WAIT" if not wait_safe.is_empty() else "C_WINDOW_WITHOUT_PROVEN_WAIT"))
	mode.integral_class = "E_INCOMPLETE_NO_REAL_PLAYER_NOISE_REPLAY"

## Optional independent checkpoint replay. Real Player inputs, movement,
## noise, normal Enemy ticks and encounters. Initial checkpoint placement is
## explicit; success is local, not a START->EXIT stealth claim.
func _replay(stage: Node3D,player: CharacterBody3D) -> void:
	var source := ""
	var wanted := "MAIN/NODE_0"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="): source = arg.trim_prefix("--source=")
		if arg.begins_with("--route="): wanted = arg.trim_prefix("--route=")
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(source))
	var selected := {}
	for sector in records:
		if int(sector.seed) != stage.seed or sector.sector != String(stage.sector_run.sector_definitions[0].sector_id): continue
		for route in sector.routes:
			if route.id == wanted and route.valid: selected = route
	if selected.is_empty():
		print("P2CD_REPLAY=FAIL_FIXTURE missing recorded valid route")
		get_tree().quit(1)
		return
	var from := _vector(selected.points[0])
	var to := _vector(selected.points[-1])
	var path := NavigationServer3D.map_get_path(stage.nav_region.get_navigation_map(),from,to,true)
	if path.size() < 2:
		print("P2CD_REPLAY=FAIL_FIXTURE no real path")
		get_tree().quit(1)
		return
	var mode: Dictionary = selected.modes[1]
	var departure: float = mode.departures_with_safe_wait_from_t0[0] if not mode.departures_with_safe_wait_from_t0.is_empty() else (mode.departures_sec[0] if not mode.departures_sec.is_empty() else 0.0)
	var report := {"seed":stage.seed,"route":wanted,"departure_sec":departure,"expected_crossing_sec":mode.crossing_sec,"actual_distance":0.0,"arrived":false,"vision_frames":0,"confirmed_frames":0,"sound_events":0,"states":{},"samples":[],"scope":"REAL_PLAYER_LOCAL_CHECKPOINT_NOT_GLOBAL_ROUTE"}
	var noise_callback := func(_position,_radius,_intensity): report.sound_events += 1
	EventBus.player_noise_emitted.connect(noise_callback)
	Input.action_press("stealth")
	player.global_position = from+Vector3.UP*0.86
	player.set_physics_process(true)
	var next := 1
	var last := player.global_position
	var hz := Engine.physics_ticks_per_second
	# Geometric travel time + discrete waypoint arrival tolerance budget.
	var max_sec: float = departure+mode.crossing_sec+path.size()*0.16/mode.speed+1.0
	for frame in ceili(max_sec*hz):
		var now := float(frame)/hz
		for action in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
		if now >= departure and next < path.size():
			var toward := path[next]-player.global_position
			toward.y = 0.0
			if toward.length() < 0.16:
				next += 1
			else:
				var local := player.global_basis.inverse()*toward.normalized()
				if absf(local.x) > 0.001: Input.action_press("move_right" if local.x > 0 else "move_left",absf(local.x))
				if absf(local.z) > 0.001: Input.action_press("move_back" if local.z > 0 else "move_forward",absf(local.z))
		await get_tree().physics_frame
		var displacement := player.global_position-last
		displacement.y = 0.0
		report.actual_distance += displacement.length()
		last = player.global_position
		var vision := false
		var confirmed := false
		var poses: Array = []
		for guard: Enemy in stage.get_node("RuntimeContent").get_children():
			vision = guard._passes_vision_baseline(player) or vision
			confirmed = guard.has_confirmed_visual_contact(player) or confirmed
			report.states[guard.get_debug_state_name()] = true
			if frame % SAMPLE_FRAMES == 0: poses.append({"slot":guard.get_meta("content_slot_id"),"state":guard.get_debug_state_name(),"position":guard.global_position,"patrol":guard.get_patrol_runtime_debug()})
		if vision: report.vision_frames += 1
		if confirmed: report.confirmed_frames += 1
		if frame % SAMPLE_FRAMES == 0: report.samples.append({"sec":now,"player":player.global_position,"guards":poses})
		var flat := player.global_position-to
		flat.y = 0
		if now >= departure and flat.length() < 0.2:
			report.arrived = true
			report.elapsed_sec = now
			break
		if ExplorationState.is_suspended():
			report.encounter_suspended = true
			break
	for action in ["stealth","move_left","move_right","move_forward","move_back"]: Input.action_release(action)
	EventBus.player_noise_emitted.disconnect(noise_callback)
	report.classification = ("A_LOCAL_DEMONSTRATED" if departure == 0.0 else "B_LOCAL_WAIT_DEMONSTRATED") if report.arrived and report.vision_frames == 0 and not report.states.has("ALERT") and not report.states.has("CHASE") and not report.has("encounter_suspended") else ("C_LOCAL_HIGH_RISK" if report.arrived else "D_NO_SUCCESS_DEMONSTRATED")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
	print("P2CD_REPLAY="+JSON.stringify(report))
	get_tree().quit(0)

func _vector(value: String) -> Vector3:
	var pieces := value.trim_prefix("(").trim_suffix(")").split(",")
	return Vector3(float(pieces[0]),float(pieces[1]),float(pieces[2]))
