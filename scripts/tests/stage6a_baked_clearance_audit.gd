extends Node3D

## Physical audit of the production B+C bake. Legacy manual regions are
## disabled by Fortress6A before this test starts. Enemy AI is disabled here:
## routes use the baked NavigationServer path plus the real capsule/body, so
## stuck recovery cannot turn an invalid normal route into a pass.
const SPEED_MPS := 2.0
const ARRIVAL_M := 0.35
const MIN_CLEARANCE_M := 0.45
const MAX_TICKS := 1200
const MAX_PROJECTION_M := 0.35

func _ready() -> void:
	var fortress: Node3D = $MainFortress6A/Fortress6A
	var player: CharacterBody3D = $MainFortress6A/Player
	var wait := 0
	while not fortress.call("is_navigation_bake_ready") and wait < 240:
		await get_tree().physics_frame
		wait += 1
	if not fortress.call("is_navigation_bake_ready"):
		push_error("Baked clearance audit: bake not ready")
		get_tree().quit(1)
		return
	var enemy: Enemy = fortress.get_node("InitialMelee")
	enemy.set_physics_process(false)
	player.set_physics_process(false)
	# This harness audits architecture, not overlap with the real Player parked
	# at Spawn/Well. Production collision masks are never changed.
	var player_collision_layer := player.collision_layer
	player.collision_layer = 0
	CombatEncounterManager.combat_transition_enabled = false
	var selected := "ALL"
	var route_contains := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baked-audit="):
			selected = argument.trim_prefix("--baked-audit=")
		if argument.begins_with("--route-contains="):
			route_contains = argument.trim_prefix("--route-contains=")
	var passed := true
	if selected == "END_TO_END":
		passed = await _run_route(enemy, fortress, {"name":"END_TO_END_EAST", "start":Vector3(2,1,0), "target":Vector3(70,1,0)})
		passed = await _run_route(enemy, fortress, {"name":"END_TO_END_WEST", "start":Vector3(70,1,0), "target":Vector3(2,1,0)}) and passed
	else:
		for route in _transition_routes():
			if selected != "ALL" and not String(route.name).begins_with(selected):
				continue
			if not route_contains.is_empty() and not String(route.name).contains(route_contains):
				continue
			passed = await _run_route(enemy, fortress, route) and passed
	CombatEncounterManager.combat_transition_enabled = true
	player.collision_layer = player_collision_layer
	if passed:
		print("Stage6A baked clearance audit %s: PASS" % selected)
		get_tree().quit()
	else:
		push_error("Stage6A baked clearance audit %s: FAIL" % selected)
		get_tree().quit(1)

func _transition_routes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var transitions := [
		{"id":"X09", "x":9.0, "z":0.0}, {"id":"X17", "x":17.0, "z":0.0},
		# x=41 is two actual merge mouths; its old z=0.55 input had no floor.
		{"id":"X41_N", "x":41.0, "z":2.85}, {"id":"X41_S", "x":41.0, "z":-2.85},
		{"id":"X49", "x":49.0, "z":0.0}, {"id":"X58", "x":58.0, "z":0.0},
		{"id":"X66", "x":66.0, "z":0.0},
	]
	var variants := [{"tag":"CENTER", "offset":0.0}, {"tag":"LEFT_MOD", "offset":0.20}, {"tag":"LEFT_AGG", "offset":0.35}, {"tag":"RIGHT_MOD", "offset":-0.20}, {"tag":"RIGHT_AGG", "offset":-0.35}]
	for transition in transitions:
		var x: float = transition.x
		for variant in variants:
			var z: float = float(transition.z) + float(variant.offset)
			result.append({"name":"%s_%s_EAST" % [transition.id, variant.tag], "start":Vector3(x - 2.5, 1, z), "target":Vector3(x + 3.5, 1, z)})
			result.append({"name":"%s_%s_WEST" % [transition.id, variant.tag], "start":Vector3(x + 3.5, 1, z), "target":Vector3(x - 2.5, 1, z)})
	return result

