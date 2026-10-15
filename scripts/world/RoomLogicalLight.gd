extends Node3D

## Legacy uniform room contribution, or opt-in coherent ceiling fixture.
## No ambient mutation. The opt-in source can illuminate through a real opening
## within range, but static geometry occludes it; the legacy footprint stays inert.
var footprint := Vector2.ZERO
var addition := 2
var model: RoomLightModelResource
var profile_id := ""
var active := true
var visual: SpotLight3D
var query_count := 0
var query_usec := 0

func _ready() -> void:
	if model != null:
		visual = SpotLight3D.new()
		visual.name = "FixtureLight"
		visual.rotation_degrees.x = -90.0
		visual.spot_range = model.range_m
		visual.spot_angle = model.cone_half_angle_deg
		visual.spot_attenuation = 1.0
		visual.light_energy = addition * model.logical_peak_per_room_unit * model.visual_energy_per_logical_unit
		visual.light_color = model.color
		visual.shadow_enabled = model.shadows_enabled
		add_child(visual)
		set_active(model.enabled)
	LightingManager.register_light_source(self)

func _exit_tree() -> void:
	LightingManager.unregister_light_source(self)

func get_light_contribution_at(world_position: Vector3) -> float:
	if model != null:
		var started := Time.get_ticks_usec()
		query_count += 1
		var value := model.contribution(to_local(world_position),addition) if active else 0.0
		if value > 0.0:
			# Only static world geometry (layer 1), never Player/Enemy or bake proxies.
			# Shorten the endpoint to avoid treating the sampled floor as an occluder.
			var end := world_position.move_toward(global_position,0.03)
			var ray := PhysicsRayQueryParameters3D.create(global_position,end,1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): value = 0.0
		query_usec += Time.get_ticks_usec()-started
		return value
	var local := to_local(world_position)
	return float(addition) if absf(local.x) < footprint.x*0.5 and absf(local.z) < footprint.y*0.5 and local.y > -0.25 and local.y < 3.0 else 0.0

func set_active(value: bool) -> void:
	active = value
	if visual != null: visual.visible = active
	var fixture := get_node_or_null("Fixture") as MeshInstance3D
	if fixture != null: fixture.visible = active

func get_light_diagnostic() -> Dictionary:
	return {"source":str(get_path()),"profile":profile_id,"position":global_position,
		"active":active,"range_m":model.range_m if model != null else 0.0,
		"queries":query_count,"query_usec":query_usec}
