extends Node

const STAGE_SCENE := preload("res://scenes/tests/Stage6JArchetypePrototype.tscn")
var endings := 0
var rewards := 0
var defeats := 0


func _ready() -> void:
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	CombatManager.combat_ended.connect(func(): endings += 1)
	CombatManager.player_defeated.connect(func(): defeats += 1)
	RewardManager.reward_sequence_started.connect(func(): rewards += 1)

	var stage := STAGE_SCENE.instantiate() as Node3D
	stage.initial_seed = 65001
	stage.test_archetype_index = 1 # VARKHEM_BASE
	add_child(stage)

	var assembled := await _wait_until(func(): return stage.nav_ready and stage.assembly_valid, 720)
	var combat_ui := stage.get_node_or_null("CombatUI") as CanvasLayer
	var reward_ui := stage.get_node_or_null("RewardUI") as CanvasLayer
	var player := stage.get_node_or_null("Player") as Node3D
	var runtime_root := stage.get_node_or_null("RuntimeContent") as Node3D
	var enemy: Enemy = null
	if runtime_root != null:
		for child in runtime_root.get_children():
			if child is Enemy:
				enemy = child as Enemy
				break

	var composition_valid := combat_ui != null and reward_ui != null
	var runtime_enemy_valid := enemy != null and enemy.enemy_resource != null
	var old_waypoints: Array = []
	if runtime_enemy_valid:
		for child in enemy.get_children():
			if child is Marker3D: old_waypoints.append(child)
	var combat_started := false
	if player != null and runtime_enemy_valid:
		# La percepción/encounter tienen su propio gate. Acá se prueba el
		# límite que faltaba: Enemy procedural ya generado -> señal pública de
		# combate -> CombatManager + UI presentes en la escena manual Stage6J.
		EventBus.combat_ready.emit(player, [enemy])
		await get_tree().process_frame
		combat_started = CombatManager.get_combatant_count() == 1 and player.is_frozen and combat_ui.visible

	await stage.regenerate_from_debug()
	await get_tree().process_frame
	await get_tree().physics_frame
	var reset_valid: bool = not CombatEncounterManager.is_encounter_active() \
		and CombatManager.get_combatant_count() == 0 \
		and player != null and not player.is_frozen \
		and not is_instance_valid(enemy) and not combat_ui.visible \
		and endings == 1 and rewards == 0
	for waypoint in old_waypoints:
		reset_valid = reset_valid and not is_instance_valid(waypoint)
	var lifecycle_valid := await _remaining_lifecycle(stage, player, combat_ui, reward_ui)

	print("Stage6J playable combat/reset assembled=%s composition=%s runtime_enemy=%s combat=%s reset=%s" % [assembled, composition_valid, runtime_enemy_valid, combat_started, reset_valid])
	stage.queue_free()
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if assembled and composition_valid and runtime_enemy_valid and combat_started and reset_valid and lifecycle_valid:
		print("Stage6J playable combat/reset validation: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6J playable combat/reset validation: FAIL")
		get_tree().quit(1)


func _remaining_lifecycle(stage: Node3D, player: Node3D, ui: CanvasLayer, reward_ui: CanvasLayer) -> bool:
	await _wait_until(func(): return stage.nav_ready and stage.assembly_valid, 720)
	player.set_physics_process(false)
	player.global_position = Vector3(-500, 1, -500)
	# Real defeat through public damage/end-turn contracts, then in-place reset.
	RunState.reset_run()
	player.freeze_for_combat()
	EventBus.combat_ready.emit(player, [stage.get_node("RuntimeContent").get_child(0)])
	RunState.apply_damage_to_player(9999)
	CombatManager.end_turn()
	var defeat_valid: bool = defeats == 1 and ui.visible and ui.defeat_overlay.visible and player.is_frozen
	await stage.regenerate(stage.seed)
	await _wait_until(func(): return stage.nav_ready and stage.assembly_valid, 720)
	var defeat_reset: bool = not ui.visible and not player.is_frozen and CombatManager.get_combatant_count() == 0 and endings == 2 and rewards == 0
	CombatManager.reset_after_defeat()
	var idempotent: bool = endings == 2
	# Actual card resolution -> victory -> reward completion -> exploration.
	RunState.reset_run()
	player.global_position = Vector3(-500, 1, -500)
	player.freeze_for_combat()
	EventBus.combat_ready.emit(player, [stage.get_node("RuntimeContent").get_child(0)])
	var lethal := CardResource.new()
	lethal.damage_amount = 999
	lethal.stamina_cost = 0
	RunState.hand.append(lethal)
	CombatManager.play_card(lethal)
	var victory_valid: bool = endings == 3 and rewards == 1 and not ui.visible and player.is_frozen and reward_ui.visible
	for step in 12:
		match RewardManager.get_step():
			RewardManager.STEP_SUMMARY: RewardManager.acknowledge_summary()
			RewardManager.STEP_DNA_CHOICE: RewardManager.choose_dna_slot("weapon")
			RewardManager.STEP_DNA_RESULT, RewardManager.STEP_KIT_RESULT: RewardManager.acknowledge_message()
			RewardManager.STEP_CARD_UNLOCKED: RewardManager.leave_unlocked_card_out()
			RewardManager.STEP_KIT_OFFER: RewardManager.decline_first_aid_kit()
			RewardManager.STEP_DONE: break
	await get_tree().process_frame
	var resumed: bool = not player.is_frozen and not reward_ui.visible and RewardManager.get_step() == RewardManager.STEP_DONE
	CombatManager.reset_after_defeat()
	var no_duplicate: bool = endings == 3 and rewards == 1
	await stage.regenerate(stage.seed)
	await _wait_until(func(): return stage.nav_ready and stage.assembly_valid, 720)
	player.global_position = Vector3(-500, 1, -500)
	player.freeze_for_combat()
	EventBus.combat_ready.emit(player, [stage.get_node("RuntimeContent").get_child(0)])
	var new_combat: bool = ui.visible and not ui.defeat_overlay.visible and CombatManager.get_combatant_count() == 1
	await stage.regenerate(stage.seed)
	await _wait_until(func(): return stage.nav_ready and stage.assembly_valid, 720)
	var final_reset: bool = not ui.visible and not player.is_frozen and endings == 4 and rewards == 1
	print("Stage6J lifecycle defeat=%s defeat_reset=%s idempotent=%s victory=%s resume=%s no_duplicate=%s new_combat=%s final_reset=%s endings=%d rewards=%d" % [defeat_valid, defeat_reset, idempotent, victory_valid, resumed, no_duplicate, new_combat, final_reset, endings, rewards])
	return defeat_valid and defeat_reset and idempotent and victory_valid and resumed and no_duplicate and new_combat and final_reset


func _wait_until(predicate: Callable, max_physics_frames: int) -> bool:
	for _frame in max_physics_frames:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())