func _run_route(enemy: Enemy, fortress: Node3D, route: Dictionary) -> bool:
	enemy.global_position = route.start
	enemy.velocity = Vector3.ZERO
	enemy._navigation_target = Vector3.INF
	enemy._semantic_navigation_target = Vector3.INF
	await get_tree().physics_frame
	var map := fortress.get_world_3d().get_navigation_map()
	var start_check := _validate_endpoint(map, route.start)
	var target_check := _validate_endpoint(map, route.target)
	if not start_check.valid or not target_check.valid:
		print("6A BAKE TRANSITION %s | TEST INPUT INVALID start=%s end=%s" % [route.name, start_check.kind, target_check.kind])
		return false
	var start: Vector3 = start_check.projected
	var target: Vector3 = target_check.projected
	print("6A BAKE INPUT %s | start=VALID gap=%.3f end=VALID gap=%.3f" % [route.name, start_check.gap, target_check.gap])
	enemy.global_position = route.start
	await get_tree().physics_frame
	var path := NavigationServer3D.map_get_path(map, start, target, true)
	if path.size() < 2:
		print("6A BAKE TRANSITION %s | FAIL connected=false" % route.name)
		return false
	var index := 0
	while index < path.size() and _flat_distance(enemy.global_position, path[index]) < 0.1:
		index += 1
	var min_clearance := _wall_clearance(fortress, enemy.global_position)
	var min_at := enemy.global_position
	var stationary := 0.0
	var max_stationary := 0.0
	var collisions := 0
	var recovery_before := enemy.get_debug_stuck_recovery_count()
	var reached := false
	var path_length := 0.0
	for path_index in range(1, path.size()):
		path_length += _flat_distance(path[path_index - 1], path[path_index])
	# Long end-to-end paths need enough physical frames at the same 2 m/s
	# harness speed. This is a timeout budget, not a relaxed arrival rule.
	var tick_budget := maxi(MAX_TICKS, ceili((path_length / SPEED_MPS + 2.0) * 60.0))
	for _tick in tick_budget:
		while index < path.size() and _flat_distance(enemy.global_position, path[index]) < 0.12:
			index += 1
		var goal: Vector3 = target if index >= path.size() else path[index]
		var heading := goal - enemy.global_position
		heading.y = 0
		enemy.velocity = heading.normalized() * SPEED_MPS if heading.length() > 0.001 else Vector3.ZERO
		var before := enemy.global_position
		enemy.move_and_slide()
		var moved := _flat_distance(enemy.global_position, before)
		var current_clearance := _wall_clearance(fortress, enemy.global_position)
		if current_clearance < min_clearance:
			min_clearance = current_clearance
			min_at = enemy.global_position
		for collision_index in enemy.get_slide_collision_count():
			var collision := enemy.get_slide_collision(collision_index)
			if collision.get_normal().y < 0.7:
				collisions += 1
		if enemy.velocity.length() > 0.05 and moved < 0.002:
			stationary += 1.0 / 60.0
		else:
			stationary = 0.0
		max_stationary = maxf(max_stationary, stationary)
		if _flat_distance(enemy.global_position, target) <= ARRIVAL_M:
			reached = true
			break
		await get_tree().physics_frame
	var recovery_delta := enemy.get_debug_stuck_recovery_count() - recovery_before
	var clean := reached and min_clearance >= MIN_CLEARANCE_M and max_stationary < 0.5 and recovery_delta == 0
	var kind := "CLEAN PASS" if clean else ("RECOVERED PASS" if reached else "FAIL")
	print("6A BAKE TRANSITION %s | %s connected=true path=%d clearance=%.3f at=(%.2f,%.2f) stationary=%.2f collisions=%d recoveries=%d" % [route.name, kind, path.size(), min_clearance, min_at.x, min_at.z, max_stationary, collisions, recovery_delta])
	return clean

func _validate_endpoint(map: RID, requested: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(requested + Vector3.UP * 2.0, requested - Vector3.UP * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"valid":false, "kind":"INVALID PHYSICAL START", "projected":Vector3.ZERO, "gap":INF}
	var projected := NavigationServer3D.map_get_closest_point(map, requested)
	if projected == Vector3.ZERO:
		return {"valid":false, "kind":"START OFF NAVMESH", "projected":projected, "gap":INF}
	var gap := _flat_distance(requested, projected)
	if gap > MAX_PROJECTION_M:
		return {"valid":false, "kind":"INVALID PROJECTION %.3f" % gap, "projected":projected, "gap":gap}
	return {"valid":true, "kind":"VALID START", "projected":projected, "gap":gap}

func _wall_clearance(fortress: Node3D, position: Vector3) -> float:
	var closest := INF
	var walls := fortress.get_node("Walls")
	for node in walls.get_children():
		if node is CSGBox3D:
			var wall := node as CSGBox3D
			var half := wall.size * 0.5
			var local := wall.to_local(position)
			var dx := maxf(absf(local.x) - half.x, 0.0)
			var dz := maxf(absf(local.z) - half.z, 0.0)
			closest = minf(closest, Vector2(dx, dz).length())
	return closest

func _flat_distance(a: Vector3, b: Vector3) -> float:
	var delta := a - b
	delta.y = 0
	return delta.length()
