extends RefCounted
class_name CardValueResolver

const ModifierDef := preload("res://resources/equipment/ValueModifierResource.gd")

static func get_resolved_card_values(card: CardResource, state: Node = RunState) -> Dictionary:
	return {
		"damage": _resolve(card, ModifierDef.ValueKind.DAMAGE, state),
		"block": _resolve(card, ModifierDef.ValueKind.BLOCK, state),
	}

static func _resolve(card: CardResource, kind: int, state: Node) -> int:
	var value := float(card.damage_amount if kind == ModifierDef.ValueKind.DAMAGE else card.block_amount)
	# Character stat is an explicit input. Existing basic cards can opt in to
	# the legacy equipped weapon/shield stat without changing their Resource.
	if kind == ModifierDef.ValueKind.DAMAGE and card.derive_damage_from_weapon:
		value += state.get_damage_card_stat()
	if kind == ModifierDef.ValueKind.BLOCK and card.derive_block_from_shield:
		value += state.get_block_card_stat()
	for artifact in state.get_active_artifacts():
		value = _apply_modifiers(value, artifact.modifiers, kind, card.tags)
	var loadout: LoadoutResource = state.equipped_loadout
	if loadout != null and loadout.primary_weapon != null:
		value = _apply_modifiers(value, loadout.primary_weapon.modifiers, kind, card.tags)
	if loadout != null and loadout.secondary_weapon != null and (loadout.primary_weapon == null or loadout.primary_weapon.allows_secondary):
		value = _apply_modifiers(value, loadout.secondary_weapon.modifiers, kind, card.tags)
	return maxi(0, roundi(value))

static func _apply_modifiers(value: float, modifiers: Array, kind: int, tags: Array[StringName]) -> float:
	for modifier in modifiers:
		if modifier != null and modifier.applies_to(kind, tags):
			if modifier.operation == ModifierDef.Operation.FLAT: value += modifier.amount
			else: value *= 1.0 + modifier.amount
	return value
