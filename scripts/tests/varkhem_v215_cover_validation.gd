extends Node3D

const PLAYER := preload("res://scenes/player/Player.tscn")
const ENEMY := preload("res://scenes/enemies/Enemy.tscn")
const GUARD := preload("res://resources/enemies/orco_melee.tres")
@export var automatic := false
var player: CharacterBody3D
var guard: Enemy
var covers: Array[LogicalCover] = []
var errors: Array[String] = []
@export var chase_mode := false
var diagnostic_mode := 1
var compact: Label

func _box(at: Vector3, size: Vector3, parent: Node3D) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	parent.add_child(visual)

func _check(ok: bool, message: String) -> void:
	print("V215_CHECK %s %s" % [ok,message])
	if not ok: errors.append(message)

func _wait(seconds: float) -> void:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline: await get_tree().physics_frame

func _ready() -> void:
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	_box(Vector3(0,-0.1,0),Vector3(30,0.2,30),floor_body)
	for index in 3:
		var cover := LogicalCover.new()
		cover.category = index
		cover.position = Vector3((index-1)*5,0,-4)
		add_child(cover)
		# Deliberately MEDIUM taller than HIGH: category, not mesh height.
		_box(Vector3(0,0.65+index*0.2,0),Vector3(2,1.3+index*0.4,1),cover)
		covers.append(cover)
	var region := NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	var vertices := PackedVector3Array()
	for z in range(-14,15):
		for x in range(-14,15): vertices.append(Vector3(x,0,z))
	nav.vertices = vertices
	for z in 28:
		for x in 28:
			var center := Vector2(x-13.5,z-13.5)
			var blocked := false
			for cover in covers:
				if absf(center.x-cover.position.x) < 1.6 and absf(center.y-cover.position.z) < 1.1: blocked = true
			if not blocked:
				var a := z*29+x
				nav.add_polygon(PackedInt32Array([a,a+29,a+30,a+1]))
	region.navigation_mesh = nav
	add_child(region)
	player = PLAYER.instantiate()
	player.position = Vector3(-5,0.86,-8)
	add_child(player)
	guard = ENEMY.instantiate()
	guard.enemy_resource = GUARD
	guard.position = Vector3(-5,0.91,0)
	add_child(guard)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60,20,0)
	add_child(light)
	if automatic:
		await _run()
	else:
		var ui := CanvasLayer.new()
		add_child(ui)
		var label := Label.new()
		label.text = "V2.1.5-A.1 | COVER: fixed guard / CHASE: mobile guard\nPC Ctrl STEALTH, Shift RUN | Android MODE: WALK/RUN/STEALTH"
		ui.add_child(label)
		var buttons := HBoxContainer.new()
		buttons.position = Vector2(12,65)
		ui.add_child(buttons)
		for index in 4:
			var button := Button.new()
			button.text = ["HIGH","MEDIUM","LOW","OPEN"][index]
			button.custom_minimum_size = Vector2(80,48)
			button.pressed.connect(_manual_lane.bind(index))
			buttons.add_child(button)
		var mode := Button.new()
		mode.text = "COVER / CHASE"
		mode.custom_minimum_size = Vector2(130,48)
		mode.pressed.connect(func(): chase_mode = not chase_mode; _manual_lane(0))
		buttons.add_child(mode)
		var debug_button := Button.new()
		debug_button.text = "DEBUG"
		debug_button.custom_minimum_size = Vector2(80,48)
		debug_button.pressed.connect(func(): diagnostic_mode = (diagnostic_mode+1)%3)
		buttons.add_child(debug_button)
		compact = Label.new()
		compact.position = Vector2(12,120)
		ui.add_child(compact)
		var touch := load("res://scenes/ui/TouchControls.tscn") as PackedScene
		add_child(touch.instantiate())
		add_child((load("res://scenes/ui/CombatUI.tscn") as PackedScene).instantiate())
		add_child((load("res://scenes/ui/RewardUI.tscn") as PackedScene).instantiate())
		_manual_lane(0)


