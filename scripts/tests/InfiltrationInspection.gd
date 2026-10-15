extends "res://scripts/tests/ProceduralInspection.gd"

var infiltration := false
var details: Label
var routes: MeshInstance3D
var elapsed := 0.0
var last_noise := "none"
var observed_states := {}
## Latest transition per live enemy stays available for the active scene.
## Retired snapshots are diagnostic only, never a gameplay/replay event log.
## Zero disables retired storage; discarded snapshots are counted explicitly.
@export_range(0, 256) var retired_state_history_limit := 32
var retired_state_history: Array[Dictionary] = []
var retired_state_history_dropped := 0
var _observed_runtime_id := 0
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

func _prune_observed_states(root: Node) -> void:
	var runtime_id := root.get_instance_id() if root != null else 0
	if runtime_id != _observed_runtime_id:
		_observed_runtime_id = runtime_id
		details.text = ""
		routes.mesh = null
		last_noise = "none"
	var live := {}
	if root != null:
		for enemy in root.get_children():
			if enemy is Enemy: live[str(enemy.get_instance_id())] = true
	for key in observed_states.keys():
		if live.has(key): continue
		var retired: Dictionary = observed_states[key].duplicate(true)
		retired["enemy_id"] = key
		retired_state_history.append(retired)
		observed_states.erase(key)
	while retired_state_history.size() > maxi(retired_state_history_limit,0):
		retired_state_history.pop_front()
		retired_state_history_dropped += 1

func get_debug_history_metrics() -> Dictionary:
	return {"active":observed_states.size(),"retired":retired_state_history.size(),"retired_limit":maxi(retired_state_history_limit,0),"discarded":retired_state_history_dropped,"scope":"latest transitions, not a complete replay log"}

func _process(delta: float) -> void:
	super._process(delta)
	info.text = info.text.replace("V2.1.1", "V2.1.4")
	if ExplorationState.can_update_positioning(CombatEncounterManager):
		info.text += "\nPOSITIONING / EXPLORATION SUSPENDED"
	else:
		info.text += "\nCOMBAT SUSPENDED" if ExplorationState.is_suspended() else "\nEXPLORATION ACTIVE"
	elapsed += delta
	if elapsed < 0.2: return
	elapsed = 0.0
	var root := stage.get_node_or_null("RuntimeContent")
	# Also retire obsolete IDs while the overlay is hidden.
	_prune_observed_states(root)
	if not infiltration: return
	var player: Node3D = stage.get_node("Player")
	var lines: Array[String] = ["LIGHT %d/5 | NOISE %s" % [LightingManager.get_light_level_at(player.global_position),last_noise]]
	var encounter := CombatEncounterManager.get_debug_encounter_diagnostic()
	lines.append("ENC %s | IN %d / OUT %d" % [encounter.result,encounter.participants.size(),encounter.excluded.size()])
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.GOLD
	if root != null:
		for enemy: Enemy in root.get_children():
			var key: String = str(enemy.get_instance_id())
			var state := enemy.get_debug_state_name()
			var observed: Dictionary = observed_states.get(key,{"state":state,"transition":"initial","seed":stage.seed,"sector":stage.current_sector_index})
			if observed.state != state:
				observed.transition = "%s→%s / last stimulus %s" % [observed.state,state,enemy.get_debug_last_known_source()]
				observed.state = state
			observed_states[key] = observed
			lines.append("%s %s %.1fm | %s | %s" % [enemy.get_meta("patrol_kind",&"NONE"),state,enemy.global_position.distance_to(player.global_position),enemy.get_debug_ai_owner(),observed.transition])
			lines.append("  %s | LAST %s | LOOK %s | MOVE %s" % [enemy.get_debug_stimulus_source(),enemy.get_debug_last_known_position(),-enemy.global_basis.z,enemy.get_debug_physical_heading()])
			lines.append("  %s | POS %s" % [enemy.get_debug_encounter_admission_reason(),enemy.get_debug_combat_position_reason()])
			var points: Array = enemy.get_meta("patrol_world_points",[])
			if points.size() >= 2:
				mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
				for index in range(points.size()-1):
					mesh.surface_add_vertex(points[index]+Vector3.UP*0.15)
					mesh.surface_add_vertex(points[index+1]+Vector3.UP*0.15)
				mesh.surface_end()
	details.text = "\n".join(lines)
	routes.mesh = mesh
