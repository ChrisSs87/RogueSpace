extends RefCounted
class_name StatusEffectInstance
var definition: Resource
var stacks := 1
var turns_remaining := 0
var source: Variant
func _init(def: Resource, effect_source: Variant = null) -> void:
	definition = def; source = effect_source; turns_remaining = def.base_duration_turns
