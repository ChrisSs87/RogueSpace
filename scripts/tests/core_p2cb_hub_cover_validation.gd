extends "res://scripts/tests/varkhem_v215_c_environment_validation.gd"

const BUILDER := preload("res://scripts/world/RoomEnvironmentBuilder.gd")
const PLAYER := preload("res://scenes/player/Player.tscn")
var witnesses: Array = []

func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	witnesses = []
	var modules: Node3D = dungeon.get_node("AssembledModules")
	var profile: RoomEnvironmentProfileResource = dungeon.active_archetype.room_environment_profile
	var map: RID = dungeon.nav_region.get_navigation_map()
	if profile.distribution_cover_candidates.size() != 2 or profile.max_covers_per_distribution != 1: errors.append("configured hub candidates failed to load")
	if _hub_nodes(dungeon.current_plan).size() != dungeon.current_room_environment_report.get("distribution",[]).size(): errors.append("semantic hub not evaluated")
	for audit in dungeon.current_room_environment_report.get("distribution",[]):
		var module: Node3D = modules.get_node(NodePath(String(audit.node)))
		var definition: ModuleDefinitionResource = dungeon.current_plan.module_definitions[audit.node]
		if audit.instantiated > profile.max_covers_per_distribution: errors.append("hub budget exceeded")
		if audit.examined.size() != profile.distribution_cover_candidates.size(): errors.append("hub candidates not audited")
		# Deliberate invalid probes exercise rejection, not weakened clearances.
		if BUILDER._distribution_rejection(definition,definition.footprint_size,AABB(Vector3(-0.5,0,-0.5),Vector3.ONE),profile) != "reserved circulation/access cross": errors.append("axis intrusion accepted")
		if BUILDER._distribution_rejection(definition,definition.footprint_size,AABB(Vector3(-8,0,-8),Vector3.ONE),profile) != "footprint/wall margin": errors.append("wall intrusion accepted")
		for cover in module.get_children():
			if not cover is LogicalCover: continue
			var size: Vector3 = Vector3.ZERO
			for part in cover.get_children():
				if part is CollisionShape3D: size = part.shape.size
			if cover.category != LogicalCover.Category.MEDIUM: errors.append("non MEDIUM hub cover")
			var rejection := BUILDER._distribution_rejection(definition,definition.footprint_size,AABB(cover.position-size*0.5,size),profile)
			if not rejection.is_empty(): errors.append("unsafe accepted hub cover: "+rejection)
			# A HIGH-sized prop in the same inner strip violates patrol reserve.
			if BUILDER._distribution_rejection(definition,definition.footprint_size,AABB(cover.position-profile.cover_size_high*0.5,profile.cover_size_high),profile).is_empty(): errors.append("HIGH patrol intrusion probe accepted")
			witnesses.append(_witness(dungeon,module,cover,map))
			if witnesses[-1].status == "FAIL": errors.append("tactical witness contract failed")
			# Pure LogicalCover transform contract, separately from runtime bake.
			var probe := LogicalCover.new()
			probe.category = cover.category
			probe.visibility_volume = cover.visibility_volume
			add_child(probe)
			for quarter in 4:
				for mirror in [1.0,-1.0]:
					var basis := Basis(Vector3.UP,quarter*PI*0.5).scaled(Vector3(mirror,1,1))
					probe.transform = Transform3D(basis,Vector3(100,5,100))
					var from := probe.to_global(Vector3(-3,1,0))
					var to := probe.to_global(Vector3(3,1,0))
					if probe.blocks_sight(from,to,false) or not probe.blocks_sight(from,to,true): errors.append("MEDIUM rotated/mirrored posture contract")
			probe.free()
	print("P2CB_HUB="+JSON.stringify({"seed":dungeon.seed,"sector":dungeon.current_sector_index,"geometry_errors":errors,"distribution":dungeon.current_room_environment_report.get("distribution",[]),"witnesses":witnesses,"dynamic_tactics":"INCOMPLETE"}))
	return errors

## A bounded snapshot witness, not a claim of evasion during combined patrols.
## Real guard eye/LOS rules, real Player capsule/posture, actual bake/physics.
## No AI state or contact is injected; no production field is changed.
func _witness(dungeon: Node3D, module: Node3D, cover: LogicalCover, map: RID) -> Dictionary:
	var result := {"node":String(module.name),"status":"INCOMPLETE","reason":"no accessible witness at current relevant guard snapshot","dynamic":"INCOMPLETE"}
	for guard: Enemy in dungeon.get_node("RuntimeContent").get_children():
		if not guard.get_meta("patrol_kind",&"") == &"HUB": continue
		if not guard.get_meta("patrol_world_points",[]).any(func(p): return module.to_local(p).length() < 8.0): continue
		# The protected circulation center is the actual traversal being tested,
		# not a pocket chosen simply because it lies behind the box.
		var target := module.global_position
		target.y = module.global_position.y+0.86
		var projected := NavigationServer3D.map_get_closest_point(map,target)
		if Vector2(projected.x-target.x,projected.z-target.z).length() > 0.12: continue
		var entry := NavigationServer3D.map_get_closest_point(map,dungeon.start_point)
		if NavigationServer3D.map_get_path(map,entry,projected,true).size() < 2 or NavigationServer3D.map_get_path(map,projected,entry,true).size() < 2: continue
		var player: CharacterBody3D = PLAYER.instantiate()
		add_child(player)
		player.set_physics_process(false)
		player.global_position = target
		var shape_query := PhysicsShapeQueryParameters3D.new()
		shape_query.shape = player.get_node("CollisionShape3D").shape
		shape_query.transform = player.get_node("CollisionShape3D").global_transform
		shape_query.collision_mask = 1|4
		shape_query.exclude = [player.get_rid()]
		shape_query.margin = 0.0
		if not get_world_3d().direct_space_state.intersect_shape(shape_query).is_empty():
			player.free()
			continue
		var eye := guard.get_vision_origin()
		var head: Node3D = player.get_node("Head")
		var standing := guard._has_clear_vision_line(eye,head.global_position,player)
		player.movement_state = player.MovementState.STEALTH
		player._update_posture(1.0)
		var crouched := guard._has_clear_vision_line(eye,head.global_position,player)
		var forward := -guard.global_basis.z
		var toward := target-guard.global_position
		toward.y = 0
		var fov := rad_to_deg(Vector3(forward.x,0,forward.z).angle_to(toward)) <= guard.enemy_resource.vision_angle_deg*0.5
		var range_ok := toward.length() <= guard.get_debug_fov_range_m()
		var interposed := cover.interposes(eye,head.global_position)
		var status := "LOS_WITNESS_PASS" if standing and not crouched and interposed and range_ok and fov else "INCOMPLETE"
		if interposed and crouched: status = "FAIL"
		result = {"node":String(module.name),"guard":String(guard.name),"position":target,"nav_projected":projected,"capsule_clear":true,"path_both_ways":true,"distance":toward.length(),"range":range_ok,"fov_snapshot":fov,"standing_los":standing,"crouched_los":crouched,"cover_interposed":interposed,"status":status,"dynamic":"INCOMPLETE"}
		player.free()
		if result.status == "LOS_WITNESS_PASS": return result
	return result

func _additional_physical_metrics(dungeon: Node3D) -> Dictionary:
	var result := super._additional_physical_metrics(dungeon)
	result["hub_tactical_snapshot"] = witnesses.duplicate(true)
	result["hub_dynamic_tactics"] = "INCOMPLETE"
	return result
