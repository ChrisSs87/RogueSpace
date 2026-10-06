extends Node3D
const EnemyScene := preload("res://scenes/enemies/Enemy.tscn")
const Carnotauro := preload("res://resources/enemies/orco_melee.tres")
const Def := preload("res://resources/effects/StatusEffectDefinition.gd")
func make_def(id: StringName, op: int, value: int, turns: int, policy: int, tags: Array[StringName]) -> Resource:
	var d = Def.new(); d.effect_id=id; d.turn_start_operation=op; d.magnitude=value; d.base_duration_turns=turns; d.reapply_policy=policy; d.tags=tags; return d
func _ready() -> void:
	var player := $MainFortress6A/Player
	var enemy = EnemyScene.instantiate(); var fixture_resource: EnemyResource = Carnotauro.duplicate() as EnemyResource; fixture_resource.combat_deck=[]; enemy.enemy_resource=fixture_resource; add_child(enemy)
	RunState.reset_run(); CombatManager.reset_after_defeat(); CombatEncounterManager.reset()
	EventBus.combat_ready.emit(player, [enemy])
	var poison = make_def(&"test_poison", Def.TurnOperation.DAMAGE, 2, 2, Def.ReapplyPolicy.REFRESH_DURATION, [&"toxin"])
	var guard = make_def(&"test_guard", Def.TurnOperation.BLOCK, 4, 1, Def.ReapplyPolicy.ADD_STACK, [&"defense"]); guard.max_stacks=2
	var hp0 := RunState.player_health
	RunState.apply_effect(poison)
	CombatManager.end_turn(); var hp1: int = RunState.player_health; var duration1: int = int(RunState.effects.get_effect(&"test_poison").turns_remaining)
	RunState.apply_effect(poison); var refreshed: int = int(RunState.effects.get_effect(&"test_poison").turns_remaining)
	CombatManager.end_turn(); var hp2: int = RunState.player_health; var duration2: int = int(RunState.effects.get_effect(&"test_poison").turns_remaining)
	CombatManager.end_turn(); var hp3 := RunState.player_health
	RunState.apply_effect(guard); CombatManager.end_turn(); var guard_ok := RunState.block == 4 and not RunState.effects.has_effect(&"test_guard")
	RunState.effects.set_resistance(&"toxin", 0.5)
	var resistant_hp: int = RunState.player_health; var resistant_poison = make_def(&"resistant_poison", Def.TurnOperation.DAMAGE, 2, 1, Def.ReapplyPolicy.NO_STACK, [&"toxin"])
	RunState.apply_effect(resistant_poison); CombatManager.end_turn(); var resistance_ok: bool = RunState.player_health == resistant_hp - 1
	RunState.effects.set_resistance(&"toxin", 1.0)
	var combatant = CombatManager._combatants[0]
	var enemy_hp: int = int(combatant.current_health); combatant.apply_effect(poison); CombatManager.end_turn(); var enemy_effect_ok: bool = combatant.current_health == enemy_hp - 2
	var immune = make_def(&"immune_poison", Def.TurnOperation.DAMAGE, 2, 1, Def.ReapplyPolicy.NO_STACK, [&"toxin"])
	RunState.effects.grant_immunity(&"toxin"); var immunity_ok := not RunState.apply_effect(immune)
	var timeline_ok: bool = hp1 == hp0 - 2 and duration1 == 1 and refreshed == 2 and hp2 == hp1 - 2 and duration2 == 1 and hp3 == hp2 - 2 and not RunState.effects.has_effect(&"test_poison")
	print("6C COMBAT timeline | hp %d>%d>%d>%d | duration %d>%d refresh=%d | guard=%s resistance=%s enemy=%s immunity=%s" % [hp0,hp1,hp2,hp3,duration1,duration2,refreshed,guard_ok,resistance_ok,enemy_effect_ok,immunity_ok])
	if timeline_ok and guard_ok and resistance_ok and enemy_effect_ok and immunity_ok: print("Stage6C combat integration: PASS"); get_tree().quit(0)
	else: push_error("Stage6C combat integration: FAIL"); get_tree().quit(1)
