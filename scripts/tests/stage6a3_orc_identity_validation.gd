extends Node

func _ready() -> void:
	var melee: EnemyResource = load("res://resources/enemies/orco_melee.tres")
	var rogue: EnemyResource = load("res://resources/enemies/orco_picaro.tres")
	var failures: Array[String] = []
	var melee_actions: Dictionary = {}
	var rogue_actions: Dictionary = {}
	for i in range(120):
		var m := EnemyCombatant.new(null, melee)
		m.current_health -= 4
		m.choose_intention()
		melee_actions[m.intention.card_name] = true
		var r := EnemyCombatant.new(null, rogue)
		r.choose_intention()
		rogue_actions[r.intention.card_name] = true
	print("ORC IDENTITY | melee hp %d actions %s | rogue hp %d actions %s" % [melee.max_health, melee_actions.keys(), rogue.max_health, rogue_actions.keys()])
	if melee.max_health != 40 or not melee_actions.has("Golpe de Hacha") or not melee_actions.has("Defensa") or not melee_actions.has("Mordisco") or not melee_actions.has("Regeneración"):
		failures.append("kit Melee incompleto")
	if rogue.max_health != 20 or not rogue_actions.has("Arañazo") or not rogue_actions.has("Mordisco") or not rogue_actions.has("Defensa"):
		failures.append("kit Rogue incompleto")
	if failures.is_empty():
		print("Stage6A3 orc identity validation: PASS")
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)
