extends Node3D

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const HORVEX := preload("res://resources/enemies/xenomorfo.tres")

var stealth_ticks := 0
var stealth_broken := false
var zone_entries := 0
var entry_valid := false
var ready_count := 0
var ready_valid := false
var encounter_valid := false
var approach_started := false
var pending_survived_join_window := false
var approach_seen := false

func trace(label: String, enemy: Enemy, player: Node3D) -> void:
	print("AMBUSH_TRACE frame=%d %s pos=%s stealth_ticks=%d conditions=%s candidate=%s combatants=%d" % [Engine.get_physics_frames(), label, player.global_position, stealth_ticks, enemy.get_debug_ambush_conditions(player), enemy.get_debug_ambush_candidate_registered(), CombatManager.get_combatant_count()])

func _ready() -> void:
	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player = main.get_node("Player")
	var original: Enemy = fortress.get_node("InitialMelee")
	original.perception_timer.stop(); original.set_physics_process(false)
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_resource = HORVEX
	fortress.add_child(enemy)
	enemy.global_position = Vector3(6.0, 1.0, 0.0)
	enemy.rotation.y = 0.0
	for other_name in ["StorageRogue", "BarracksMelee", "FinalRogue"]:
		var other: Enemy = fortress.get_node(other_name)
		other.perception_timer.stop()
		other.set_physics_process(false)
	for _i in 60: await get_tree().physics_frame
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	enemy.player_entered_ambush_zone.connect(func(p):
		zone_entries += 1
		var c := enemy.get_debug_ambush_conditions(p)
		entry_valid = approach_started and stealth_ticks >= 12 and not stealth_broken and c.stealth and c.contact == "NONE" and c.valid
		trace("ZONE_ENTRY_BEFORE_AMBUSH", enemy, p))
	EventBus.ambush_ready.connect(func(e, p):
		ready_count += 1
		ready_valid = e == enemy and p == player and enemy.get_debug_ambush_candidate_registered() and enemy.get_debug_ambush_conditions(player).contact == "NONE"
		trace("AMBUSH_READY", enemy, player))
	EventBus.combat_ready.connect(func(p, enemies):
		encounter_valid = p == player and enemies.size() == 1 and enemies[0] == enemy
		trace("COMBAT_READY", enemy, player))
	EventBus.player_noise_emitted.connect(func(_pos, _radius, _intensity): trace("NOISE", enemy, player))
	var previous_pending := -1
	var previous_locked := false
	# Horvex is a real can_patrol=false profile: stationary/IDLE by normal
	# configuration, while perception and physics remain fully active.
	var forward := -enemy.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	player.global_position = enemy.global_position - forward * 3.0
	player.velocity = Vector3.ZERO
	player.look_at(player.global_position + forward, Vector3.UP)
	Input.action_press("stealth")
	# physics_frame fires before node processing; process_frame observes completed physics.
	for _i in 12:
		await get_tree().physics_frame
		await get_tree().process_frame
		if player.get_movement_state_label() == "STEALTH": stealth_ticks += 1
		else: stealth_broken = true
		trace("STEALTH_PRECHECK", enemy, player)
	if stealth_ticks != 12 or stealth_broken or enemy.get_debug_ambush_conditions(player).in_zone or enemy.get_debug_state_name() != "IDLE" or enemy._current_contact_kind != "NONE":
		print("Stage6B ambush E2E: TEST SETUP INVALID")
		finish(false)
		return
	approach_started = true
	Input.action_press("move_forward")
	var combat_seen := false
	for tick in 480:
		await get_tree().physics_frame
		await get_tree().process_frame
		if player.get_movement_state_label() == "STEALTH": stealth_ticks += 1
		else: stealth_broken = true
		var pending := CombatEncounterManager.get_debug_pending_count()
		var locked := CombatEncounterManager.is_encounter_active()
		if zone_entries > 0 and pending == 1 and CombatEncounterManager.get_debug_join_window_remaining() < CombatEncounterManager.join_window_sec:
			pending_survived_join_window = true
		if enemy.get_debug_state_name() == "APPROACH":
			approach_seen = true
		if pending != previous_pending or locked != previous_locked or tick % 15 == 0:
			print("AMBUSH_LIFECYCLE tick=%d pending=%d window=%.3f locked=%s ambush_list=%d state=%s requested=%s owner=%s positioning=%s" % [tick, pending, CombatEncounterManager.get_debug_join_window_remaining(), locked, CombatEncounterManager._ambush_candidates.size(), enemy.get_debug_state_name(), enemy._has_requested_encounter, enemy.get_debug_ai_owner(), enemy.get_debug_has_combat_positioning()])
		previous_pending = pending; previous_locked = locked
		if tick < 90 or tick % 30 == 0: trace("APPROACH_%d" % tick, enemy, player)
		if zone_entries > 0: Input.action_release("move_forward")
		combat_seen = CombatManager.get_combatant_count() > 0
		if combat_seen: break
	Input.action_release("move_forward")
	var first := RunState.stamina
	var correct_enemy := CombatManager.get_combatant_count() == 1 and CombatManager.get_combatant_node(0) == enemy
	var second := -1
	if combat_seen:
		CombatManager.end_turn()
		second = RunState.stamina
	# Observe additional real ticks to catch duplicate emissions.
	for _i in 30:
		await get_tree().physics_frame
		await get_tree().process_frame
	var passed := not stealth_broken and entry_valid and ready_valid and pending_survived_join_window and approach_seen and encounter_valid and correct_enemy and enemy.get_debug_ambush_candidate_registered() and first == RunState.max_stamina + 2 and second == RunState.max_stamina and ready_count == 1
	print("6B AMBUSH E2E | sustained=%s ticks=%d zone_entries=%d entry_valid=%s registered=%s pending_survived=%s approach=%s encounter_enemy=%s correct_combatant=%s combatants=%d first=%d second=%d ready_count=%d" % [not stealth_broken, stealth_ticks, zone_entries, entry_valid, enemy.get_debug_ambush_candidate_registered(), pending_survived_join_window, approach_seen, encounter_valid, correct_enemy, CombatManager.get_combatant_count(), first, second, ready_count])
	finish(passed)

func finish(passed: bool) -> void:
	Input.action_release("move_forward")
	Input.action_release("stealth")
	if passed: print("Stage6B ambush E2E: PASS")
	else: push_error("Stage6B ambush E2E: FAIL")
	get_tree().quit(0 if passed else 1)
