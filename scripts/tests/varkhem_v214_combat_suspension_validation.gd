extends Node

var starts := 0
var endings := 0
var rewards := 0
var errors: Array[String] = []

func _wait_stage(stage: Node3D) -> bool:
	for frame in 1200:
		await get_tree().physics_frame
		if stage.nav_ready and stage.assembly_valid: return true
	return false

func _ready() -> void:
	CombatManager.combat_started.connect(func(): starts += 1)
	CombatManager.combat_ended.connect(func(): endings += 1)
	RewardManager.reward_sequence_started.connect(func(): rewards += 1)
	var stage := load("res://scenes/tests/VarkhemV213ExperienceTest.tscn").instantiate() as Node3D
	add_child(stage)
	if not await _wait_stage(stage):
		print("V214_SUSPENSION_RESULT=INCOMPLETE assembly")
		get_tree().quit(1)
		return
	var player: Node3D = stage.get_node("Player")
	var enemies := stage.get_node("RuntimeContent").get_children()
	player.set_physics_process(false)
	var participant: Enemy = enemies[0]
	var chaser: Enemy = enemies[1]
	chaser._on_player_seen(player.global_position,true)
	participant.mark_combat_started()
	player.freeze_for_combat()
	EventBus.combat_ready.emit(player,[participant])
	var snapshots := {}
	for enemy: Enemy in enemies:
		snapshots[enemy.get_instance_id()] = {"position":enemy.global_position,"basis":enemy.global_basis,"space":PhysicsServer3D.body_get_space(enemy.get_rid()),"layer":enemy.collision_layer,"mask":enemy.collision_mask,"state":enemy.get_debug_state_name(),"sight":enemy._sight_timer,"known":enemy.get_debug_last_known_position(),"timer":enemy.perception_timer.time_left}
	for frame in 120: await get_tree().physics_frame
	var moved := 0
	var timer_changed := 0
	for enemy: Enemy in enemies:
		var snapshot: Dictionary = snapshots[enemy.get_instance_id()]
		if enemy.global_position.distance_to(snapshot.position) > 0.001: moved += 1
		if absf(enemy.perception_timer.time_left-snapshot.timer) > 0.001: timer_changed += 1
		if not OS.get_cmdline_user_args().has("--control"):
			if not snapshot.space.is_valid() or PhysicsServer3D.body_get_space(enemy.get_rid()) != snapshot.space: errors.append("physics body unregistered")
			if enemy.global_basis != snapshot.basis or enemy.collision_layer != snapshot.layer or enemy.collision_mask != snapshot.mask: errors.append("orientation/collision changed")
			if enemy.velocity != Vector3.ZERO: errors.append("pending movement during suspension")
			if enemy.get_debug_state_name() != snapshot.state or enemy._sight_timer != snapshot.sight or enemy.get_debug_last_known_position() != snapshot.known: errors.append("exploration state updated during combat")
	var ui: CanvasLayer = stage.get_node("CombatUI")
	var card_ui_valid: bool = ui.visible and ui.is_processing() and not RunState.hand.is_empty()
	var row := {"moved":moved,"timer_changed":timer_changed,"card_ui":card_ui_valid,"starts":starts,"chaser_state":chaser.get_debug_state_name(),"player_frozen":player.is_frozen}
	print("V214_SUSPENSION_COMBAT=%s" % JSON.stringify(row))
	if OS.get_cmdline_user_args().has("--control"):
		print("V214_CONTROL_REPRODUCED=%s" % (moved > 0))
		await stage.regenerate(stage.seed)
		get_tree().quit(0 if moved > 0 else 1)
		return
	if moved > 0 or timer_changed > 0 or not card_ui_valid or not player.is_frozen or starts != 1: errors.append("combat exploration isolation")
	# Signal callbacks must also be gated; process_mode alone does not stop them.
	var known_before := chaser.get_debug_last_known_position()
	EventBus.player_noise_emitted.emit(chaser.global_position,100,1)
	chaser._on_perception_tick()
	if chaser.get_debug_last_known_position() != known_before: errors.append("sensory signal bypassed suspension")
	if CombatEncounterManager.request_encounter_candidate(chaser) != CombatEncounterManager.REJECTED_CLOSED or starts != 1: errors.append("additional encounter during combat")
	# Existing real card API, not a synthetic victory signal.
	var lethal := CardResource.new()
	lethal.damage_amount = 999
	lethal.stamina_cost = 0
	RunState.hand.append(lethal)
	CombatManager.play_card(lethal)
	if ui.visible or endings != 1 or rewards != 1: errors.append("victory/UI/reward signals")
	var reward_position := chaser.global_position
	for frame in 30: await get_tree().physics_frame
	if not ExplorationState.is_suspended() or chaser.global_position != reward_position: errors.append("reward suspension")
	for step in 20:
		match RewardManager.get_step():
			RewardManager.STEP_SUMMARY: RewardManager.acknowledge_summary()
			RewardManager.STEP_DNA_CHOICE: RewardManager.choose_dna_slot("weapon")
			RewardManager.STEP_DNA_RESULT, RewardManager.STEP_KIT_RESULT: RewardManager.acknowledge_message()
			RewardManager.STEP_CARD_UNLOCKED: RewardManager.leave_unlocked_card_out()
			RewardManager.STEP_KIT_OFFER: RewardManager.decline_first_aid_kit()
			RewardManager.STEP_DONE: break
	player.global_position = Vector3(-500,1,-500)
	var before_resume: Vector3 = chaser.global_position
	for frame in 120: await get_tree().physics_frame
	if player.is_frozen or chaser.global_position.distance_to(before_resume) < 0.01: errors.append("exploration did not resume")
	await stage.regenerate(stage.seed)
	await _wait_stage(stage)
	# Defeat retains suspension until the existing reset contract.
	var next: Enemy = stage.get_node("RuntimeContent").get_child(0)
	next.mark_combat_started()
	player.freeze_for_combat()
	EventBus.combat_ready.emit(player,[next])
	RunState.apply_damage_to_player(99999)
	CombatManager.end_turn()
	var bystander: Enemy = stage.get_node("RuntimeContent").get_child(1)
	var defeat_position := bystander.global_position
	for frame in 30: await get_tree().physics_frame
	if bystander.global_position != defeat_position or not ui.defeat_overlay.visible: errors.append("defeat isolation")
	await stage.regenerate(stage.seed)
	await _wait_stage(stage)
	if player.is_frozen or ui.visible or CombatManager.get_combatant_count() != 0: errors.append("defeat reset")
	var resumed: Enemy = stage.get_node("RuntimeContent").get_child(1)
	var resumed_position := resumed.global_position
	player.global_position = Vector3(-500,1,-500)
	for frame in 120: await get_tree().physics_frame
	if resumed.global_position.distance_to(resumed_position) < 0.01: errors.append("reset did not resume patrol")
	print("V214_SUSPENSION_RESULT=%s" % JSON.stringify({"valid":errors.is_empty(),"errors":errors,"starts":starts,"endings":endings,"rewards":rewards}))
	await stage.regenerate(stage.seed)
	get_tree().quit(0 if errors.is_empty() else 1)
