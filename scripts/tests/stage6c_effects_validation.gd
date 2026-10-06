extends Node
const Def := preload("res://resources/effects/StatusEffectDefinition.gd")
const EffectContainerScript := preload("res://scripts/effects/StatusEffectContainer.gd")
class Receiver:
	var hp := 20
	var block := 0
	func apply_effect_damage(value: int) -> void: hp -= value
	func add_block(value: int) -> void: block += value
func make_def(id: StringName, op: int, magnitude: int, duration: int, policy: int, tags: Array[StringName]) -> Resource:
	var d = Def.new(); d.effect_id=id; d.turn_start_operation=op; d.magnitude=magnitude; d.base_duration_turns=duration; d.reapply_policy=policy; d.tags=tags; return d
func _ready() -> void:
	var failures: Array[String] = []
	var poison = make_def(&"poison", Def.TurnOperation.DAMAGE, 2, 2, Def.ReapplyPolicy.REFRESH_DURATION, [&"toxin"])
	var shield = make_def(&"guard", Def.TurnOperation.BLOCK, 3, 1, Def.ReapplyPolicy.ADD_STACK, [&"defense"])
	shield.max_stacks = 2
	var effects = EffectContainerScript.new(); var r = Receiver.new()
	if not effects.apply_effect(poison) or not effects.has_effect(&"poison"): failures.append("apply")
	effects.remove_effect(&"poison"); if effects.has_effect(&"poison"): failures.append("remove")
	effects.apply_effect(poison); effects.process_turn_start(r); effects.process_turn_start(r)
	if r.hp != 16 or effects.has_effect(&"poison"): failures.append("duration/poison")
	effects.apply_effect(poison); effects.process_turn_start(r); effects.apply_effect(poison)
	if effects.get_effect(&"poison").turns_remaining != 2: failures.append("refresh")
	effects.clear_combat_effects(); effects.apply_effect(shield); effects.apply_effect(shield); effects.process_turn_start(r)
	if r.block != 6 or effects.has_effect(&"guard"): failures.append("stack/buff")
	effects.grant_immunity(&"toxin"); if effects.apply_effect(poison): failures.append("immunity")
	var resistant = EffectContainerScript.new(); resistant.set_resistance(&"toxin", 0.5); resistant.apply_effect(poison); resistant.process_turn_start(r)
	if r.hp != 13: failures.append("resistance")
	if failures.is_empty(): print("Stage6C effects framework: PASS"); get_tree().quit(0)
	else: push_error("Stage6C effects framework: FAIL %s" % [failures]); get_tree().quit(1)
