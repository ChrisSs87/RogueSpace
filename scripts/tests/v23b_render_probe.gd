extends Node3D

## Desktop diagnostic only. Frozen actors isolate rendering, not a gameplay gate.
func _ready() -> void:
	var baseline := OS.get_cmdline_user_args().has("--visual-baseline")
	var selected: StringName = &"OPERATIVA"
	var semantic := &"BARRACKS"
	var seed := 65001
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): selected = StringName(arg.trim_prefix("--variant="))
		if arg.begins_with("--seed="): seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--semantic="): semantic = StringName(arg.trim_prefix("--semantic="))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var profile: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
	if baseline: profile.visual_style = null
	var stage := preload("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate()
	stage.lighting_variant_id = selected
	stage.initial_seed = seed
	add_child(stage)
	var deadline := Time.get_ticks_msec()+15000
	while not stage.nav_ready and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not stage.nav_ready:
		print("V23B_RENDER_RESULT="+JSON.stringify({"valid":false,"reason":"navigation fixture not ready"}))
		get_tree().quit(1)
		return
	for actor in get_tree().root.find_children("*","CharacterBody3D",true,false):
		actor.set_physics_process(false)
		if actor is Enemy: actor.perception_timer.stop()
		for debug_label in actor.find_children("*","Label3D",true,false): debug_label.visible = false
	for label in ["SemanticLocationDebug","ContentSlotDebug","SectorTransitionDebug"]:
		var root := stage.get_node_or_null(NodePath(label))
		if root != null: root.visible = false
	for layer in stage.find_children("*","CanvasLayer",true,false): layer.visible = false
	var location: DungeonSemanticLocation
	for candidate in stage.current_plan.semantic_locations:
		if candidate.definition.semantic_id == semantic: location = candidate; break
	var module: Node3D
	if location != null:
		module = stage.get_node("AssembledModules").get_node(NodePath(String(location.node_id)))
	elif semantic == &"CORRIDOR":
		for id in stage.current_plan.module_ids:
			if stage.current_plan.module_types[id] == &"CORRIDOR":
				module = stage.get_node("AssembledModules").get_node(NodePath(String(id)))
				break
	if module == null:
		print("V23B_RENDER_RESULT="+JSON.stringify({"valid":false,"reason":"no barracks fixture"}))
		get_tree().quit(1)
		return
	var player: Node3D = stage.get_node("Player")
	var center := module.global_position
	var camera_footprint: Vector2 = module.get_meta("footprint_size")
	player.global_position = center+module.global_basis*Vector3(0,0.86,minf(3.0,camera_footprint.y*0.5-0.65))
	var camera := player.get_node("Head/Camera3D") as Camera3D
	camera.look_at(center+Vector3(0,1,0))
	if semantic == &"CORRIDOR":
		player.global_position = center+module.global_basis*Vector3(-camera_footprint.x*0.5+0.65,0.86,0)
		camera.look_at(center+module.global_basis*Vector3(minf(3.0,camera_footprint.x*0.5-0.65),1,0))
	var top := OS.get_cmdline_user_args().has("--top-view")
	if top:
		var minimum := Vector3(INF,0,INF)
		var maximum := Vector3(-INF,0,-INF)
		for part: Node3D in stage.get_node("AssembledModules").get_children():
			var footprint: Vector2 = part.get_meta("footprint_size")
			for x in [-0.5,0.5]:
				for z in [-0.5,0.5]:
					var corner := part.to_global(Vector3(footprint.x*x,0,footprint.y*z))
					minimum.x = minf(minimum.x,corner.x); minimum.z = minf(minimum.z,corner.z)
					maximum.x = maxf(maximum.x,corner.x); maximum.z = maxf(maximum.z,corner.z)
		var overview := Camera3D.new()
		overview.projection = Camera3D.PROJECTION_ORTHOGONAL
		overview.size = maxf(maximum.x-minimum.x,maximum.z-minimum.z)*1.1
		add_child(overview)
		var midpoint := (minimum+maximum)*0.5
		overview.position = midpoint+Vector3.UP*200
		overview.look_at(midpoint,Vector3.FORWARD)
		overview.make_current()
	for _index in 30: await RenderingServer.frame_post_draw
	var timings: Array[float] = []
	var previous := Time.get_ticks_usec()
	for _index in 120:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		timings.append(float(now-previous)/1000.0)
		previous = now
	var sum := 0.0
	for value in timings: sum += value
	timings.sort()
	var image := get_viewport().get_texture().get_image()
	var filename := output
	var saved := image.save_png(filename)
	print("V23B_RENDER_RESULT="+JSON.stringify({"valid":saved == OK,"mode":String(selected),"baseline":baseline,"seed":seed,"semantic":semantic,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),
		"adapter":RenderingServer.get_video_adapter_name(),"mean_frame_ms":sum/timings.size(),"p90_frame_ms":timings[108],
		"maximum_frame_ms":timings.back(),"lights":stage.get_node("AssembledModules").find_children("FixtureLight","SpotLight3D",true,false).size(),
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"screenshot":filename,
		"limitations":"desktop, stationary camera, vsync/driver dependent; not Android or gameplay certification"}))
	get_tree().quit(0 if saved == OK else 1)
