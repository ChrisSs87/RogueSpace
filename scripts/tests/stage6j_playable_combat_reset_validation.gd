extends Node

const STAGE_SCENE := preload("res://scenes/tests/Stage6JArchetypePrototype.tscn")


func _ready() -> void:
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()

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
		and not is_instance_valid(enemy)

	print("Stage6J playable combat/reset assembled=%s composition=%s runtime_enemy=%s combat=%s reset=%s" % [assembled, composition_valid, runtime_enemy_valid, combat_started, reset_valid])
	stage.queue_free()
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if assembled and composition_valid and runtime_enemy_valid and combat_started and reset_valid:
		print("Stage6J playable combat/reset validation: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6J playable combat/reset validation: FAIL")
		get_tree().quit(1)


func _wait_until(predicate: Callable, max_physics_frames: int) -> bool:
	for _frame in max_physics_frames:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())
