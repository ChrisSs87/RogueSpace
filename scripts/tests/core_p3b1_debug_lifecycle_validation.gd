extends Node3D

var stage: Node3D
var report := {"errors":[],"snapshots":[],"signatures":{},"checks":[],"baseline":false}
var output := ""
var baseline := false

func _ready() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	report.baseline = baseline
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	await _open_scene()
	_capture("initial",0)
	# First establish a warm equivalent sector. No forced encounters.
	await _regenerate(65003)
	_capture("equivalent_initial",0)
	if OS.get_cmdline_user_args().has("--stream-memory"):
		await _memory_plateau()
		_save()
		return
	var repeats := 8 if baseline else 50
	for debug_on in [false,true]:
		if stage.get_node("Inspection").infiltration != debug_on:
			stage.get_node("Inspection")._toggle_infiltration()
		for iteration in repeats:
			await _regenerate(65003)
			_capture("same_on" if debug_on else "same_off",iteration)
	for pass_index in (1 if baseline else 2):
		for seed in [65001,65002,65003,65004,65005,65006]:
			await _regenerate(seed)
			_capture("seed_change",pass_index)
			while stage.current_sector_index < stage.sector_run.sector_count()-1:
				await stage.advance_sector_from_debug()
				await _settled()
				_capture("sector_change",pass_index)
	if not baseline:
		await _history_contract()
		_ui_contract()
		await _settled()
		_capture("ui_reused",0)
	# Scene ownership: destroy normally and let queued frees finish.
	stage.queue_free()
	for tick in 20: await get_tree().physics_frame
	report.after_scene_free = _global_counts()
	_check(report.after_scene_free.enemies == 0,"enemy references after scene free")
	_check(report.after_scene_free.agents == 0,"agents after scene free")
	_check(report.after_scene_free.debug_layers == 0,"debug UI after scene free")
	_check(report.after_scene_free.logical_lights == 0,"logical sources after scene free")
	await _open_scene()
	_capture("scene_restart",0)
	if baseline:
		var equivalent: Array = report.snapshots.filter(func(row): return row.mode == "same_off")
		_check(equivalent[-1].debug_layers-equivalent[0].debug_layers == 2*(repeats-1),"baseline debug layers reproduce +2/regeneration")
		_check(equivalent[-1].nodes-equivalent[0].nodes == 4*(repeats-1),"baseline live nodes reproduce +4/regeneration")
	else:
		for mode in ["same_off","same_on"]:
			var equivalent: Array = report.snapshots.filter(func(row): return row.mode == mode)
			for key in ["nodes","enemies","agents","covers","logical_lights","visual_lights","noise_connections"]:
				var values: Array = equivalent.map(func(row): return row[key])
				_check(values.min() == values.max(),"stable "+mode+"/"+key)
	_save()

func _open_scene() -> void:
	stage = load("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate()
	add_child(stage)
	for tick in 900:
		if stage.nav_ready: break
		await get_tree().physics_frame
	await _settled()

func _regenerate(seed: int) -> void:
	await stage.regenerate(seed)
	await _settled()

func _settled() -> void:
	var player: CharacterBody3D = stage.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-500,1,-500)
	# Existing observer refresh is 0.2 s; sample after one complete refresh.
	for tick in 20: await get_tree().physics_frame
	_check(stage.assembly_valid and stage.nav_ready,"generation/navigation readiness")

