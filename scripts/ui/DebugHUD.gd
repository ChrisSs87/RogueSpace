extends CanvasLayer

## DebugHUD.gd
## HUD de DESARROLLO exclusivamente para esta sandbox — NO es parte del
## juego final. Muestra:
##   - PLAYER LIGHT / NOISE (bloque propio, arriba de todo — Sección 3 del
##     checkpoint de correcciones: es el dato más importante para probar
##     percepción, así que va aparte y no mezclado con lo demás).
##   - HP, ADN acumulado (cantidad y nivel) por especie y equipamiento, y
##     el equipo actual.
## Los tres botones son atajos de prueba: no reemplazan al flujo real de
## recompensa (RewardManager), solo sirven para no depender de ganar
## combates para ver cómo cambian las estadísticas.
##
## PARA SACARLO DEL PROYECTO: alcanza con poner DebugConfig.debug_hud_enabled
## en false desde el Inspector (autoloads/DebugConfig.tscn) — no hace falta
## borrar ningún nodo ni script. Borrar los archivos sigue siendo una opción
## si en algún momento se quiere sacar del todo.

@onready var player_info_label: Label = $Root/PlayerInfoLabel
@onready var info_label: Label = $Root/InfoLabel
@onready var add_orco_button: Button = $Root/ButtonsContainer/AddOrcoButton
@onready var add_xeno_button: Button = $Root/ButtonsContainer/AddXenoButton
@onready var reset_button: Button = $Root/ButtonsContainer/ResetButton
@onready var perception_button: Button = $Root/ButtonsContainer/PerceptionButton

var _player: Node3D = null


