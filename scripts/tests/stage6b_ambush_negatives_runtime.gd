extends Node3D

## Negative Ambush runtime checks. Each case uses the real Player/Enemy,
## perception and EventBus; only the initial physical setup differs.
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const HORVEX := preload("res://resources/enemies/xenomorfo.tres")

var fortress: Node3D
var player: Node3D
var ready_count := 0
const FIXTURE_ORIGIN := Vector3(-40, 0, 0)

func _create_fixture() -> void:
	# Test-owned supported space, separate from Fortress6A/W05. The production
	# greybox stays unchanged; real bodies, navigation and perception still run.
	var floor := CSGBox3D.new()
	floor.size = Vector3(20, 0.2, 20)
	floor.position = FIXTURE_ORIGIN + Vector3(0, -0.1, 0)
	floor.use_collision = true
	add_child(floor)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-9,0,-9),Vector3(-9,0,9),Vector3(9,0,9),Vector3(9,0,-9)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	region.position = FIXTURE_ORIGIN
	add_child(region)

func _preflight(enemy: Enemy, require_vision: bool) -> bool:
	# Reuse the original preparation bound. No stimulus/state is fabricated.
	for _i in 180:
		await get_tree().physics_frame
		await get_tree().process_frame
		var map := get_world_3d().get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) == 0: continue
		var start := NavigationServer3D.map_get_closest_point(map, enemy.global_position)
		var end := NavigationServer3D.map_get_closest_point(map, player.global_position)
		var path := NavigationServer3D.map_get_path(map, start, end, true)
		var projected := Vector2(start.x-enemy.global_position.x,start.z-enemy.global_position.z).length() < 0.12 and Vector2(end.x-player.global_position.x,end.z-player.global_position.z).length() < 0.12
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule: CapsuleShape3D = player.get_node("CollisionShape3D").shape.duplicate()
		# Interior capsule excludes the legitimate resting-floor contact only.
		capsule.radius -= 0.01
		capsule.height -= 0.02
		query.shape = capsule
		query.transform = player.get_node("CollisionShape3D").global_transform
		query.collision_mask = player.collision_mask
		query.exclude = [player.get_rid()]
		var clear := get_world_3d().direct_space_state.intersect_shape(query).is_empty()
		var target: Vector3 = player.get_node("Head").global_position
		var delta := target-enemy.get_vision_origin()
		delta.y = 0
		var fov := rad_to_deg((-enemy.global_basis.z).angle_to(delta.normalized())) <= enemy.get_debug_fov_angle_deg()/2
		var los := enemy._has_clear_vision_line(enemy.get_vision_origin(),target,player)
		var in_range := delta.length() <= enemy.get_debug_fov_range_m()
		if player.is_on_floor() and enemy.is_on_floor() and clear and projected and path.size() >= 2 and (not require_vision or (fov and los and in_range)):
			print("6B NEGATIVE PREFLIGHT | case=%s floor=true capsule_clear=true path=%d FOV=%s LOS=%s range=%s" % [enemy.name,path.size(),fov,los,in_range])
			return true
	print("6B NEGATIVE FAIL_FIXTURE | case=%s player=%s enemy=%s player_floor=%s enemy_floor=%s" % [enemy.name,player.global_position,enemy.global_position,player.is_on_floor(),enemy.is_on_floor()])
	return false

func _ready() -> void:
	var main: Node3D = $MainFortress6A
	fortress = main.get_node("Fortress6A")
	player = main.get_node("Player")
	for name in ["InitialMelee", "StorageRogue", "BarracksMelee", "FinalRogue"]:
		var built_in: Enemy = fortress.get_node(name)
		built_in.perception_timer.stop()
		built_in.set_physics_process(false)
	EventBus.ambush_ready.connect(func(_enemy, _player): ready_count += 1)
	_create_fixture()
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
	player.global_position = FIXTURE_ORIGIN + Vector3(-6.0, 0.85, 5.0)
	player.velocity = Vector3.ZERO
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.name = name
	enemy.enemy_resource = HORVEX
	fortress.add_child(enemy)
	enemy.global_position = FIXTURE_ORIGIN + Vector3(0.0, 1.0, 0.0)
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
	if not await _preflight(enemy, false):
		await _dispose(enemy)
		return false
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
	# Outside both real capsules, still unambiguously in front (not rear zone).
	player.global_position = enemy.global_position + forward * 1.2
	player.look_at(player.global_position - forward, Vector3.UP)
	if not await _preflight(enemy, true):
		await _dispose(enemy)
		return false
	Input.action_press("stealth")
	for _i in 90: await get_tree().physics_frame
	var result := not enemy.get_debug_ambush_candidate_registered()
	print("6B AMBUSH NEGATIVE frontal | candidate=%s contact=%s state=%s" % [enemy.get_debug_ambush_candidate_registered(), enemy._current_contact_kind, enemy.get_debug_state_name()])
	await _dispose(enemy)
	return result


func _case_prior_contact() -> bool:
	var enemy := await _spawn("PriorContact")
	var forward := -enemy.global_transform.basis.z.normalized()
	# Allow full exposure before ALERT locomotion reaches the Player capsule.
	# At 1 m the old setup triggers legitimate stuck recovery before the fifth
	# visual tick, breaking FOV. Derive the run-up from the real Resource, not
	# a guessed coordinate or an increased timeout. No AI state is held/forced.
	var light := LightingManager.get_light_level_at(enemy.global_position)
	var capability: float = HORVEX.light_detection_curve[light]
	var exposure_time := HORVEX.detection_time_sec / maxf(capability, 0.01)
	var initial_distance := GameBalance.get_speed(HORVEX.chase_speed_tier) * (exposure_time + HORVEX.perception_interval_sec) + 1.0
	player.global_position = enemy.global_position + forward * initial_distance
	player.look_at(player.global_position + forward, Vector3.UP)
	if not await _preflight(enemy, true):
		await _dispose(enemy)
		return false
	var vision_confirmed := false
	for _i in 180:
		await get_tree().physics_frame
		if enemy._current_contact_kind == "VISION":
			vision_confirmed = true
			break
		if _i % 10 == 0:
			print("6B PRIOR_CONTACT_TRACE=" + JSON.stringify({"tick":_i,"player":player.global_position,"enemy":enemy.global_position,"forward":-enemy.global_basis.z,"floor":player.is_on_floor(),"enemy_floor":enemy.is_on_floor(),"state":enemy.get_debug_state_name(),"contact":enemy._current_contact_kind,"exposure":enemy._sight_timer,"perception":enemy.get_cover_perception_debug(),"suspended":ExplorationState.is_suspended()}))
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
		await get_tree().process_frame
		if enemy.get_debug_ambush_conditions(player).in_zone:
			entered_zone = true
			break
	Input.action_release("move_forward")
	var result := vision_confirmed and entered_zone and not enemy.get_debug_ambush_candidate_registered()
	print("6B AMBUSH NEGATIVE prior_contact | had_vision=%s entered_zone=%s candidate=%s contact=%s state=%s" % [vision_confirmed, entered_zone, enemy.get_debug_ambush_candidate_registered(), enemy._current_contact_kind, enemy.get_debug_state_name()])
	await _dispose(enemy)
	return result