func _global_counts() -> Dictionary:
	var counts := {"nodes":0,"enemies":0,"agents":0,"covers":0,"visual_lights":0,"debug_layers":0,"logical_lights":LightingManager.get("_sources").size(),"noise_connections":EventBus.get_signal_connection_list("player_noise_emitted").size(),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}
	var pending: Array[Node] = [get_tree().root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		counts.nodes += 1
		if node is Enemy: counts.enemies += 1
		if node is NavigationAgent3D: counts.agents += 1
		if node is LogicalCover: counts.covers += 1
		if node is Light3D: counts.visual_lights += 1
		if node is CanvasLayer and node.has_node("Stage6GDebug"): counts.debug_layers += 1
		pending.append_array(node.get_children())
	return counts

func _capture(mode: String,iteration: int) -> void:
	var row := _global_counts()
	row.mode = mode
	row.iteration = iteration
	row.seed = stage.seed
	row.sector = stage.current_sector_index
	var inspection := stage.get_node("Inspection")
	row.history_active = inspection.observed_states.size()
	row.history_retired = 0 if baseline else inspection.retired_state_history.size()
	row.history_dropped = 0 if baseline else inspection.retired_state_history_dropped
	row.debug_enabled = inspection.infiltration
	var signature := var_to_str([stage.current_plan.get_topology_signature(),stage.get_assembly_signature(),stage.current_content_plan.get_signature(),stage.current_runtime_content_report,stage.current_room_environment_report,stage.nav_mesh.vertices,stage.nav_mesh.get_polygon_count()])
	var key := "%d/%d" % [stage.seed,stage.current_sector_index]
	if report.signatures.has(key): _check(report.signatures[key] == signature,"determinism "+key)
	else: report.signatures[key] = signature
	if not baseline:
		_check(row.debug_layers == 1,"one owned diagnostic layer")
		_check(row.history_active <= row.enemies,"history only contains live enemies")
		_check(row.history_retired <= maxi(inspection.retired_state_history_limit,0),"bounded retired history")
	report.snapshots.append(row)

func _history_contract() -> void:
	var inspection := stage.get_node("Inspection")
	inspection.retired_state_history_limit = 2
	await _regenerate(65003)
	_check(inspection.retired_state_history.size() == 2,"configured recent history limit")
	_check(inspection.retired_state_history_dropped > 0,"truncation is explicit")
	for value in inspection.retired_state_history:
		_check(value.has("seed") and value.has("sector") and value.has("enemy_id") and value.has("transition"),"retired audit context")
	inspection.retired_state_history_limit = 0
	await _regenerate(65003)
	_check(inspection.retired_state_history.is_empty(),"zero disables retired storage")
	_check(inspection.observed_states.size() == stage.current_runtime_content_report.spawned.size(),"active history retained with zero retired budget")
	inspection.retired_state_history_limit = 32
	report.checks.append("history limits 32/2/0; active data preserved; discarded count available")

func _memory_plateau() -> void:
	var inspection := stage.get_node("Inspection")
	inspection._toggle_infiltration()
	# Fill the configured recent archive before the constant-storage window.
	for iteration in 6: await _regenerate(65003)
	var stream := FileAccess.open(output+".jsonl",FileAccess.WRITE)
	var first := _global_counts()
	var maximum_memory: float = first.memory_static
	var minimum_memory: float = first.memory_static
	var last := first
	for iteration in 32:
		await _regenerate(65003)
		last = _global_counts()
		last.iteration = iteration
		last.history = inspection.get_debug_history_metrics()
		maximum_memory = maxf(maximum_memory,last.memory_static)
		minimum_memory = minf(minimum_memory,last.memory_static)
		for key in ["nodes","enemies","agents","covers","logical_lights","noise_connections"]:
			_check(first[key] == last[key],"constant-storage stability "+key)
		_check(last.history.active == 8 and last.history.retired == 32,"constant-storage history plateau")
		# Stream instead of retaining snapshots in the harness: bounded own memory.
		stream.store_line(JSON.stringify(last))
	stream.close()
	report.memory_plateau = {"samples":32,"first":first,"last":last,"minimum_memory":minimum_memory,"maximum_memory":maximum_memory,"scope":"constant-size harness storage; warmed history and same seed; no memory-zero assertion"}

func _ui_contract() -> void:
	var inspection := stage.get_node("Inspection")
	var original_layer: CanvasLayer = stage.get_node("Stage6GDebugLayer")
	var original_label: Label = original_layer.get_node("Stage6GDebug")
	for iteration in 10: stage._update_debug()
	_check(original_label == stage.get_node("Stage6GDebugLayer/Stage6GDebug"),"reuse original label")
	var profile_layer := stage.get_node("SectorProfilesDebugLayer")
	var button: Button = profile_layer.get_child(0)
	_check(button.pressed.get_connections().size() == 1,"one PROFILES handler")
	for iteration in 4: button.pressed.emit()
	_check(not stage.sector_profiles_debug,"PROFILES open/close")
	# Recovery of owned UI children, without deleting any foreign node.
	var sentinel := Node.new()
	sentinel.name = "ForeignDiagnosticSentinel"
	stage.add_child(sentinel)
	original_label.free()
	stage._update_debug()
	_check(original_layer == stage.get_node("Stage6GDebugLayer"),"reuse layer after owned label removed")
	_check(is_instance_valid(sentinel),"foreign node untouched")
	sentinel.free()
	inspection.top_view()
	inspection.zoom(0.8)
	inspection.fit()
	inspection.toggle_map()
	inspection.toggle_map()
	inspection.player_view()
	_check(not inspection.top_active,"view controls recover player camera")
	report.checks.append("reuse/child recreation; PROFILES handlers; TOP/PLAYER/MAP/ZOOM/FIT")

func _check(condition: bool,message: String) -> void:
	if not condition: report.errors.append(message)

func _save() -> void:
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
	print("P3B1_RESULT="+JSON.stringify({"valid":report.errors.is_empty(),"errors":report.errors,"snapshots":report.snapshots.size(),"baseline":baseline,"checks":report.checks}))
	get_tree().quit(0 if report.errors.is_empty() else 1)