func _manual_lane(index: int) -> void:
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	player.unfreeze_after_combat()
	if is_instance_valid(guard):
		guard.perception_timer.stop()
		guard.set_physics_process(false)
		guard.queue_free()
	var x: float = [-5.0,0.0,5.0,10.0][index]
	player.position = Vector3(x,0.86,-8)
	guard = ENEMY.instantiate()
	guard.enemy_resource = GUARD
	guard.position = Vector3(x,0.91,0)
	add_child(guard)
	guard.set_physics_process(chase_mode)


func _process(_delta: float) -> void:
	if automatic or compact == null or not is_instance_valid(guard): return
	var data := guard.get_cover_perception_debug()
	compact.visible = diagnostic_mode == 1
	compact.text = "%s | STATE:%s | DIST:%s | FOV:%s | LOS:%s | COVER:%s | POSTURE:%s" % ["CHASE" if chase_mode else "COVER",data.state,data.distance,data.fov,data.los,data.cover,data.posture]
	guard.debug_label.visible = diagnostic_mode == 2

func _run() -> void:
	# Matrix isolates LOS while normal perception timer remains active.
	guard.set_physics_process(false)
	await _wait(0.3)
	for index in 3:
		for crouch in [false,true]:
			CombatManager.reset_after_defeat()
			CombatEncounterManager.reset()
			guard.position = Vector3((index-1)*5,0.91,0)
			guard.rotation = Vector3.ZERO
			player.position = Vector3((index-1)*5,0.86,-8)
			if crouch: Input.action_press("stealth")
			else: Input.action_release("stealth")
			await _wait(0.4)
			var expected: bool = index == 2 or (index == 1 and not crouch)
			_check(player.is_crouched() == crouch,"posture %s/%s" % [index,crouch])
			_check(guard.get_cover_perception_debug().fov == "YES","fixture FOV valid %s/%s" % [index,crouch])
			print("V215_COVER_EVIDENCE="+JSON.stringify(guard.get_cover_perception_debug()))
			var raw := PhysicsRayQueryParameters3D.create(guard.get_vision_origin(),player.get_node("Head").global_position,Enemy.WORLD_COLLISION_MASK,[guard.get_rid()])
			var raw_hit := get_world_3d().direct_space_state.intersect_ray(raw)
			print("V215_RAW_COLLIDER="+(str(raw_hit.collider.get_path()) if not raw_hit.is_empty() else "NONE"))
			_check((guard._last_vision_result != Enemy.VISION_NONE) == expected,"cover category %s crouch %s" % [index,crouch])
	# Deliberately invalid FOV must not be misreported as a MEDIUM LOS bug.
	Input.action_release("stealth")
	guard.position = Vector3(0,0.91,0)
	player.position = Vector3(0,0.86,-8)
	guard.rotation.y = PI
	await _wait(0.4)
	_check(guard._last_vision_result == Enemy.VISION_NONE and guard.get_cover_perception_debug().fov == "NO" and guard.get_cover_perception_debug().cover == "N/A","MEDIUM standing: FOV failure distinct from cover")
	guard.rotation.y = 0.0
	await _wait(0.4)
	_check(guard._last_vision_result != Enemy.VISION_NONE and guard.get_cover_perception_debug().cover == "MEDIUM:PASS","MEDIUM standing visible when FOV restored")
	for crouch in [false,true]:
		player.position = Vector3(10,0.86,-8)
		guard.position = Vector3(10,0.91,0)
		if crouch: Input.action_press("stealth")
		else: Input.action_release("stealth")
		await _wait(0.4)
		_check(guard._last_vision_result != Enemy.VISION_NONE,"open exposure both postures %s" % crouch)
	# Real clearance for uncrouching under a low ceiling; no collider disabled.
	var ceiling := StaticBody3D.new()
	ceiling.position = player.position + Vector3(0,0.5,0)
	add_child(ceiling)
	_box(Vector3.ZERO,Vector3(2,0.15,2),ceiling)
	# Register the newly-created test collider before asking to stand.
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("stealth")
	await _wait(0.3)
	_check(player.is_crouched(),"ceiling prevents standing")
	ceiling.queue_free()
	await _wait(0.4)
	if player.is_crouched():
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := CapsuleShape3D.new()
		shape.height = 1.7
		shape.radius = 0.4
		query.shape = shape
		query.transform = player.global_transform
		query.collision_mask = player.collision_mask
		query.exclude = [player.get_rid()]
		query.margin = 0.001
		for hit in get_world_3d().direct_space_state.intersect_shape(query):
			print("V215_HEADROOM_COLLIDER %s player=%s collider=%s" % [hit.collider.get_path(),player.position,hit.collider.position])
	_check(not player.is_crouched(),"standing resumes with headroom")
	# Move laterally into open lane, still crouched. Vision is not invisibility.
	Input.action_press("stealth")
	player.position = Vector3(-2,0.86,-8)
	guard.position = Vector3(-5,0.91,0)
	guard.rotation = Vector3.ZERO
	await _wait(0.4)
	_check(guard._last_vision_result != Enemy.VISION_NONE,"lateral exposure restores normal vision while crouched")
	var wall := StaticBody3D.new()
	add_child(wall)
	_box(Vector3(-3.5,1.5,-4),Vector3(8,3,0.3),wall)
	await _wait(0.4)
	_check(guard._last_vision_result == Enemy.VISION_NONE,"ordinary wall blocks sight")
	wall.queue_free()
	Input.action_release("stealth")
	var touch := (load("res://scenes/ui/TouchControls.tscn") as PackedScene).instantiate()
	add_child(touch)
	touch.visible = true
	player.touch_controls = touch
	var rotation_before: Vector3 = player.get_node("Head").rotation
	for index in 3:
		player.cycle_mobile_movement_mode()
		await _wait(0.1)
		_check(player.is_crouched() == (index == 1),"Android mode posture %s" % index)
	_check(player.get_node("Head").rotation == rotation_before,"posture never rotates camera")
	var path := NavigationServer3D.map_get_path(get_world_3d().get_navigation_map(),Vector3(-5,0,0),Vector3(-5,0,-8),true)
	_check(path.size() >= 2,"route around HIGH exists on real navigation map")
	Input.action_press("stealth")
	var light_level := LightingManager.get_light_level_at(player.position)
	var capability: float = GUARD.light_detection_curve[light_level]
	_check(capability > 0.0,"FIXTURE_CONFIGURATION: light permits progressive confirmation")
	var detection_deadline := Time.get_ticks_msec()+int((GUARD.detection_time_sec/maxf(capability,0.001)+GUARD.perception_interval_sec*3)*1000)
	while guard._last_vision_result != Enemy.VISION_CHASE and Time.get_ticks_msec() < detection_deadline:
		await get_tree().physics_frame
	_check(player.is_crouched() and guard._last_vision_result == Enemy.VISION_CHASE,"exposed crouched player is progressively confirmed at 8.5m")
	_check(guard.get_debug_last_known_source() == "VISION","normal vision supplies last known position")
	Input.action_release("stealth")
	guard.set_physics_process(true)
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	player.unfreeze_after_combat()
	await _run_obstacle_pursuit()
	await _run_local_search()
	print("V215_COVER_RESULT="+JSON.stringify({"valid":errors.is_empty(),"errors":errors}))
	get_tree().quit(0 if errors.is_empty() else 1)


