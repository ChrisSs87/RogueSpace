extends Node3D

## Runtime lifecycle regression: real Enemy perception drives all candidates.
## Timers are started deliberately only when a late enemy is meant to acquire
## the Player; no Enemy state/contact/candidate is assigned by this test.
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const HORVEX := preload("res://resources/enemies/xenomorfo.tres")

var player: Node3D
var fortress: Node3D

func _ready() -> void:
	var main: Node3D = $MainFortress6A
	fortress = main.get_node("Fortress6A")
	player = main.get_node("Player")
	_disable_fortress_enemies()
	for _i in 60:
		await get_tree().physics_frame
	var recovery_ok := await _run_rejected_recovery()
	var third_ok := await _run_third_enemy()
	print("6B MULTI RUNTIME | rejected_recovery=%s third_enemy=%s" % [recovery_ok, third_ok])
	if recovery_ok and third_ok:
		print("Stage6B multi runtime: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6B multi runtime: FAIL")
		get_tree().quit(1)


func _disable_fortress_enemies() -> void:
	for name in ["InitialMelee", "StorageRogue", "BarracksMelee", "FinalRogue"]:
		var enemy: Enemy = fortress.get_node(name)
		enemy.perception_timer.stop()
		enemy.set_physics_process(false)


func _spawn_enemy(name: String, position: Vector3, perception_enabled: bool) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.name = name
	enemy.enemy_resource = HORVEX
	fortress.add_child(enemy)
	enemy.global_position = position
	enemy.rotation.y = 0.0 # Forward -Z toward the Player in this fixture.
	await get_tree().physics_frame
	if not perception_enabled:
		enemy.perception_timer.stop()
	return enemy


func _prepare_attempt() -> void:
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if player.has_method("unfreeze_after_combat"):
		player.unfreeze_after_combat()
	player.global_position = Vector3(6.0, 0.85, -2.0)
	player.velocity = Vector3.ZERO


func _wait_until(predicate: Callable, timeout_sec: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		await get_tree().physics_frame
		if predicate.call():
			return true
		elapsed += 1.0 / 60.0
	return false


func _cleanup(enemies: Array[Enemy]) -> void:
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if player.has_method("unfreeze_after_combat"):
		player.unfreeze_after_combat()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	for _i in 3:
		await get_tree().physics_frame


func _run_rejected_recovery() -> bool:
	await _prepare_attempt()
	var a := await _spawn_enemy("RecoveryA", Vector3(5.3, 1.0, 0.0), true)
	var b := await _spawn_enemy("RecoveryB", Vector3(6.7, 1.0, 0.0), true)
	var rejected := await _spawn_enemy("RecoveryRejected", Vector3(6.0, 1.0, 2.0), false)
	var combat_started := await _wait_until(func(): return CombatManager.get_combatant_count() == 2, 8.0)
	rejected.perception_timer.start()
	var rejected_while_active := await _wait_until(func(): return rejected._encounter_debug_state == "REJECTED" and rejected._excluded_from_active_encounter, 3.0)
	var did_not_invade := CombatManager.get_combatant_count() == 2 and rejected.get_debug_ai_owner() == "EXPLORATION"
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if player.has_method("unfreeze_after_combat"):
		player.unfreeze_after_combat()
	var accepted_after_reset := await _wait_until(func(): return rejected._has_requested_encounter and rejected._encounter_debug_state == "CANDIDATE", 3.0)
	print("6B REJECTED RECOVERY | combat=%s rejected=%s no_invade=%s accepted_after_reset=%s state=%s excluded=%s" % [combat_started, rejected_while_active, did_not_invade, accepted_after_reset, rejected._encounter_debug_state, rejected._excluded_from_active_encounter])
	await _cleanup([a, b, rejected])
	return combat_started and rejected_while_active and did_not_invade and accepted_after_reset


func _run_third_enemy() -> bool:
	await _prepare_attempt()
	var a := await _spawn_enemy("ThirdA", Vector3(5.3, 1.0, 0.0), true)
	var b := await _spawn_enemy("ThirdB", Vector3(6.7, 1.0, 0.0), true)
	var c := await _spawn_enemy("ThirdC", Vector3(6.0, 1.0, 2.0), false)
	var pair_combat := await _wait_until(func(): return CombatManager.get_combatant_count() == 2, 8.0)
	c.perception_timer.start()
	var third_rejected := await _wait_until(func(): return c._encounter_debug_state == "REJECTED" and c._excluded_from_active_encounter, 3.0)
	var max_two := CombatManager.get_combatant_count() == 2
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if player.has_method("unfreeze_after_combat"):
		player.unfreeze_after_combat()
	var reusable := await _wait_until(func(): return c._has_requested_encounter and c._encounter_debug_state == "CANDIDATE", 3.0)
	print("6B THIRD ENEMY | pair=%s rejected=%s max_two=%s reusable=%s state=%s excluded=%s" % [pair_combat, third_rejected, max_two, reusable, c._encounter_debug_state, c._excluded_from_active_encounter])
	await _cleanup([a, b, c])
	return pair_combat and third_rejected and max_two and reusable
