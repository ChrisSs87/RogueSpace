extends Node

var errors: Array = []
func check(value: bool, message: String) -> void:
	if not value: errors.append(message)

func _ready() -> void:
	var enemy := Enemy.new()
	enemy.enemy_resource = preload("res://resources/enemies/orco_picaro.tres")
	var profile := preload("res://resources/lighting/VarkhemLighting.tres").duplicate(true) as BiomeLightingProfileResource
	var rows: Array = []
	for exposure in [0.0,1.0,2.0,2.99,3.0,3.01,4.0,6.0,8.0,10.0]:
		profile.ambient = exposure
		LightingManager.configure_biome(profile,self)
		var level := LightingManager.get_detection_light_level_at(Vector3.ZERO)
		var capability := enemy._get_light_detection_capability(level)
		var rounded := LightingManager.get_light_level_at(Vector3.ZERO)
		check(is_equal_approx(level,exposure/2.0),"continuous exposure adapter")
		check(rounded == roundi(exposure/2.0),"integer compatibility adapter unchanged")
		check(is_equal_approx(LightingManager.get_exposure_diagnostic(Vector3.ZERO).detection_level,level),"diagnostic agrees with perception")
		rows.append({"exposure":exposure,"rounded":rounded,"before_capability":enemy.enemy_resource.light_detection_curve[rounded],"after_capability":capability})
	check(is_equal_approx(enemy._get_light_detection_capability(1.5),0.325),"interpolation at ambient3")
	check(absf(enemy._get_light_detection_capability(1.50001)-enemy._get_light_detection_capability(1.49999)) < 0.0001,"no jump around ambient3")
	for resource in [preload("res://resources/enemies/orco_melee.tres"),preload("res://resources/enemies/orco_picaro.tres"),preload("res://resources/enemies/xenomorfo.tres")]:
		enemy.enemy_resource = resource
		for level in 6:
			check(enemy._get_light_detection_capability(float(level)) == resource.light_detection_curve[level],"integer curve samples preserved "+resource.enemy_name)
	LightingManager.configure_biome(null,self)
	for level in 6:
		LightingManager.set_ambient_light_level(level)
		check(LightingManager.get_detection_light_level_at(Vector3.ZERO) == float(level),"legacy exact integer behavior")
	var source := preload("res://scripts/world/LightSource.gd").new()
	source.intensity = 1
	source.position = Vector3(1.25,0,0) # real falloff gives fractional 0.75.
	add_child(source)
	LightingManager.set_ambient_light_level(1)
	check(is_equal_approx(LightingManager.get_exposure_at(Vector3.ZERO),3.5),"fractional legacy fixture actually contributes 0.75")
	check(LightingManager.get_detection_light_level_at(Vector3.ZERO) == float(LightingManager.get_light_level_at(Vector3.ZERO)),"legacy fractional source retains rounding")
	var started := Time.get_ticks_usec()
	for i in 100000: enemy._get_light_detection_capability(1.5)
	print("A4_CURVE="+JSON.stringify({"errors":errors,"rows":rows,"curve_100000_usec":Time.get_ticks_usec()-started,"functional":"PASS" if errors.is_empty() else "FAIL"}))
	enemy.free()
	get_tree().quit(0 if errors.is_empty() else 1)