func _ready() -> void:
	if not DebugConfig.debug_hud_enabled:
		queue_free()
		return

	add_orco_button.pressed.connect(_on_add_orco_pressed)
	add_xeno_button.pressed.connect(_on_add_xeno_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	perception_button.pressed.connect(_on_perception_pressed)

	RunState.player_health_changed.connect(_on_state_changed)
	RunState.oxygen_changed.connect(_on_oxygen_state_changed)
	DNAManager.dna_changed.connect(_on_dna_changed)

	_refresh()


## PLAYER LIGHT/NOISE cambian con la posición y el movimiento del jugador
## todo el tiempo, así que esto se recalcula todos los frames — a
## diferencia del resto del HUD (HP/ADN), que solo se actualiza cuando
## cambia de verdad, vía señales.
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			player_info_label.text = "PLAYER\nLIGHT: N/A\nMOVEMENT: N/A\nNOISE RADIUS: N/A\nNOISE INTENSITY: N/A"
			return

	# Mismo valor que usa Perception (Enemy._evaluate_vision) para evaluar
	# al jugador — ninguna fórmula nueva ni duplicada.
	var light_level: int = LightingManager.get_light_level_at(_player.global_position)
	var movement_label: String = "N/A"
	var noise_radius_label: String = "N/A"
	var noise_intensity_label: String = "N/A"
	var speed_label: String = "N/A"
	if _player.has_method("get_movement_state_label"):
		movement_label = _player.get_movement_state_label()
	if _player.has_method("get_current_noise_radius_m"):
		noise_radius_label = "%.1f m" % _player.get_current_noise_radius_m()
	if _player.has_method("get_current_noise_intensity"):
		noise_intensity_label = "%.1f" % _player.get_current_noise_intensity()
	if _player.has_method("get_current_speed_mps"):
		speed_label = "%.2f m/s" % _player.get_current_speed_mps()

	player_info_label.text = "PLAYER\nLIGHT: %d / 5\nMOVEMENT: %s\nACTUAL SPEED: %s\nNOISE RADIUS: %s\nNOISE INTENSITY: %s" % [light_level, movement_label, speed_label, noise_radius_label, noise_intensity_label]


func _on_state_changed(_current: int, _max: int) -> void:
	_refresh()


func _on_oxygen_state_changed(_current: float, _max: float) -> void:
	_refresh()


func _on_dna_changed(_equipment_slot: String, _species_id: String, _new_amount: int) -> void:
	_refresh()


## +1 ADN a los TRES equipamientos a la vez (atajo de prueba, no es la
## mecánica real): así se ve de una el efecto en arma/escudo/traje sin
## tener que clickear tres veces.
func _on_add_orco_pressed() -> void:
	var prototype := get_tree().current_scene
	if prototype != null and prototype.has_method("toggle_content_profile_from_debug"):
		prototype.toggle_content_profile_from_debug()
		_refresh()
		return
	DNAManager.add_dna("weapon", "varkhen", 1)
	DNAManager.add_dna("shield", "varkhen", 1)
	DNAManager.add_dna("suit", "varkhen", 1)


func _on_add_xeno_pressed() -> void:
	var prototype := get_tree().current_scene
	if prototype != null and prototype.has_method("advance_sector_from_debug"):
		prototype.advance_sector_from_debug()
		_refresh()
		return
	DNAManager.add_dna("weapon", "horvex", 1)
	DNAManager.add_dna("shield", "horvex", 1)
	DNAManager.add_dna("suit", "horvex", 1)


func _on_reset_pressed() -> void:
	# En el prototipo 6G el mismo botón de depuración reconstruye sólo la
	# dungeon aislada; no resetea el estado productivo de la run.
	var prototype := get_tree().current_scene
	if prototype != null and prototype.has_method("regenerate_from_debug"):
		prototype.regenerate_from_debug()
		return
	DNAManager.reset()
	RunState.reset_run()
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	get_tree().reload_current_scene()


## DEBUG SIMPLE conserva el HUD normal; este botón alterna sólo el overlay
## técnico de percepción/navegación (conos, anillo, labels de Enemy).
func _on_perception_pressed() -> void:
	# En Stage6G el botón existente alterna exclusivamente los dos templates
	# TEST. Fuera de esa escena conserva el overlay de percepción productivo.
	var prototype := get_tree().current_scene
	if prototype != null and prototype.has_method("toggle_archetype_from_debug") and bool(prototype.get("archetype_mode")):
		prototype.toggle_archetype_from_debug()
		_refresh()
		return
	if prototype != null and prototype.has_method("toggle_template_from_debug"):
		prototype.toggle_template_from_debug()
		return
	DebugConfig.perception_debug_enabled = not DebugConfig.perception_debug_enabled
	perception_button.text = "Percepción: %s" % ("ON" if DebugConfig.perception_debug_enabled else "OFF")


func _refresh() -> void:
	var prototype := get_tree().current_scene
	if prototype != null and prototype.has_method("toggle_archetype_from_debug") and bool(prototype.get("archetype_mode")):
		perception_button.text = "Archetype TEST"
		add_xeno_button.text = "Sector transition"
	elif prototype != null and prototype.has_method("toggle_template_from_debug"):
		perception_button.text = "Template TEST"
	else:
		perception_button.text = "Percepción: %s" % ("ON" if DebugConfig.perception_debug_enabled else "OFF")
	add_orco_button.text = "Profile TEST" if prototype != null and prototype.has_method("toggle_content_profile_from_debug") else "+ ADN Varkhen"
	var weapon_name: String = RunState.equipped_weapon.weapon_name if RunState.equipped_weapon != null else "—"
	var shield_name: String = RunState.equipped_shield.shield_name if RunState.equipped_shield != null else "—"
	var suit_name: String = RunState.equipped_suit.suit_name if RunState.equipped_suit != null else "—"

	var text: String = "[ DEBUG ]\n"
	text += "Vida: %d/%d\n" % [RunState.player_health, RunState.max_player_health]
	text += "O2: %d%%\n" % roundi(RunState.oxygen_current)
	text += "\nO2 DEBUG:\n"
	text += "DISTANCE TRAVELLED: %.1f m\n" % RunState.exploration_distance_travelled_m
	text += "O2 MOVE COST: %.2f\n" % RunState.oxygen_movement_spent
	text += "O2 COMBAT COST: %.2f\n" % RunState.oxygen_combat_spent
	text += "O2 TOTAL SPENT: %.2f\n" % [RunState.oxygen_movement_spent + RunState.oxygen_combat_spent]
	text += "RUN TIME: %.0f s · COMBATS: %d · DEFEATED: %d\n" % [RunState.get_run_time_sec(), RunState.combats_started, RunState.enemies_defeated]
	text += "MOVE TIME S/W/R: %.1f / %.1f / %.1f s\n" % [float(RunState.movement_time_sec["STEALTH"]), float(RunState.movement_time_sec["WALK"]), float(RunState.movement_time_sec["RUN"])]
	text += "Equipo: %s / %s / %s\n" % [weapon_name, shield_name, suit_name]
	text += "\nADN (cantidad / nivel):\n"
	for species_id in ["varkhen", "horvex"]:
		var display_species := "Varkhen" if species_id == "varkhen" else "Horvex"
		text += "%s — Espada %d/%d · Escudo %d/%d · Traje %d/%d\n" % [
			display_species,
			DNAManager.get_dna_amount("weapon", species_id), DNAManager.get_dna_level("weapon", species_id),
			DNAManager.get_dna_amount("shield", species_id), DNAManager.get_dna_level("shield", species_id),
			DNAManager.get_dna_amount("suit", species_id), DNAManager.get_dna_level("suit", species_id),
		]

	info_label.text = text
