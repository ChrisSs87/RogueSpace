extends RefCounted
class_name ContentPlacementPlan

var seed := 0
var profile_id: StringName
var all_slots: Array[DungeonContentSlot] = []
var selected_slots: Array[DungeonContentSlot] = []
var generation_error := ""

func is_valid() -> bool:
	if not generation_error.is_empty():
		return false
	var seen: Dictionary = {}
	for slot in selected_slots:
		if slot == null or seen.has(slot.unique_id):
			return false
		seen[slot.unique_id] = true
	return true

func get_signature() -> String:
	var parts: Array[String] = []
	for slot in selected_slots:
		parts.append("%s:%s" % [slot.unique_id, slot.category])
	parts.sort()
	return "|".join(parts)
