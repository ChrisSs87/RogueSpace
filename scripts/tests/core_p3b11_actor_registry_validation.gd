extends Node3D

class RegistryActor extends CharacterBody3D:
	var resumed := 0
	var active_timer: Timer
	var prepaused_timer: Timer
	func _ready() -> void:
		active_timer = Timer.new()
		active_timer.wait_time = 100
		add_child(active_timer)
		active_timer.start()
		prepaused_timer = Timer.new()
		prepaused_timer.wait_time = 100
		add_child(prepaused_timer)
		prepaused_timer.start()
		prepaused_timer.paused = true
	func on_exploration_resumed(_msec: int) -> void:
		resumed += 1

var stage: Node3D
var baseline := false
var output := ""
var errors: Array[String] = []
var checks: Array[String] = []
var report := {}

func _ready() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	stage = load("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate()
	add_child(stage)
	for tick in 900:
		if stage.nav_ready: break
		await get_tree().physics_frame
	await _settled()
	# Debug remains OFF; no per-generation snapshots retained by this harness.
	for warmup in 6:
		await stage.regenerate(65003)
		await _settled()
	var stream := FileAccess.open(output+".jsonl",FileAccess.WRITE)
	var first := _counts()
	var last := first
	var signatures := {}
	var min_memory: float = first.memory_static
	var max_memory: float = first.memory_static
	for iteration in 100:
		await stage.regenerate(65003)
		await _settled()
		last = _counts()
		last.iteration = iteration
		var signature := var_to_str([stage.current_plan.get_topology_signature(),stage.get_assembly_signature(),stage.current_runtime_content_report,stage.current_room_environment_report,stage.nav_mesh.vertices,stage.nav_mesh.get_polygon_count()])
		if signatures.has("65003/0"): _check(signatures["65003/0"] == signature,"determinism")
		else: signatures["65003/0"] = signature
		for key in ["nodes","enemies","agents","covers","lights","noise_connections","debug_layers"]:
			_check(last[key] == first[key],"stable "+key)
		if not baseline:
			_check(last.invalid == 0,"no obsolete registry entry")
			_check(last.total == last.valid,"registry total equals live")
		min_memory = minf(min_memory,last.memory_static)
		max_memory = maxf(max_memory,last.memory_static)
		stream.store_line(JSON.stringify(last))
	stream.close()
	report.memory = {"first":first,"last":last,"samples":100,"min_memory":min_memory,"max_memory":max_memory,"signature":signatures["65003/0"]}
	if baseline:
		_check(last.invalid-first.invalid == 800,"baseline +800 retired weak records")
		_check(last.objects-first.objects == 800,"baseline +800 Objects")
	else:
		# Actual Stage reset clears positioning via the existing public contract.
		ExplorationState.set_encounter_positioning(true)
		await stage.regenerate(65002)
		await _settled()
		_check(not ExplorationState.is_suspended(),"regeneration keeps existing reset semantics")
		_check(_counts().invalid == 0,"suspended regeneration cleanup")
	stage.queue_free()
	for tick in 4: await get_tree().physics_frame
	report.scene_destroyed = _counts()
	if not baseline:
		_check(report.scene_destroyed.invalid == 0,"scene destruction cleans stale entries")
		await _contracts()
	else: _check(report.scene_destroyed.invalid > 0,"baseline stale entries survive scene destruction")
	report.baseline = baseline
	report.errors = errors
	report.checks = checks
	report.valid = errors.is_empty()
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	print("P3B11_RESULT="+JSON.stringify({"valid":errors.is_empty(),"errors":errors,"baseline":baseline,"checks":checks,"samples":100}))
	get_tree().quit(0 if errors.is_empty() else 1)

func _settled() -> void:
	var player: CharacterBody3D = stage.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-500,1,-500)
	for tick in 20: await get_tree().physics_frame
	_check(stage.nav_ready and stage.assembly_valid,"real physical generation")
	_check(not stage.get_node("Inspection").infiltration and not DebugConfig.perception_debug_enabled,"debug remains disabled")