func _run_obstacle_pursuit() -> void:
	guard.perception_timer.stop()
	guard.queue_free()
	await get_tree().physics_frame
	player.position = Vector3(5,0.86,-8)
	guard = ENEMY.instantiate()
	guard.enemy_resource = GUARD
	guard.position = Vector3(5,0.91,0)
	add_child(guard)
	var route := NavigationServer3D.map_get_path(get_world_3d().get_navigation_map(),Vector3(5,0,0),Vector3(5,0,-8),true)
	_check(route.size() > 2,"FIXTURE_CONFIGURATION: obstacle route has detour")
	var length := 0.0
	for index in range(1,route.size()): length += route[index-1].distance_to(route[index])
	var deadline := Time.get_ticks_msec()+int((length/GameBalance.get_speed(GUARD.chase_speed_tier)+GUARD.perception_interval_sec*5)*1000)
	var lateral := 0.0
	var states: Array[String] = []
	while Time.get_ticks_msec() < deadline and guard.position.z > -4.6:
		await get_tree().physics_frame
		lateral = maxf(lateral,absf(guard.position.x-5.0))
		var state := guard.get_debug_state_name()
		if state not in states: states.append(state)
	_check(guard.position.z < -4.6 and lateral > 1.3,"real sensory pursuit navigates around physical LOW")
	print("V215_OBSTACLE_PURSUIT="+JSON.stringify({"position":str(guard.position),"lateral_m":lateral,"states":states,"path_m":length}))
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	player.unfreeze_after_combat()


