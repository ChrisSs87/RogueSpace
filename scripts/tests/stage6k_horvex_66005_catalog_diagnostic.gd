extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const NEST := preload("res://resources/run/test_archetypes/HorvexNest.tres")
const PROBE := preload("res://scripts/tests/stage6k_horvex_66005_placement_probe.gd")


func _ready() -> void:
	var choices: Array[Dictionary] = [
		{"definition": &"nest_cross_junction", "side": &"east"},
		{"definition": &"nest_cross_junction", "side": &"north"},
		{"definition": &"nest_cross_junction", "side": &"south"},
		{"definition": &"nest_t_junction", "side": &"east"},
		{"definition": &"nest_t_junction", "side": &"south"},
	]
	var successes: Array[Dictionary] = []
	var failures := 0
	for node0_choice in choices:
		for node2_choice in choices:
			for node3_choice in choices:
				var result := _try_choices({&"NODE_0": node0_choice, &"NODE_2": node2_choice, &"NODE_3": node3_choice})
				if bool(result.success):
					successes.append(result)
				else:
					failures += 1
	print("6K Horvex 66005 catalog probe combinations=%d successes=%d failures=%d" % [choices.size() * choices.size() * choices.size(), successes.size(), failures])
	for success in successes:
		print("6K Horvex 66005 catalog solution=%s definitions=%s stats=%s" % [success.choices, success.definitions, success.stats])
	get_tree().quit(0)


func _try_choices(decisions: Dictionary) -> Dictionary:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	var run: DungeonSectorRun = director.create_sector_run(NEST, 66005)
	var template: DungeonTemplateResource = director.get_sector_template(run, 1)
	var plan: DungeonPlan = director.build_sector_plan(run, 1)
	var probe := PROBE.new()
	add_child(probe)
	probe.current_sector_index = 1
	probe.active_template = template
	probe.current_plan = plan
	probe.forced_junction_choice = decisions
	var assembly: Dictionary = probe._assemble_plan(plan)
	if bool(assembly.get("success", false)):
		var root: Node3D = assembly.get("root", null)
		if root != null and is_instance_valid(root):
			root.free()
	var result := {
		"success": bool(assembly.get("success", false)),
		"choices": decisions.duplicate(true),
		"definitions": probe.get_selected_module_definitions(),
		"stats": probe.placement_stats.duplicate(true),
	}
	remove_child(probe)
	probe.free()
	return result
