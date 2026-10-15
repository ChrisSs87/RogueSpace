extends "res://scripts/tests/a3_p2ce_reference.gd"

func _ready() -> void:
	var environment: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
	var profile: BiomeLightingProfileResource = preload("res://resources/lighting/VarkhemLighting.tres")
	for arg in OS.get_cmdline_user_args():
		if arg == "--a-baseline": environment.biome_lighting = null
		if arg.begins_with("--variant="): profile.default_variant = StringName(arg.trim_prefix("--variant="))
	await super._ready()
