extends "res://scripts/tests/a3_staged_audit.gd"

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--visual-baseline"):
		var environment: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
		environment.visual_style = null
	await super._ready()
