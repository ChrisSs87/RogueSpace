extends RefCounted
class_name CharacterStats

## Contenedor pequeño y extensible. Nuevos stats son IDs de datos, no campos
## nuevos en CombatManager/CardValueResolver.
var base_values: Dictionary = {&"damage": 0, &"block": 0}

func set_base(stat_id: StringName, value: int) -> void:
	base_values[stat_id] = value

func get_value(stat_id: StringName) -> int:
	return int(base_values.get(stat_id, 0))
