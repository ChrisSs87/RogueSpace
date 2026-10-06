extends Node

## Smoke-only coverage for the mobile comparison scene. It exercises the same
## public callbacks used by the debug buttons without altering generation data.
const EXPERIENCE_SCENE := preload("res://scenes/tests/Stage6KArchetypeExperienceTest.tscn")


func _ready() -> void:
	var experience := EXPERIENCE_SCENE.instantiate()
	add_child(experience)
	while not experience.nav_ready:
		await get_tree().physics_frame
	var failures: Array[String] = []
	for config in [
		{"name": "SHIP", "index": 0, "seed": 67001},
		{"name": "VARKHEM", "index": 1, "seed": 65001},
		{"name": "HORVEX", "index": 2, "seed": 66011},
	]:
		experience.test_archetype_index = int(config.index)
		await experience.regenerate(int(config.seed))
		if not _valid_runtime(experience):
			failures.append("%s initial" % config.name)
			continue
		var initial_seed: int = experience.seed
		await experience.regenerate_from_debug()
		if not _valid_runtime(experience) or experience.seed == initial_seed:
			failures.append("%s new_seed" % config.name)
		if experience.sector_run != null and experience.current_sector_index < experience.sector_run.sector_count() - 1:
			await experience.advance_sector_from_debug()
			if not _valid_runtime(experience):
				failures.append("%s next_sector" % config.name)
	print("6K.4 FINAL experience smoke failures=%s" % str(failures))
	experience.queue_free()
	get_tree().quit(0 if failures.is_empty() else 1)


func _valid_runtime(experience: Node) -> bool:
	var player := experience.get_node_or_null("Player") as CharacterBody3D
	return experience.assembly_valid and experience.nav_ready and player != null and experience.get_runtime_counts().regions == 1