func _run_local_search() -> void:
	guard.queue_free()
	await get_tree().physics_frame
	player.position = Vector3(10,0.86,-8)
	guard = ENEMY.instantiate()
	guard.enemy_resource = GUARD
	guard.position = Vector3(10,0.91,0)
	add_child(guard)
	var deadline := Time.get_ticks_msec()+int(GUARD.perception_interval_sec*3*1000)
	while guard._last_vision_result == Enemy.VISION_NONE and Time.get_ticks_msec() < deadline: await get_tree().physics_frame
	_check(guard._last_vision_result != Enemy.VISION_NONE,"search fixture receives normal visual stimulus")
	var known := guard.get_debug_last_known_position()
	player.position = Vector3(-12,0.86,12)
	var search_seen := false
	var points: Array[Vector3] = []
	var reference: Array[Vector3] = []
	var visited := 0
	var motion := 0.0
	var forward_ok := true
	var previous := guard.position
	# Travel bound from actual speed + existing search timeout, no fake AI state.
	var seconds := known.distance_to(guard.position)/GameBalance.get_speed(GUARD.chase_speed_tier)+GUARD.lose_target_timeout_sec+GUARD.perception_interval_sec*5
	deadline = Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if guard._searching_at_last_known:
			if not search_seen:
				points = guard._alert_search_points.duplicate()
				reference = guard._build_local_search_points()
				print("V215_SEARCH_BEGIN="+JSON.stringify({"known":str(known),"position":str(guard.position),"points":points}))
			search_seen = true
			visited = maxi(visited, guard._alert_search_index)
			var step := guard.position-previous
			step.y = 0.0
			motion += step.length()
			if step.length() > 0.001 and guard._alert_search_pause <= 0.0:
				forward_ok = forward_ok and (-guard.global_basis.z).dot(step.normalized()) > 0.8
		if search_seen and guard.get_debug_state_name() == "PATROL": break
		previous = guard.position
	_check(search_seen and points.size() == 2,"ALERT selects two navigable local points")
	_check(points == reference,"local search candidates deterministic")
	_check(visited == 2 and motion > 1.0,"ALERT physically investigates bounded points")
	_check(forward_ok,"ALERT faces physical movement")
	_check(guard.get_debug_state_name() == "PATROL" and not guard._searching_at_last_known,"bounded search returns to PATROL")
	_check(guard.get_debug_last_known_position() == known,"search never knows hidden player position")
	print("V215_SEARCH_RESULT="+JSON.stringify({"points":points.size(),"visited":visited,"motion_m":motion,"forward_ok":forward_ok,"state":guard.get_debug_state_name()}))
