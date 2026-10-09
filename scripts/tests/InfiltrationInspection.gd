extends "res://scripts/tests/ProceduralInspection.gd"

var infiltration := false
var details: Label
var routes: MeshInstance3D
var elapsed := 0.0
var last_noise := "none"
var observed_states := {}
var previous_debug := false

func _ready() -> void:
	super._ready()
	previous_debug = DebugConfig.perception_debug_enabled
	DebugConfig.perception_debug_enabled = false
	var panel := info.get_parent()
	_button(panel, "INFILTRATION DEBUG", _toggle_infiltration)
	details = Label.new()
	details.add_theme_font_size_override("font_size", 14)
	panel.add_child(details)
	details.hide()
	routes = MeshInstance3D.new()
	add_child(routes)
	routes.hide()
	EventBus.player_noise_emitted.connect(_noise)

func _exit_tree() -> void:
	DebugConfig.perception_debug_enabled = previous_debug

func _toggle_infiltration() -> void:
	infiltration = not infiltration
	DebugConfig.perception_debug_enabled = infiltration
	details.visible = infiltration
	routes.visible = infiltration

func _noise(_position: Vector3, radius: float, intensity: float) -> void:
	last_noise = "radius %.1fm / intensity %.2f" % [radius,intensity]

func _process(delta: float) -> void:
	super._process(delta)
	info.text = info.text.replace("V2.1.1", "V2.1.2")
	elapsed += delta
	if not infiltration or elapsed < 0.2: return
	elapsed = 0.0
	var player: Node3D = stage.get_node("Player")
	var lines: Array[String] = ["LIGHT %d/5 | NOISE %s" % [LightingManager.get_light_level_at(player.global_position),last_noise]]
	var root := stage.get_node_or_null("RuntimeContent")
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.GOLD
	if root != null:
		for enemy: Enemy in root.get_children():
			var key: String = str(enemy.get_instance_id())
			var state := enemy.get_debug_state_name()
			var observed: Dictionary = observed_states.get(key,{"state":state,"transition":"initial"})
			if observed.state != state:
				observed.transition = "%s→%s / last stimulus %s" % [observed.state,state,enemy.get_debug_last_known_source()]
				observed.state = state
			observed_states[key] = observed
			lines.append("%s %s %.1fm | %s | %s" % [enemy.get_meta("patrol_kind",&"NONE"),state,enemy.global_position.distance_to(player.global_position),enemy.get_debug_ai_owner(),observed.transition])
			var points: Array = enemy.get_meta("patrol_world_points",[])
			if points.size() >= 2:
				mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
				for index in range(points.size()-1):
					mesh.surface_add_vertex(points[index]+Vector3.UP*0.15)
					mesh.surface_add_vertex(points[index+1]+Vector3.UP*0.15)
				mesh.surface_end()
	details.text = "\n".join(lines)
	routes.mesh = mesh
