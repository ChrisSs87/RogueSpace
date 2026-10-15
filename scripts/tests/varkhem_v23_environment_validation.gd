extends "res://scripts/tests/varkhem_v215_c_environment_validation.gd"

var legacy_lighting := false

func _ready() -> void:
	legacy_lighting = OS.get_cmdline_user_args().has("--lighting-baseline")
	if legacy_lighting:
		# Process-local A/B switch only, never writes a Resource to disk.
		var profile: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
		profile.coherent_light = null
	await super._ready()

func _additional_physical_errors(dungeon: Node3D) -> Array:
	var errors := super._additional_physical_errors(dungeon)
	var modules := dungeon.get_node("AssembledModules")
	var lights := modules.find_children("FixtureLight","SpotLight3D",true,false)
	var report: Dictionary = dungeon.current_room_environment_report
	if lights.size() != (0 if legacy_lighting else report.lit_rooms.size()): errors.append("one coherent source per existing fixture")
	if not legacy_lighting:
		for label in ["SemanticLocationDebug","ContentSlotDebug","SectorTransitionDebug"]:
			var debug_root := dungeon.get_node_or_null(NodePath(label))
			if debug_root == null: continue
			for marker in debug_root.find_children("*","GeometryInstance3D",true,false):
				if marker.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: errors.append("nonphysical debug marker casts false shadow")
	for row in report.get("lighting",[]):
		if row.range_m != 7.0 or row.logical_peak != 3.0 or not row.active: errors.append("effective lighting differs from V23 profile")
	# The inherited physical gate intentionally assembles a Stage script without
	# a Player child; use its physically validated START, not an invented actor.
	var sample_position: Vector3 = dungeon.start_point
	var started := Time.get_ticks_usec()
	for _index in 1000: LightingManager.get_light_level_at(sample_position)
	var elapsed := Time.get_ticks_usec()-started
	print("V23_SECTOR_LIGHT="+JSON.stringify({"seed":dungeon.seed,"sector":dungeon.current_sector_index,
		"lights":lights.size(),"queries_1000_usec":elapsed,"lighting":report.get("lighting",[]),"errors":errors}))
	return errors
