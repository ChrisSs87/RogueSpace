extends "res://scripts/tests/a3_p2cd_reference.gd"

## Audit only. No AI state injection, synthetic noise, perception timer calls,
## disabled colliders or production changes. All phases use normal Player input.
func _ready() -> void:
	if OS.get_cmdline_user_args().has("--replay"):
		await super._ready()
		return
	var seed := 65002
	var sector := 0
	var kind := "HUB"
	var pocket_index := 0
	var category := 1
	var crouch := true
	var hold_only := OS.get_cmdline_user_args().has("--hold-only")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--sector="): sector = int(arg.trim_prefix("--sector="))
		if arg.begins_with("--kind="): kind = arg.trim_prefix("--kind=")
		if arg.begins_with("--pocket="): pocket_index = int(arg.trim_prefix("--pocket="))
		if arg.begins_with("--category="): category = int(arg.trim_prefix("--category="))
		if arg == "--stand": crouch = false
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var stage: Node3D = load("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate()
	stage.initial_seed = seed
	add_child(stage)
	await _await_sector(stage)
	var player: CharacterBody3D = stage.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-500,1,-500)
	for n in sector:
		await stage.advance_sector_from_debug()
		await _await_sector(stage)
		player.global_position = Vector3(-500,1,-500)
	var report := {"seed":seed,"sector_index":sector,"kind":kind,"pocket":pocket_index,"category":category,"posture":"STEALTH" if crouch else "WALK","result":"INCOMPLETE","phase":"FIXTURE","distance_m":0.0,"noise":[],"samples":[],"first_suspicion":{},"first_confirmation":{},"visual_exposure_sec":0.0,"phases":[],"wait_sec":0.0,"blocked_cover_frames":0,"wait_frames":0,"instant_out_clear_frames":0,"scope":"LOCAL_ENTRY_REFUGE_WAIT_EXIT_NOT_GLOBAL_STEALTH"}
	if not stage.assembly_valid or not stage.nav_ready:
		report.reason = "FAIL_FIXTURE assembly/navigation"
		_finish(report)
		return
	report.sector_id = stage.sector_run.sector_definitions[sector].sector_id
	var modules: Node3D = stage.get_node("AssembledModules")
	var module: Node3D = null
	var node_id: StringName
	for location in stage.current_plan.semantic_locations:
		if location.definition.semantic_id == (&"CENTRAL_HUB" if kind == "HUB" else &"BARRACKS"):
			node_id = location.node_id
			module = modules.get_node(NodePath(String(node_id)))
			break
	if module == null:
		report.reason = "NO_COMPATIBLE_SEMANTIC_MODULE"
		_finish(report)
		return
	report.node = node_id
	var cover: LogicalCover = null
	for child in module.get_children():
		if child is LogicalCover and child.category == category: cover = child
	if cover == null:
		report.reason = "NO_EXISTING_COVER_OF_CATEGORY"
		_finish(report)
		return
	var parent: Node3D
	for id in stage.current_plan.links:
		if stage.current_plan.links[id].has(node_id): parent = modules.get_node(NodePath(String(id)))
	var entry := _seam(module,parent)
	var exit := module.global_position
	if kind == "HUB":
		for child in stage.current_plan.links[node_id]:
			if stage.current_plan.main_path_nodes.has(child): exit = _seam(module,modules.get_node(NodePath(String(child))))
	var pockets := BUILDER.room_access_positions(module,cover,stage.nav_region.get_navigation_map(),player.get_node("CollisionShape3D").shape)
	if pocket_index >= pockets.size() or not pockets[pocket_index].accessible:
		report.reason = "FAIL_FIXTURE pocket not statically accessible"
		report.pockets = pockets
		_finish(report)
		return
	var refuge: Vector3 = pockets[pocket_index].world
	var map: RID = stage.nav_region.get_navigation_map()
	var inbound := NavigationServer3D.map_get_path(map,entry,refuge,true)
	var outbound := NavigationServer3D.map_get_path(map,refuge,exit,true)
	report.cover = String(cover.name)
	report.entry = entry
	report.refuge = refuge
	report.exit = exit
	report.inbound_m = _meters(inbound)
	report.outbound_m = _meters(outbound)
	# Parent implementation checks physical Player capsule, static sweeps and
	# projection. Returned modes are irrelevant; no perception is simulated.
	var in_check := _route(stage,player,"in",entry,refuge)
	var out_check := _route(stage,player,"out",refuge,exit)
	if not in_check.valid or not out_check.valid:
		report.reason = "FAIL_FIXTURE " + in_check.reason + out_check.reason
		_finish(report)
		return
	var guards := stage.get_node("RuntimeContent").get_children()
	var cycle := 0.0
	for guard: Enemy in guards:
		var points: Array = guard.get_meta("patrol_world_points",[])
		var length := 0.0
		for i in range(points.size()-1): length += _meters(NavigationServer3D.map_get_path(map,points[i],points[i+1],true))
		cycle = maxf(cycle,2.0*length/GameBalance.get_speed(guard.enemy_resource.patrol_speed_tier)+2.0*maxi(points.size()-1,1)*(guard.patrol_pause_sec+180.0/maxf(guard.patrol_turn_speed_deg,1.0)))
	report.required_wait_sec = cycle
	var hz := Engine.physics_ticks_per_second
	var now := 0.0
	report.elapsed_sec = 0.0
	var noise_callback := func(position,radius,intensity): report.noise.append({"sec":report.elapsed_sec,"position":position,"radius":radius,"intensity":intensity,"phase":report.phase})
	EventBus.player_noise_emitted.connect(noise_callback)
	if crouch: Input.action_press("stealth")
	player.global_position = entry+Vector3.UP*0.86
	player.set_physics_process(true)
	var path := inbound
	var next := 1
	var wait_start := 0.0
	var outgoing_start := 0.0
	var speed: float = GameBalance.get_speed(player.walk_speed_tier)*(player.stealth_speed_multiplier if crouch else 1.0)
	report.nominal_speed = speed
	var deadline: float = (_meters(inbound)+_meters(outbound))/speed+cycle*2.0+path.size()*0.16/speed+2.0
	report.phase = "ENTRY_TO_REFUGE"
	if hold_only:
		player.global_position = refuge+Vector3.UP*0.86
		report.phase = "WAIT_IN_REFUGE"
		report.scope = "REFUGE_HOLD_EXIT_CONTROL_NO_ENTRY_DEMONSTRATED"
	report.phases.append({"phase":report.phase,"sec":0.0})
	var last := player.global_position
	for frame in ceili(deadline*hz):
		now = float(frame)/hz
		report.elapsed_sec = now
		_stop_input()
		if report.phase in ["ENTRY_TO_REFUGE","REFUGE_TO_EXIT"]:
			if next < path.size():
				var delta := path[next]-player.global_position
				delta.y = 0
				if delta.length() < 0.16: next += 1
				else: _drive(player,delta)
			else:
				if report.phase == "REFUGE_TO_EXIT":
					report.result = "PASS" if report.first_suspicion.is_empty() and report.first_confirmation.is_empty() else "FAIL"
					report.reason = "ALL_STAGES_UNDETECTED" if report.result == "PASS" else "COMPLETED_BUT_PERCEIVED"
					report.crossing_out_sec = now-outgoing_start
					break
				report.phase = "WAIT_IN_REFUGE"
				report.phases.append({"phase":report.phase,"sec":now})
				wait_start = now
		if report.phase == "WAIT_IN_REFUGE":
			report.wait_sec = now-wait_start
			var clear := _outgoing_clear(guards,player,outbound)
			if clear: report.instant_out_clear_frames += 1
			if report.wait_sec >= cycle and clear:
				report.phase = "REFUGE_TO_EXIT"
				report.phases.append({"phase":report.phase,"sec":now})
				outgoing_start = now
				path = outbound
				next = 1
		await get_tree().physics_frame
		var displacement := player.global_position-last
		displacement.y = 0
		report.distance_m += displacement.length()
		last = player.global_position
		var poses: Array = []
		var exposed := false
		var cover_block := false
		for guard: Enemy in guards:
			var visual := guard._passes_vision_baseline(player)
			var confirmed := guard.has_confirmed_visual_contact(player)
			exposed = exposed or visual
			cover_block = cover_block or cover.blocks_sight(guard.get_vision_origin(),player.get_node("Head").global_position,player.is_crouched())
			var state := guard.get_debug_state_name()
			var source := guard.get_debug_last_known_source()
			var detail := {"sec":now,"phase":report.phase,"slot":guard.get_meta("content_slot_id"),"state":state,"source":source,"stimulus":guard.get_debug_stimulus_source(),"visual":visual,"confirmed":confirmed,"position":guard.global_position,"forward":-guard.global_basis.z,"last_known":guard.get_debug_last_known_position()}
			if state in ["ALERT","CHASE","APPROACH","COMBAT"] and report.first_suspicion.is_empty(): report.first_suspicion = detail.duplicate()
			if confirmed and report.first_confirmation.is_empty(): report.first_confirmation = detail.duplicate()
			if frame % 12 == 0: poses.append(detail)
		if exposed: report.visual_exposure_sec += 1.0/hz
		if report.phase == "WAIT_IN_REFUGE":
			report.wait_frames += 1
			if cover_block: report.blocked_cover_frames += 1
		if frame % 12 == 0: report.samples.append({"sec":now,"phase":report.phase,"player":player.global_position,"posture":player.get_movement_state_label(),"guards":poses})
		if not report.first_confirmation.is_empty() or ExplorationState.is_suspended():
			report.result = "FAIL"
			report.reason = "CONTACT_CONFIRMED" if not report.first_confirmation.is_empty() else "ENCOUNTER_SUSPENDED"
			break
	report.elapsed_sec = now
	if not report.has("reason"): report.reason = "NO_COMPLETE_SEQUENCE_WITHIN_OBSERVATION_DEADLINE"
	_stop_input()
	Input.action_release("stealth")
	EventBus.player_noise_emitted.disconnect(noise_callback)
	_finish(report)

func _stop_input() -> void:
	for action in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)

func _drive(player: CharacterBody3D,delta: Vector3) -> void:
	var local := player.global_basis.inverse()*delta.normalized()
	if absf(local.x) > 0.001: Input.action_press("move_right" if local.x > 0 else "move_left",absf(local.x))
	if absf(local.z) > 0.001: Input.action_press("move_back" if local.z > 0 else "move_forward",absf(local.z))

func _outgoing_clear(guards: Array,player: CharacterBody3D,path: PackedVector3Array) -> bool:
	# Instantaneous cue ONLY, never a PASS criterion or future-path prediction.
	# Pure LOS/FOV queries from real guard transforms. Restores Player transform
	# before physics resumes; no sensing tick runs at the queried locations.
	var original := player.global_position
	var clear := true
	for point in path:
		player.global_position = point+Vector3.UP*0.86
		for guard: Enemy in guards:
			if guard._passes_vision_baseline(player): clear = false
	player.global_position = original
	return clear

func _finish(report: Dictionary) -> void:
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
	print("P2CE_RESULT="+JSON.stringify(report))
	get_tree().quit(0) # Audit outcome separate from process outcome; FAIL kept.
