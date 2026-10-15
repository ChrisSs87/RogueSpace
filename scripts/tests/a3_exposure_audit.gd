extends Node3D

const SOURCE = preload("res://scripts/world/RoomLogicalLight.gd")
var variant := "OPERATIVA"
var scenario := "under"
var crouch := false
var rows: Array = []
var errors: Array = []
var player: CharacterBody3D
var guard: Enemy
var source: Node3D

func box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = pos
	add_child(body)
	return body

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		if arg.begins_with("--case="): scenario = arg.trim_prefix("--case=")
		if arg == "--crouch": crouch = true
	CombatEncounterManager.combat_transition_enabled = false
	var profile: BiomeLightingProfileResource = preload("res://resources/lighting/VarkhemLighting.tres")
	LightingManager.configure_biome(null if variant == "V23_A" else profile,self)
	LightingManager.set_ambient_light_level(1)
	box(Vector3(0,-0.1,-4),Vector3(30,0.2,30))
	player = preload("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector3(0,0.86,-5)
	add_child(player)
	if crouch: Input.action_press("stealth")
	source = SOURCE.new()
	source.model = preload("res://resources/run/VarkhemRoomEnvironment.tres").coherent_light if variant == "V23_A" else profile.get_source(&"military_ceiling").create_model(2.0,profile.get_variant(StringName(variant)),0.18)
	source.position = Vector3(0,1.9,-5)
	add_child(source)
	if scenario == "far": source.position.x = 10
	if scenario == "ambient": source.set_active(false)
	if scenario in ["HIGH","MEDIUM","LOW"]:
		var cover := LogicalCover.new()
		cover.category = {"HIGH":0,"MEDIUM":1,"LOW":2}[scenario]
		cover.position = Vector3(0,1,-2.5)
		cover.visibility_volume = AABB(Vector3(-1,-1,-0.5),Vector3(2,3,1))
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2,2,1)
		collision.shape = shape
		cover.add_child(collision)
		add_child(cover)
	if scenario == "wall": box(Vector3(0,1.5,-2.5),Vector3(5,3,0.3))
	# Settle posture/physics BEFORE starting the real perception Timer.
	for i in 30: await get_tree().physics_frame
	guard = preload("res://scenes/enemies/Enemy.tscn").instantiate()
	guard.enemy_resource = preload("res://resources/enemies/orco_picaro.tres")
	guard.position = Vector3(0,0.91,0)
	add_child(guard)
	guard.set_physics_process(false) # controlled orientation only, normal sensory Timer.
	var confirmation := -1.0
	var first_alert := -1.0
	var previous := player.global_position
	var start := player.global_position
	var frame := 0
	for i in 480: # eight seconds covers ambient1's configured 6.67s confirmation.
		frame = i
		if scenario == "moving":
			Input.action_release("move_right")
			Input.action_release("move_left")
			Input.action_press("move_right" if (i / 30) % 2 == 0 else "move_left")
		await get_tree().physics_frame
		if guard.get_debug_state_name() == "ALERT" and first_alert < 0: first_alert = float(i+1)/60.0
		if i % 12 == 11:
			rows.append({"sec":float(i+1)/60.0,"exposure":LightingManager.get_exposure_diagnostic(player.global_position),"perception":guard.get_cover_perception_debug(),"sight_timer":guard._sight_timer,"position":player.global_position,"delta_m":player.global_position.distance_to(previous)})
			previous = player.global_position
		if guard.has_confirmed_visual_contact(player):
			confirmation = float(i+1)/60.0
			break
	if not player.is_on_floor(): errors.append("FIXTURE_SUPPORT")
	if player.is_crouched() != crouch: errors.append("FIXTURE_POSTURE")
	var expected_block := scenario in ["HIGH","wall"] or (scenario == "MEDIUM" and crouch)
	if (confirmation < 0) != expected_block: errors.append("CONFIRMATION_CONTRACT")
	var result := {"variant":variant,"case":scenario,"crouch":crouch,"confirmation_sec":confirmation,"first_alert_sec":first_alert,"frames":frame+1,"errors":errors,"rows":rows,"movement_net_m":player.global_position.distance_to(start),"enemy":guard.enemy_resource.enemy_name,"functional":"PASS" if errors.is_empty() else "FAIL"}
	print("A3_EXPOSURE="+JSON.stringify(result))
	for action in ["stealth","move_right","move_left"]: Input.action_release(action)
	CombatEncounterManager.reset()
	get_tree().quit(0 if errors.is_empty() else 1)
