extends Node

## Data/combat regression for 6B. Runtime exploration/encounter remains
## covered by the existing Fortress6A tests; this isolates the new state.
func _ready() -> void:
	var carn: EnemyResource = load("res://resources/enemies/orco_melee.tres")
	var raptor: EnemyResource = load("res://resources/enemies/orco_picaro.tres")
	var horvex: EnemyResource = load("res://resources/enemies/xenomorfo.tres")
	var sting: CardResource = load("res://resources/cards/horvex_sting.tres")
	var failures: Array[String] = []
	if carn.max_health != 40 or carn.opening_block != 6 or carn.species_id != "varkhen": failures.append("Carnotauro")
	if raptor.max_health != 20 or raptor.opening_block != 6 or raptor.species_id != "varkhen": failures.append("Raptor")
	if horvex.max_health != 30 or horvex.can_patrol or not horvex.poison_immune or horvex.species_id != "horvex": failures.append("Horvex")
	if not (raptor.patrol_speed_tier > carn.patrol_speed_tier and raptor.chase_speed_tier > carn.chase_speed_tier and horvex.chase_speed_tier > raptor.chase_speed_tier): failures.append("relaciones velocidad")
	if not (horvex.light_detection_curve[0] > raptor.light_detection_curve[0] and horvex.light_detection_curve[0] > carn.light_detection_curve[0]): failures.append("oscuridad Horvex")
	if sting.action_id != "enemy_poison_attack" or sting.value != 5: failures.append("Aguijón")
	var normal := EnemyCombatant.new(Node3D.new(), carn)
	var immune := EnemyCombatant.new(Node3D.new(), horvex)
	if not normal.apply_poison() or normal.apply_poison() or not normal.poisoned: failures.append("poison no stack")
	normal.apply_damage(2)
	if normal.current_health != carn.max_health - 2: failures.append("poison tick")
	if immune.apply_poison() or immune.poisoned: failures.append("inmunidad Horvex")
	print("6B identities | Carnotauro hp=%d patrol/chase=%d/%d | Raptor=%d/%d | Horvex=%d/%d dark0=%.2f" % [carn.max_health,carn.patrol_speed_tier,carn.chase_speed_tier,raptor.patrol_speed_tier,raptor.chase_speed_tier,horvex.patrol_speed_tier,horvex.chase_speed_tier,horvex.light_detection_curve[0]])
	if failures.is_empty():
		print("Stage6B identity/poison validation: PASS")
		get_tree().quit()
	else:
		push_error("Stage6B identity/poison validation: FAIL %s" % failures)
		get_tree().quit(1)
