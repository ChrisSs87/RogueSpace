extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const NEST := preload("res://resources/run/test_archetypes/HorvexNest.tres")


func _ready() -> void:
	var invalid := 0
	for seed in range(63001, 63021):
		var director: DungeonArchetypeDirector = DIRECTOR.new()
		var run: DungeonSectorRun = director.create_sector_run(NEST, seed)
		for index in range(run.sector_count()):
			var plan := director.build_sector_plan(run, index)
			if plan == null or not plan.is_valid():
				invalid += 1
				var sectors: Array[String] = []
				for sector in run.sector_definitions: sectors.append(String(sector.sector_id))
				var sequence: Array[String] = []
				var reservations: Array[String] = []
				if plan != null:
					for node_id in plan.module_ids: sequence.append("%s=%s" % [node_id, plan.module_types.get(node_id, &"")])
					for location in plan.semantic_locations: reservations.append("%s@%s" % [location.definition.semantic_id, location.node_id])
				print("6K Horvex invalid seed=%d sectors=%s sector=%s error=%s/%s sequence=[%s] reserved=[%s]" % [seed, ",".join(sectors), run.get_sector(index).sector_id, plan.generation_error if plan != null else "null", plan.semantic_error if plan != null else "null", ", ".join(sequence), ", ".join(reservations)])
	print("6K Horvex diagnostic invalid=%d" % invalid)
	get_tree().quit(0)
