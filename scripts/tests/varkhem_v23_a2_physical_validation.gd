extends "res://scripts/tests/varkhem_v215_c_environment_validation.gd"

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--a-baseline"):
		var environment: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
		environment.biome_lighting = null # Process-local A baseline; never writes disk.
	await super._ready()
