extends Node3D

const SOURCE := preload("res://scripts/world/RoomLogicalLight.gd")
const MODEL := preload("res://resources/run/VarkhemRoomEnvironment.tres")
var errors: Array[String] = []
var rows: Array = []
var player: CharacterBody3D
var guard: Enemy
var source: Node3D

func check(value: bool, contract: String) -> void:
	if not value: errors.append(contract)

func wait_ticks(count: int) -> void:
	for _tick in count: await get_tree().physics_frame

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

func sample(label: String) -> void:
	var exposure := LightingManager.get_exposure_diagnostic(player.global_position)
	rows.append({"case":label,"light":exposure,"perception":guard.get_cover_perception_debug(),"vision":guard._last_vision_result})
	check(exposure.level == LightingManager.get_light_level_at(player.global_position),label+": shared HUD/perception exposure")

func _ready() -> void:
	CombatEncounterManager.combat_transition_enabled = false
	LightingManager.set_ambient_light_level(1)
	box(Vector3(0,-0.1,-4),Vector3(30,0.2,30))
	player = preload("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector3(0,0.86,-5)
	add_child(player)
	guard = preload("res://scenes/enemies/Enemy.tscn").instantiate()
	guard.enemy_resource = preload("res://resources/enemies/orco_melee.tres")
	guard.position = Vector3(0,0.91,0)
	add_child(guard)
	guard.set_physics_process(false) # stationary FOV fixture; real perception Timer.
	source = SOURCE.new()
	source.model = MODEL.coherent_light
	source.profile_id = "V23_FIXTURE"
	source.position = Vector3(0,source.model.mounting_height_m,-5)
	add_child(source)
	await wait_ticks(3)
	check(source.visual.spot_range == source.model.range_m,"one shared range")
	check(is_equal_approx(source.visual.light_energy,source.addition*source.model.logical_peak_per_room_unit*source.model.visual_energy_per_logical_unit),"explicit energy mapping")
	check(source.visual.shadow_enabled,"visible geometry occlusion enabled")
	check((-source.visual.global_transform.basis.z).dot(Vector3.DOWN) > 0.999,"visual cone matches logical downward cone")
	check(LightingManager.get_light_level_at(player.global_position) >= 3,"under fixture exposed")
	check(source.get_light_contribution_at(Vector3(10,0.86,-5)) == 0.0,"outside source range")
	var wall := box(Vector3(1,1.3,-5),Vector3(0.3,3,3))
	await wait_ticks(3)
	check(source.get_light_contribution_at(Vector3(2,0.86,-5)) == 0.0,"static geometry occludes exposure")
	wall.queue_free()
	await wait_ticks(3)
	check(source.get_light_contribution_at(Vector3(2,0.86,-5)) > 0.0,"occlusion removal restores source")
	# Normal progressive perception observes PATROL -> ALERT -> CHASE.
	var seen_alert := guard.get_debug_state_name() == "ALERT"
	var deadline := Time.get_ticks_msec()+2500
	while guard._last_vision_result != Enemy.VISION_CHASE and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		seen_alert = seen_alert or guard.get_debug_state_name() == "ALERT"
	check(seen_alert,"lit exposure retains progressive ALERT")
	check(guard._last_vision_result == Enemy.VISION_CHASE,"normal timer confirms lit exposed player")
	sample("lit_chase")
	source.set_active(false)
	await wait_ticks(18)
	check(not source.visual.visible and source.get_light_contribution_at(player.global_position) == 0.0,"activation affects both channels")
	check(guard._last_vision_result == Enemy.VISION_CHASE,"shade does not erase already accumulated confirmed exposure")
	sample("ambient_after_confirmation")
	source.set_active(true)
	var cover := LogicalCover.new()
	cover.position = Vector3(0,1,-2.5)
	cover.visibility_volume = AABB(Vector3(-1,-1,-0.5),Vector3(2,3,1))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2,2,1)
	collision.shape = shape
	cover.add_child(collision)
	add_child(cover)
	for category in [LogicalCover.Category.HIGH,LogicalCover.Category.MEDIUM,LogicalCover.Category.LOW]:
		cover.category = category
		for crouched in [false,true]:
			if crouched: Input.action_press("stealth")
			else: Input.action_release("stealth")
			await wait_ticks(30)
			check(player.is_crouched() == crouched,"real posture fixture")
			var expected: bool = category == LogicalCover.Category.LOW or (category == LogicalCover.Category.MEDIUM and not crouched)
			check((guard.get_cover_perception_debug().los == "YES") == expected,"unchanged cover LOS %s/%s" % [category,crouched])
			sample("cover_%s_%s" % [category,crouched])
	cover.queue_free()
	Input.action_release("stealth")
	wall = box(Vector3(0,1.5,-2.5),Vector3(5,3,0.3))
	await wait_ticks(18)
	check(guard.get_cover_perception_debug().los == "NO","wall still blocks guard LOS")
	wall.queue_free()
	# Moving sample, same source function; no exposure grid or independent HUD formula.
	await wait_ticks(3)
	player.position = Vector3(0,0.86,-5)
	var before_move := player.position
	var before_exposure: float = source.get_light_contribution_at(player.global_position)
	Input.action_press("move_right")
	await wait_ticks(30)
	Input.action_release("move_right")
	check(player.position.distance_to(before_move) > 0.5,"real input/collision movement during exposure")
	check(source.get_light_contribution_at(player.global_position) < before_exposure,"moving away lowers contribution")
	sample("real_movement")
	for x in [0.0,2.0,4.0,8.0]:
		player.position.x = x
		await wait_ticks(2)
		sample("movement_%s" % x)
	var start := Time.get_ticks_usec()
	for _index in 10000: LightingManager.get_light_level_at(Vector3(0,0.86,-5))
	var elapsed := Time.get_ticks_usec()-start
	var process_total := 0.0
	var physics_total := 0.0
	for _index in 120:
		await get_tree().physics_frame
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("V23_LIGHT_RESULT="+JSON.stringify({"valid":errors.is_empty(),"errors":errors,"rows":rows,"queries_10000_usec":elapsed,"source":source.get_light_diagnostic(),"headless_process_mean_ms":process_total/120.0*1000.0,"headless_physics_mean_ms":physics_total/120.0*1000.0,"render_measurement":"INCOMPLETE_HEADLESS"}))
	Input.action_release("stealth")
	CombatEncounterManager.reset()
	get_tree().quit(0 if errors.is_empty() else 1)
