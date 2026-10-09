extends Node3D

## Real MainSandbox bodies, navigation, timers and ordinary encounter admission.
## Nominal PATROL during COMBAT is not active exploration time.
const PATROLLERS: Array[String] = ["OrcoMelee1", "OrcoMelee2", "OrcoPicaro1", "OrcoMelee3", "OrcoPicaro2"]
const OBSERVATION_SEC := 10.0 # Original Stage5H budget, per phase.
var failures: Array[String] = []
var starts := 0
var endings := 0
var rewards := 0

func _observe(sandbox: Node3D, names: Array[String], phase: String) -> Dictionary:
	var rows := {}
	for enemy_name in names:
		var actor: Enemy = sandbox.get_node(enemy_name)
		rows[enemy_name] = {"position":actor.global_position,"index":actor.get_patrol_runtime_debug().patrol_index,"distance":0.0,"active_sec":0.0,"suspended_sec":0.0,"index_changed":false,"max_stall":0.0}
	var elapsed := 0.0
	var frozen := {}
	while elapsed < OBSERVATION_SEC:
		var suspended := ExplorationState.is_suspended()
		if suspended:
			for enemy_name in names:
				var actor: Enemy = sandbox.get_node(enemy_name)
				if not frozen.has(enemy_name): frozen[enemy_name] = {"transform":actor.global_transform,"space":PhysicsServer3D.body_get_space(actor.get_rid())}
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		elapsed += delta
		for enemy_name in names:
			var actor: Enemy = sandbox.get_node(enemy_name)
			var row: Dictionary = rows[enemy_name]
			var runtime := actor.get_patrol_runtime_debug()
			if suspended:
				row.suspended_sec += delta
				var saved: Dictionary = frozen[enemy_name]
				if actor.global_transform != saved.transform:
					failures.append("%s moved during COMBAT" % enemy_name)
					return rows
				if not saved.space.is_valid() or PhysicsServer3D.body_get_space(actor.get_rid()) != saved.space:
					failures.append("%s lost physics space during COMBAT" % enemy_name)
					return rows
			elif actor.get_debug_state_name() == "PATROL":
				row.active_sec += delta
				row.distance += actor.global_position.distance_to(row.position)
				row.index_changed = row.index_changed or runtime.patrol_index != row.index
				row.max_stall = maxf(row.max_stall,runtime.stall_elapsed_sec)
			row.position = actor.global_position
			row.index = runtime.patrol_index
	for enemy_name in names:
		var row: Dictionary = rows[enemy_name]
		if row.active_sec >= 3.0 and row.distance < 0.5:
			failures.append("%s no active patrol movement (%s)" % [enemy_name,phase])
		if row.active_sec >= 9.0 and not row.index_changed:
			failures.append("%s no patrol_index change during active exploration (%s)" % [enemy_name,phase])
		if row.max_stall > 2.0:
			failures.append("%s PATROL STALLED (%s)" % [enemy_name,phase])
	print("V214_STAGE5H_%s=" % phase+JSON.stringify(rows))
	return rows

func _ready() -> void:
	CombatManager.combat_started.connect(func(): starts += 1)
	CombatManager.combat_ended.connect(func(): endings += 1)
	RewardManager.reward_sequence_started.connect(func(): rewards += 1)
	var sandbox: Node3D = $MainSandbox/DungeonSandbox
	var player: CharacterBody3D = $MainSandbox/Player
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var initial := await _observe(sandbox,PATROLLERS,"INITIAL")
	var suspended_seen := false
	var initial_progress := false
	for row: Dictionary in initial.values():
		suspended_seen = suspended_seen or row.suspended_sec > 0
		initial_progress = initial_progress or row.distance >= 0.5
	if not initial_progress: failures.append("no exploration progress before natural combat")
	if not suspended_seen or starts != 1 or not ExplorationState.is_suspended():
		failures.append("FIXTURE_CONFIGURATION: natural combat/suspension not observed")
	var survivors: Array[String] = []
	var participants: Array[Node3D] = []
	for index in CombatManager.get_combatant_count(): participants.append(CombatManager.get_combatant_node(index))
	for enemy_name in PATROLLERS:
		if sandbox.get_node(enemy_name) not in participants: survivors.append(enemy_name)
	if survivors.is_empty(): failures.append("FIXTURE_CONFIGURATION: no external patrollers")
	# Public lifecycle reset and fixture participant cleanup, not forced AI states.
	# Player rests inside the authored first room, away from surviving routes.
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	player.unfreeze_after_combat()
	player.global_position = Vector3(1,1,3)
	for actor in participants:
		if is_instance_valid(actor): actor.queue_free()
	await get_tree().physics_frame
	var recovery := await _observe(sandbox,survivors,"RECOVERY")
	for enemy_name in survivors:
		var row: Dictionary = recovery[enemy_name]
		if row.active_sec < 9.0 or row.distance < 0.5 or not row.index_changed:
			failures.append("%s did not recover real patrol progress" % enemy_name)
	if ExplorationState.is_suspended() or CombatManager.get_combatant_count() != 0 or CombatEncounterManager.get_debug_pending_count() != 0:
		failures.append("combat/encounter not clean after recovery")
	if starts != 1 or endings != 1 or rewards != 0: failures.append("duplicate combat/end/reward signals")
	print("V214_STAGE5H_RESULT="+JSON.stringify({"valid":failures.is_empty(),"errors":failures,"starts":starts,"endings":endings,"rewards":rewards,"survivors":survivors}))
	var output := FileAccess.open("user://patrol_runtime_report.txt",FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"initial":initial,"recovery":recovery,"errors":failures}))
		output.close()
	if failures.is_empty(): print("Stage5H DungeonSandbox runtime patrol: PASS")
	else:
		for failure in failures: push_error("Stage5H runtime patrol: "+failure)
	get_tree().quit(0 if failures.is_empty() else 1)
