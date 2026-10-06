extends Resource
class_name ValueModifierResource

enum ValueKind { DAMAGE, BLOCK }
enum Operation { FLAT, PERCENT }

@export var value_kind: ValueKind = ValueKind.DAMAGE
@export var operation: Operation = Operation.FLAT
@export var amount: float = 0.0
@export var required_card_tags: Array[StringName] = []

func applies_to(kind: ValueKind, card_tags: Array[StringName]) -> bool:
	if value_kind != kind:
		return false
	for tag in required_card_tags:
		if not card_tags.has(tag):
			return false
	return true
