extends "res://scripts/tests/varkhem_v214_combat_suspension_validation.gd"

var observed_combat_ticks := 0
var observed_reward_ticks := 0
var observed_exploration_ticks := 0
var maximum_debug_layers := 0
var duplicate_observer_connections := false

func _physics_process(_delta: float) -> void:
	for child in get_children():
		if not child.has_node("Inspection"): continue
		var inspection := child.get_node("Inspection")
		if not inspection.infiltration: inspection._toggle_infiltration()
		var layers := 0
		for node in child.get_children():
			if node is CanvasLayer and node.has_node("Stage6GDebug"): layers += 1
		maximum_debug_layers = maxi(maximum_debug_layers,layers)
		var observer_connections := 0
		for connection in EventBus.get_signal_connection_list("player_noise_emitted"):
			if connection.callable.get_object() == inspection: observer_connections += 1
		if observer_connections != 1: duplicate_observer_connections = true
		if CombatManager.get_combatant_count() > 0: observed_combat_ticks += 1
		elif RewardManager.is_reward_active(): observed_reward_ticks += 1
		elif child.nav_ready and not ExplorationState.is_suspended(): observed_exploration_ticks += 1

func _ready() -> void:
	# Reuse every original assertion and public card/reward/reset flow.
	await super._ready()
	if observed_combat_ticks == 0 or observed_reward_ticks == 0 or observed_exploration_ticks == 0:
		errors.append("debug fixture did not observe combat/reward/exploration")
	if maximum_debug_layers != 1: errors.append("debug layer duplicated across combat/reset")
	if duplicate_observer_connections: errors.append("noise observer connection duplicated")
	print("P3B1_COMBAT_RESULT="+JSON.stringify({"valid":errors.is_empty(),"errors":errors,"combat_ticks":observed_combat_ticks,"reward_ticks":observed_reward_ticks,"exploration_ticks":observed_exploration_ticks,"maximum_debug_layers":maximum_debug_layers,"duplicate_observer_connections":duplicate_observer_connections}))
	get_tree().quit(0 if errors.is_empty() else 1)
