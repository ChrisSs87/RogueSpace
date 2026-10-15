extends "res://scripts/tests/varkhem_v23_lighting_validation.gd"

func _ready() -> void:
	var profile: BiomeLightingProfileResource = preload("res://resources/lighting/VarkhemLighting.tres")
	var variant_id := &"OPERATIVA"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant_id = StringName(arg.trim_prefix("--variant="))
	LightingManager.configure_biome(profile,self)
	var environment: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
	# Process-local fixture, public profile factory, inherited real Player/Enemy
	# and every original exposure/cover/normal-perception assertion retained.
	environment.coherent_light = profile.get_source(&"military_ceiling").create_model(environment.room_light_addition,profile.get_variant(variant_id),0.18)
	await super._ready()
