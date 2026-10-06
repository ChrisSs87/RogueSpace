extends Node3D

const BakeUtil = preload("res://scripts/tests/navigation_bake_test_util.gd")

## Verifica el pipeline real percepción -> candidate -> APPROACH -> COMBAT
## en cuatro posiciones incómodas del Player. No asigna estados internos:
## sólo posiciona los actores reales de MainFortress6A antes de que la
## percepción periódica haga su trabajo.
const CASES := {
	"center": {
		"player": Vector3(4.0, 1.0, 0.0),
		"enemy": Vector3(7.2, 1.0, -0.4),
	},
	"wall": {
		"player": Vector3(4.0, 1.0, 3.35),
		"enemy": Vector3(6.8, 1.0, 1.7),
	},
	"interior_corner": {
		# Cerca de los dos muros del ángulo noroeste, pero fuera de los
		# colliders para que la adquisición real no quede ocluida por el propio
		# Player antes de probar APPROACH.
		"player": Vector3(0.30, 1.0, 2.80),
		"enemy": Vector3(3.1, 1.0, 1.1),
	},
	"corridor_entry": {
		"player": Vector3(8.2, 1.0, 0.0),
		"enemy": Vector3(5.4, 1.0, -0.7),
	},
}


func _ready() -> void:
	var case_name := "center"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--approach-case="):
			case_name = argument.trim_prefix("--approach-case=")
	if not CASES.has(case_name):
		push_error("Unknown approach case: %s" % case_name)
		get_tree().quit(1)
		return

	var main: Node3D = $MainFortress6A
	var fortress: Node3D = main.get_node("Fortress6A")
	var player: CharacterBody3D = main.get_node("Player")
	var enemy: Enemy = fortress.get_node("InitialMelee")
	if "--nav-bc-height" in OS.get_cmdline_user_args():
		await BakeUtil.activate_bc_only(fortress, &"test_bc_approach_source")
		BakeUtil.align_agent_to_navigation_plane(enemy)
	# Evita que los otros tres patrulleros conviertan este caso aislado en 2v1.
	for enemy_name in ["StorageRogue", "BarracksMelee", "FinalRogue"]:
		var other: Enemy = fortress.get_node(enemy_name)
		other.perception_timer.stop()
		other.set_physics_process(false)

	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	await get_tree().create_timer(0.6).timeout
	var setup: Dictionary = CASES[case_name]
	player.global_position = setup["player"]
	player.velocity = Vector3.ZERO
	# La esquina puede quedar fuera de la antorcha inicial. Esta antorcha de
	# test sólo garantiza una exposición física comparable entre los cuatro
	# casos; la detección sigue pasando por LightingManager/percepción real.
	var test_light := LightSource.new()
	test_light.intensity = 5
	test_light.radius = 5.0
	main.add_child(test_light)
	test_light.global_position = player.global_position + Vector3.UP
	enemy.global_position = setup["enemy"]
	enemy.velocity = Vector3.ZERO
	# Es sólo la orientación inicial real para garantizar una oportunidad de
	# percepción; CHASE/CANDIDATE/APPROACH siguen siendo generados por runtime.
	var facing := player.global_position - enemy.global_position
	facing.y = 0.0
	if facing.length() > 0.05:
		enemy.look_at(enemy.global_position + facing.normalized(), Vector3.UP)
	# La patrulla física orienta al enemigo con su desplazamiento real. Para
	# este test de posicionamiento fijamos únicamente el instante inicial de
	# exposición: el Timer de percepción real registra el contacto antes de
	# que PATROL pueda girarlo hacia su primer waypoint. No se inyecta estado.
	enemy.set_physics_process(false)
	await get_tree().create_timer(1.15).timeout
	enemy.set_physics_process(true)
	await get_tree().physics_frame

	var combat_seen := false
	var approach_seen := false
	var invalid_slot_seen := false
	for tick in range(660):
		await get_tree().physics_frame
		var second := tick / 60
		combat_seen = combat_seen or CombatManager.get_combatant_count() == 1
		approach_seen = approach_seen or enemy.get_debug_state_name() == "APPROACH" or enemy._encounter_debug_state == "READY"
		invalid_slot_seen = invalid_slot_seen or not enemy._debug_combat_slot_valid
		if tick % 60 == 59 or combat_seen:
			var distance := enemy.global_position.distance_to(player.global_position)
			print("6A3D APPROACH %s t=%d state=%s owner=%s encounter=%s dist=%.2f fov=%s los=%s light=%d slot_valid=%s combat_positioning=%s stalled=%s" % [case_name, second + 1, enemy.get_debug_state_name(), enemy.get_debug_ai_owner(), enemy._encounter_debug_state, distance, enemy._debug_fov_str, enemy._debug_los_str, LightingManager.get_light_level_at(player.global_position), enemy._debug_combat_slot_valid, enemy.get_debug_has_combat_positioning(), enemy.get_debug_ai_stalled()])
		if combat_seen:
			break

	var passed := combat_seen and enemy.get_debug_state_name() == "COMBAT" and enemy.get_debug_ai_owner() == "COMBAT" and approach_seen and not invalid_slot_seen and not enemy.get_debug_ai_stalled()
	CombatEncounterManager.reset()
	CombatManager.reset_after_defeat()
	if passed:
		print("Stage6A3D approach runtime %s: PASS" % case_name)
		get_tree().quit()
	else:
		push_error("Stage6A3D approach runtime %s: FAIL" % case_name)
		get_tree().quit(1)
