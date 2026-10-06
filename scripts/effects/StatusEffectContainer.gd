extends RefCounted
class_name StatusEffectContainer
const EffectInstanceScript := preload("res://scripts/effects/StatusEffectInstance.gd")
const EffectDefinitionScript := preload("res://resources/effects/StatusEffectDefinition.gd")
var effects: Dictionary = {}
var immune_tags: Dictionary = {}
var resistance_by_tag: Dictionary = {}
func grant_immunity(tag: StringName) -> void: immune_tags[tag] = true
func set_resistance(tag: StringName, multiplier: float) -> void: resistance_by_tag[tag] = clampf(multiplier, 0.0, 1.0)
func apply_effect(def: Resource, source: Variant = null) -> bool:
	if def == null or effects.has(def.effect_id) and def.reapply_policy == EffectDefinitionScript.ReapplyPolicy.NO_STACK: return false
	for tag in def.tags: if immune_tags.has(tag): return false
	if effects.has(def.effect_id):
		var instance = effects[def.effect_id]
		if def.reapply_policy == EffectDefinitionScript.ReapplyPolicy.ADD_STACK: instance.stacks = mini(instance.stacks + 1, def.max_stacks)
		if def.reapply_policy == EffectDefinitionScript.ReapplyPolicy.REFRESH_DURATION: instance.turns_remaining = def.base_duration_turns
		return true
	effects[def.effect_id] = EffectInstanceScript.new(def, source); return true
func remove_effect(id: StringName) -> void: effects.erase(id)
func has_effect(id: StringName) -> bool: return effects.has(id)
func get_effect(id: StringName): return effects.get(id)
func process_turn_start(receiver: Object) -> void:
	for id in effects.keys().duplicate():
		var instance = effects[id]
		var magnitude: int = int(instance.definition.magnitude) * int(instance.stacks)
		for tag in instance.definition.tags: magnitude = roundi(magnitude * float(resistance_by_tag.get(tag, 1.0)))
		if instance.definition.turn_start_operation == EffectDefinitionScript.TurnOperation.DAMAGE and receiver.has_method("apply_effect_damage"): receiver.apply_effect_damage(magnitude)
		elif instance.definition.turn_start_operation == EffectDefinitionScript.TurnOperation.BLOCK and receiver.has_method("add_block"): receiver.add_block(magnitude)
		instance.turns_remaining -= 1
		if instance.turns_remaining <= 0: effects.erase(id)
func clear_combat_effects() -> void: effects.clear()