func _counts() -> Dictionary:
	var registry: Dictionary = ExplorationState.get("_actors")
	var row := {"total":registry.size(),"valid":0,"invalid":0,"nodes":0,"enemies":0,"agents":0,"covers":0,"debug_layers":0,"lights":LightingManager.get("_sources").size(),"noise_connections":EventBus.get_signal_connection_list("player_noise_emitted").size(),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC)}
	for entry in registry.values():
		if entry.ref.get_ref() == null: row.invalid += 1
		else: row.valid += 1
	var pending: Array[Node] = [get_tree().root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		row.nodes += 1
		if node is Enemy: row.enemies += 1
		if node is NavigationAgent3D: row.agents += 1
		if node is LogicalCover: row.covers += 1
		if node is CanvasLayer and node.has_node("Stage6GDebug"): row.debug_layers += 1
		pending.append_array(node.get_children())
	return row

func _actor() -> RegistryActor:
	var actor := RegistryActor.new()
	add_child(actor)
	ExplorationState.register_actor(actor)
	return actor

func _check(condition: bool,message: String) -> void:
	if not condition: errors.append(message)

func _contracts() -> void:
	# Unit owner-signal controls; real combat/reward flows run separately.
	var actor := _actor()
	var id := actor.get_instance_id()
	CombatManager.combat_started.emit()
	_check(ExplorationState.is_suspended() and actor.active_timer.paused,"combat pauses live actor")
	var since: int = ExplorationState.get("_actors")[id].since
	for repeat in 5: ExplorationState.register_actor(actor)
	_check(ExplorationState.get("_actors")[id].since == since,"duplicate register preserves pause provenance")
	_check(actor.tree_exited.get_connections().size() == 1,"one lifecycle callback")
	RewardManager.reward_sequence_started.emit()
	CombatManager.combat_ended.emit()
	_check(ExplorationState.is_suspended() and actor.active_timer.paused and actor.resumed == 0,"reward owner survives combat ending")
	var fresh := _actor()
	_check(fresh.active_timer.paused,"new actor inherits active suspension")
	var freed_id := fresh.get_instance_id()
	fresh.queue_free()
	for tick in 3: await get_tree().physics_frame
	_check(not ExplorationState.get("_actors").has(freed_id),"destroy suspended actor removes only its record")
	_check(ExplorationState.is_suspended() and actor.active_timer.paused,"cleanup does not release foreign owner")
	# A valid actor outside the tree is not a dead actor; preserve its entry.
	remove_child(actor)
	for tick in 2: await get_tree().physics_frame
	_check(ExplorationState.get("_actors").has(id),"valid out-of-tree actor retained")
	add_child(actor)
	RewardManager.reward_sequence_finished.emit()
	_check(not ExplorationState.is_suspended() and not actor.active_timer.paused,"resume active timer")
	_check(actor.prepaused_timer.paused and actor.resumed == 1,"preexisting pause preserved, one resume callback")
	# Different ordering of simultaneous owners, including positioning.
	ExplorationState.set_encounter_positioning(true)
	CombatManager.combat_started.emit()
	RewardManager.reward_sequence_started.emit()
	RewardManager.reward_sequence_finished.emit()
	_check(ExplorationState.is_suspended() and actor.active_timer.paused,"combat/positioning survive reward finish")
	CombatManager.combat_ended.emit()
	_check(ExplorationState.is_suspended() and actor.active_timer.paused,"positioning survives combat finish")
	ExplorationState.set_encounter_positioning(false)
	_check(actor.resumed == 2 and not actor.active_timer.paused,"one final resume after all owners")
	# Explicit dead-only cleanup is idempotent and cannot unregister live actors.
	ExplorationState._remove_invalid_actor(id)
	_check(ExplorationState.get("_actors").has(id),"cleanup preserves valid actor")
	actor.queue_free()
	for tick in 3: await get_tree().physics_frame
	ExplorationState._remove_invalid_actor(id)
	ExplorationState._remove_invalid_actor(id)
	_check(not ExplorationState.get("_actors").has(id),"repeated dead deregistration")
	# Reset uses its existing all-owner semantics, not a new kind of reset.
	var reset_actor := _actor()
	CombatManager.combat_started.emit()
	ExplorationState.reset_for_regeneration()
	_check(not ExplorationState.is_suspended() and not reset_actor.active_timer.paused and reset_actor.resumed == 1,"existing reset resumes exactly once")
	reset_actor.queue_free()
	for tick in 3: await get_tree().physics_frame
	_check(_counts().invalid == 0 and _counts().valid == 1,"only persistent encounter manager remains")
	checks.append("A-J: no-suspension regeneration, suspended reset, removal/new actor, combat/reward owner ordering, duplicate register, detach/reenter, idempotent dead cleanup, 100 real regenerations")
