extends Node3D

## Diagnóstico runtime de un tercer/llegado tarde: no cambia gameplay.
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const HORVEX := preload("res://resources/enemies/xenomorfo.tres")

var player: Node3D
var fortress: Node3D


func _ready() -> void:
	var main: Node3D = $MainFortress6A
	fortress = main.get_node("Fortress6A")
	player = main.get_node("Player")
	_disable_fortress_enemies()
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if player.has_method("unfreeze_after_combat"):
		player.unfreeze_after_combat()
	player.global_position = Vector3(6.0, 0.85, -2.0)
	var a := await _spawn("LateLifecycleA", Vector3(5.3, 1.0, 0.0), true)
	var a_combat := await _wait_until(func(): return CombatManager.get_combatant_count() == 1 and a.get_debug_state_name() == "COMBAT", 10.0)
	_snapshot("A_COMBAT", null)
	var b := await _spawn("LateLifecycleB", Vector3(6.7, 1.0, 0.0), false)
	b.perception_timer.start()
	var rejected := await _wait_until(func(): return b.get_debug_encounter_state() == "REJECTED" and b._excluded_from_active_encounter, 4.0)
	_snapshot("B_REJECTED", b)
	# Victoria real del harness: se usa el lifecycle real de CombatManager,
	# retirando el único combatant y cerrando su encounter.
	if a_combat and CombatManager.get_combatant_count() == 1:
		CombatManager._combatants[0].apply_damage(9999)
		CombatManager._remove_dead_combatants()
		if CombatManager.get_combatant_count() == 0:
			CombatManager._win_combat()
	if RewardManager.get_step() != RewardManager.STEP_DONE:
		RewardManager._finish()
	await get_tree().physics_frame
	_snapshot("A_ENDED", b)
	var candidate_again := await _wait_until(func(): return b._has_requested_encounter and b.get_debug_encounter_state() == "CANDIDATE", 4.0)
	_snapshot("B_NEW_CANDIDATE", b)
	var b_combat := await _wait_until(func(): return CombatManager.get_combatant_count() == 1 and CombatManager.get_combatant_node(0) == b and b.get_debug_state_name() == "COMBAT", 8.0)
	_snapshot("B_NEW_COMBAT", b)
	var passed := a_combat and rejected and candidate_again and b_combat
	print("6G LATE ENEMY DIAGNOSTIC | a_combat=%s rejected=%s candidate_again=%s b_combat=%s" % [a_combat, rejected, candidate_again, b_combat])
	if passed:
		print("Stage6G late enemy lifecycle diagnostic: PASS")
	else:
		push_error("Stage6G late enemy lifecycle diagnostic: FAIL")
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if is_instance_valid(b): b.queue_free()
	if is_instance_valid(a): a.queue_free()
	get_tree().quit(0 if passed else 1)


func _disable_fortress_enemies() -> void:
	for name in ["InitialMelee", "StorageRogue", "BarracksMelee", "FinalRogue"]:
		var enemy: Enemy = fortress.get_node(name)
		enemy.perception_timer.stop()
		enemy.set_physics_process(false)


func _spawn(name: String, position: Vector3, enabled: bool) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.name = name
	enemy.enemy_resource = HORVEX
	fortress.add_child(enemy)
	enemy.global_position = position
	enemy.rotation.y = 0.0
	await get_tree().physics_frame
	if not enabled:
		enemy.perception_timer.stop()
	return enemy


func _wait_until(predicate: Callable, timeout_sec: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		await get_tree().physics_frame
		if predicate.call():
			return true
		elapsed += 1.0 / 60.0
	return false


func _snapshot(label: String, enemy: Enemy) -> void:
	if enemy == null:
		print("LATE %s | active=%s pending=%d combatants=%d" % [label, CombatEncounterManager.is_encounter_active(), CombatEncounterManager.get_debug_pending_count(), CombatManager.get_combatant_count()])
		return
	var belongs := false
	for index in CombatManager.get_combatant_count():
		belongs = belongs or CombatManager.get_combatant_node(index) == enemy
	print("LATE %s | state=%s encounter=%s owner=%s requested=%s closed=%s excluded=%s positioning=%s active=%s pending=%d combatants=%d belongs=%s" % [label, enemy.get_debug_state_name(), enemy.get_debug_encounter_state(), enemy.get_debug_ai_owner(), enemy._has_requested_encounter, enemy._encounter_join_closed, enemy._excluded_from_active_encounter, enemy.get_debug_has_combat_positioning(), CombatEncounterManager.is_encounter_active(), CombatEncounterManager.get_debug_pending_count(), CombatManager.get_combatant_count(), belongs])
