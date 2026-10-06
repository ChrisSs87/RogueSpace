extends Resource
class_name WeightedPoolResource
@export var entries: Array[WeightedEntryResource] = []
func choose(rng: RandomNumberGenerator) -> WeightedEntryResource:
	var total := 0.0
	for entry in entries: if entry != null: total += maxf(0.0, entry.weight)
	if total <= 0.0: return null
	var roll := rng.randf_range(0.0, total)
	for entry in entries:
		if entry == null: continue
		roll -= maxf(0.0, entry.weight)
		if roll <= 0.0: return entry
	return entries.back()
