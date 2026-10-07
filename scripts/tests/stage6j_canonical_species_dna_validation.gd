extends Node

## Integration regression for the real procedural Varkhen reward path.
## It deliberately uses Stage6J runtime enemies, never an invented DNA
## species: EnemyResource.species_id -> CombatManager -> RewardManager ->
## DNAManager -> the canonical DNASpeciesResource progression.

const STAGE_SCENE := preload("res://scenes/tests/Stage6JArchetypePrototype.tscn")
const CARD_DEF := preload("res://resources/cards/CardResource.gd")
const VARKHEN_ID := "varkhen"


func _ready() -> void:
	DNAManager.reset()
	RunState.reset_run()
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()

	var stage := STAGE_SCENE.instantiate() as Node3D
	stage.initial_seed = 65001
	stage.test_archetype_index = 1 # VARKHEM_BASE
	add_child(stage)

	var assembled := await _wait_until(func(): return stage.nav_ready and stage.assembly_valid, 720)
	var player := stage.get_node_or_null("Player") as Node3D
	var runtime_root := stage.get_node_or_null("RuntimeContent") as Node3D
	var enemies := _varkhen_enemies(runtime_root)
	var resource := _canonical_species_resource()
	var results: Array[bool] = []
	if assembled and player != null and enemies.size() >= 3 and resource != null:
		for index in range(3):
			results.append(await _defeat_and_apply_weapon_dna(player, enemies[index], index < 2))

	var dna_amount := DNAManager.get_dna_amount("weapon", VARKHEN_ID)
	var level := DNAManager.get_dna_level("weapon", VARKHEN_ID)
	var bonus := DNAManager.get_weapon_damage_bonus()
	if RewardManager.get_step() == RewardManager.STEP_DNA_RESULT:
		RewardManager.acknowledge_message()
	var card_unlock := RewardManager.get_step() == RewardManager.STEP_CARD_UNLOCKED
	if card_unlock:
		RewardManager.leave_unlocked_card_out()
	await get_tree().process_frame
	var exploration_resumed: bool = player != null and not player.is_frozen and RewardManager.get_step() == RewardManager.STEP_DONE
	var passed: bool = assembled and resource != null and enemies.size() >= 3 \
		and results.size() == 3 and not results.has(false) \
		and dna_amount == 3 and level == 3 and bonus == resource.weapon_damage_per_level * 3 \
		and card_unlock and exploration_resumed

	print("Stage6J canonical species/DNA assembled=%s enemies=%d resource=%s rewards=%s dna=%d level=%d bonus=%d unlock=%s resume=%s" % [
		assembled, enemies.size(), resource.species_id if resource != null else "", results, dna_amount, level, bonus, card_unlock, exploration_resumed,
	])
	stage.queue_free()
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	DNAManager.reset()
	RunState.reset_run()
	if passed:
		print("Stage6J canonical species/DNA validation: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6J canonical species/DNA validation: FAIL")
		get_tree().quit(1)


func _defeat_and_apply_weapon_dna(player: Node3D, enemy: Enemy, finish_reward: bool) -> bool:
	if enemy == null or not is_instance_valid(enemy) or enemy.enemy_resource == null or enemy.enemy_resource.species_id != VARKHEN_ID:
		return false
	# CombatEncounterManager normally freezes the player immediately before
	# emitting combat_ready. This direct public-signal harness keeps that
	# lifecycle contract while testing the real CombatManager reward path.
	player.freeze_for_combat()
	EventBus.combat_ready.emit(player, [enemy])
	await get_tree().process_frame
	if CombatManager.get_combatant_count() != 1:
		return false

	var lethal := CARD_DEF.new() as CardResource
	lethal.card_name = "Canonical DNA validation strike"
	lethal.damage_amount = 999
	lethal.stamina_cost = 0
	RunState.hand.clear()
	RunState.hand.append(lethal)
	CombatManager.play_card(lethal)
	await get_tree().process_frame
	if RewardManager.get_step() != RewardManager.STEP_SUMMARY:
		return false
	RewardManager.acknowledge_summary()
	if RewardManager.get_step() != RewardManager.STEP_DNA_CHOICE or RewardManager.get_current_species() != VARKHEN_ID:
		return false
	RewardManager.choose_dna_slot("weapon")
	if RewardManager.get_step() != RewardManager.STEP_DNA_RESULT:
		return false
	if finish_reward:
		RewardManager.acknowledge_message()
		await get_tree().process_frame
		return RewardManager.get_step() == RewardManager.STEP_DONE and not player.is_frozen
	return true


func _varkhen_enemies(runtime_root: Node3D) -> Array[Enemy]:
	var result: Array[Enemy] = []
	if runtime_root == null:
		return result
	for child in runtime_root.get_children():
		if child is Enemy:
			var enemy := child as Enemy
			if enemy.enemy_resource != null and enemy.enemy_resource.species_id == VARKHEN_ID:
				result.append(enemy)
	return result


func _canonical_species_resource() -> DNASpeciesResource:
	for resource in DNAManager.species_resources:
		if resource != null and resource.species_id == VARKHEN_ID:
			return resource
	return null


func _wait_until(predicate: Callable, max_physics_frames: int) -> bool:
	for _frame in max_physics_frames:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
	return bool(predicate.call())
