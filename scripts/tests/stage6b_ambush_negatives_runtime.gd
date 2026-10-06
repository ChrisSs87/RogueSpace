extends Node3D

## Negative Ambush runtime checks. Each case uses the real Player/Enemy,
## perception and EventBus; only the initial physical setup differs.
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const HORVEX := preload("res://resources/enemies/xenomorfo.tres")

var fortress: Node3D
var player: Node3D
var ready_count := 0

func _ready() -> void:
	var main: Node3D = $MainFortress6A
	fortress = main.get_node("Fortress6A")
	player = main.get_node("Player")
	for name in ["InitialMelee", "StorageRogue", "BarracksMelee", "FinalRogue"]:
		var built_in: Enemy = fortress.get_node(name)
		built_in.perception_timer.stop()
		built_in.set_physics_process(false)
	EventBus.ambush_ready.connect(func(_enemy, _player): ready_count += 1)
	for _i in 60: await get_tree().physics_frame
	var no_stealth := await _case_no_stealth()
	var frontal := await _case_frontal_stealth()
	var prior_contact := await _case_prior_contact()
	print("6B AMBUSH NEGATIVES | no_stealth=%s frontal=%s prior_contact=%s ready_count=%d" % [no_stealth, frontal, prior_contact, ready_count])
	if no_stealth and frontal and prior_contact and ready_count == 0:
		print("Stage6B ambush negatives: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6B ambush negatives: FAIL")
		get_tree().quit(1)


func _spawn(name: String) -> Enemy:
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if player.has_method("unfreeze_after_combat"): player.unfreeze_after_combat()
	# Keep the real Player clear of the future rear zone while the new Enemy
	# enters the tree; each negative case places it only after this frame.
	Input.action_release("move_forward")
	Input.action_release("stealth")
	player.global_position = Vector3(0.0, 0.85, 0.0)
	player.velocity = Vector3.ZERO
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.name = name
	enemy.enemy_resource = HORVEX
	fortress.add_child(enemy)
	enemy.global_position = Vector3(6.0, 1.0, 0.0)
	enemy.rotation.y = 0.0
	await get_tree().physics_frame
	return enemy


func _dispose(enemy: Enemy) -> void:
	Input.action_release("move_forward")
	Input.action_release("stealth")
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if player.has_method("unfreeze_after_combat"): player.unfreeze_after_combat()
	enemy.queue_free()
	for _i in 3: await get_tree().physics_frame


func _case_no_stealth() -> bool:
	var enemy := await _spawn("NoStealth")
	var forward := -enemy.global_transform.basis.z.normalized()
	player.global_position = enemy.global_position - forward * 1.45
	player.look_at(player.global_position + forward, Vector3.UP)
	Input.action_press("move_forward")
	for _i in 18: await get_tree().physics_frame
	Input.action_release("move_forward")
	var result := not enemy.get_debug_ambush_candidate_registered()
	print("6B AMBUSH NEGATIVE no_stealth | candidate=%s contact=%s" % [enemy.get_debug_ambush_candidate_registered(), enemy._current_contact_kind])
	await _dispose(enemy)
	return result


func _case_frontal_stealth() -> bool:
	var enemy := await _spawn("FrontalStealth")
	var forward := -enemy.global_transform.basis.z.normalized()
	player.global_position = enemy.global_position + forward * 0.45
	player.look_at(player.global_position - forward, Vector3.UP)
	Input.action_press("stealth")
	for _i in 90: await get_tree().physics_frame
	var result := not enemy.get_debug_ambush_candidate_registered()
	print("6B AMBUSH NEGATIVE frontal | candidate=%s contact=%s state=%s" % [enemy.get_debug_ambush_candidate_registered(), enemy._current_contact_kind, enemy.get_debug_state_name()])
	await _dispose(enemy)
	return result


func _case_prior_contact() -> bool:
	var enemy := await _spawn("PriorContact")
	# This is the open InitialMelee room/lane used by the existing Fortress
	# runtime vision tests. It gives the real stationary Horvex clear FOV/LOS.
	enemy.global_position = Vector3(12.0, 1.0, -0.7)
	await get_tree().physics_frame
	var forward := -enemy.global_transform.basis.z.normalized()
	# Deliberately acquire real VISION from the front.
	player.global_position = enemy.global_position + forward * 1.0
	player.look_at(player.global_position + forward, Vector3.UP)
	var vision_confirmed := false
	for _i in 180:
		await get_tree().physics_frame
		if enemy._current_contact_kind == "VISION":
			vision_confirmed = true
			break
	if not vision_confirmed:
		print("6B AMBUSH NEGATIVE prior_contact: TEST SETUP INVALID (no real VISION)")
		await _dispose(enemy)
		return false
	# The Enemy is now legitimately CHASE. Move to just outside its rear zone,
	# then enter it physically in STEALTH; no contact kind is falsified.
	player.global_position = enemy.global_position - forward * 1.55
	player.look_at(player.global_position + forward, Vector3.UP)
	Input.action_press("stealth")
	Input.action_press("move_forward")
	var entered_zone := false
	for _i in 30:
		await get_tree().physics_frame
		if enemy.get_debug_ambush_conditions(player).in_zone:
			entered_zone = true
			break
	Input.action_release("move_forward")
	var result := vision_confirmed and entered_zone and not enemy.get_debug_ambush_candidate_registered()
	print("6B AMBUSH NEGATIVE prior_contact | had_vision=%s entered_zone=%s candidate=%s contact=%s state=%s" % [vision_confirmed, entered_zone, enemy.get_debug_ambush_candidate_registered(), enemy._current_contact_kind, enemy.get_debug_state_name()])
	await _dispose(enemy)
	return result
