extends Node

## DNAManager.gd (autoload)
## ADN acumulado, separado por equipamiento (arma/escudo/traje) Y por
## especie — nunca se mezclan entre sí (Sección 3 de la spec: "el ADN
## aplicado al arma no debe modificar el escudo ni el traje").
##
## 1 ADN = 1 nivel de ADN por ahora (dna_per_level). Es deliberadamente
## así de simple para esta demo corta; cuando haga falta cambiar a "5 ADN =
## 1 nivel" alcanza con cambiar ese único número, nada más se reescribe.
##
## Los efectos numéricos por especie viven en DNASpeciesResource (ver
## species_resources) — este script no tiene ningún "if especie == orco".
##
## También trackea qué HABILIDADES (cartas especiales) ya se desbloquearon,
## para que una misma habilidad nunca genere dos cartas (Sección 12 de la
## spec original de ADN: "cada habilidad desbloqueada genera como máximo
## una carta").

signal dna_changed(equipment_slot: String, species_id: String, new_amount: int)

const EQUIPMENT_SLOTS: Array[String] = ["weapon", "shield", "suit"]

@export var dna_per_level: int = 1

## Un DNASpeciesResource por especie soportada esta demo (Orco, Xenomorfo).
@export var species_resources: Array[DNASpeciesResource] = []

# dna[equipment_slot][species_id] = cantidad acumulada
var dna: Dictionary = {}

# unlocked_abilities["slot:species:nivel"] = true una vez desbloqueada.
# Independiente de si el jugador la incorporó al mazo o no — "desbloqueada"
# y "equipada" son cosas distintas (Sección 5 de la spec de esta etapa).
var unlocked_abilities: Dictionary = {}


func _ready() -> void:
	reset()


## Reinicio completo del ADN acumulado y de las habilidades desbloqueadas.
## El ADN es temporal por run (se pierde al morir/reiniciar la prueba) —
## ver CombatUI._on_restart_pressed() y DebugHUD._on_reset_pressed().
func reset() -> void:
	dna = {}
	for slot in EQUIPMENT_SLOTS:
		dna[slot] = {}
		for species_resource in species_resources:
			if species_resource != null and species_resource.species_id != "":
				dna[slot][species_resource.species_id] = 0
	unlocked_abilities = {}


func add_dna(equipment_slot: String, species_id: String, amount: int = 1) -> void:
	if amount <= 0 or species_id == "" or not EQUIPMENT_SLOTS.has(equipment_slot):
		return
	if not dna.has(equipment_slot):
		dna[equipment_slot] = {}
	var current: int = dna[equipment_slot].get(species_id, 0)
	var new_amount: int = current + amount
	dna[equipment_slot][species_id] = new_amount
	dna_changed.emit(equipment_slot, species_id, new_amount)


func get_dna_amount(equipment_slot: String, species_id: String) -> int:
	if not dna.has(equipment_slot):
		return 0
	return dna[equipment_slot].get(species_id, 0)


func get_dna_level(equipment_slot: String, species_id: String) -> int:
	var species := _get_species_resource(species_id)
	var units := species.units_per_level if species != null else dna_per_level
	return get_dna_amount(equipment_slot, species_id) / maxi(1, units)

func get_stat_bonus(equipment_slot: String, value_kind: int) -> int:
	var total := 0
	if not dna.has(equipment_slot):
		return total
	for species_id in dna[equipment_slot].keys():
		var species := _get_species_resource(species_id)
		if species == null:
			continue
		var level := get_dna_level(equipment_slot, species_id)
		for modifier in species.stat_modifiers:
			if modifier != null and modifier.value_kind == value_kind and modifier.operation == ValueModifierResource.Operation.FLAT:
				total += roundi(modifier.amount * level)
	return total


func _get_species_resource(species_id: String) -> DNASpeciesResource:
	for species_resource in species_resources:
		if species_resource != null and species_resource.species_id == species_id:
			return species_resource
	return null


## Bonus TOTAL de daño de Golpe Básico, sumando todas las especies que
## tengan ADN puesto en el arma (por ahora solo Orco aporta acá; el efecto
## de Xenomorfo en el arma es Veneno, Checkpoint D).
func get_weapon_damage_bonus() -> int:
	return _sum_bonus("weapon", "weapon_damage_per_level")


## Bonus TOTAL de bloqueo de Defensa Básica (Orco Y Xenomorfo aportan acá).
func get_shield_block_bonus() -> int:
	return _sum_bonus("shield", "shield_block_per_level")


## Bonus TOTAL de HP máximo aportado por el traje (Orco Y Xenomorfo aportan acá).
func get_suit_max_health_bonus() -> int:
	return _sum_bonus("suit", "suit_max_health_per_level")


func _sum_bonus(equipment_slot: String, per_level_field: String) -> int:
	var total: int = 0
	if not dna.has(equipment_slot):
		return total
	for species_id in dna[equipment_slot].keys():
		var level: int = get_dna_level(equipment_slot, species_id)
		if level <= 0:
			continue
		var species_resource: DNASpeciesResource = _get_species_resource(species_id)
		if species_resource != null:
			total += level * species_resource.get(per_level_field)
	return total


## Se llama justo después de aplicar 1 ADN (ver RewardManager.choose_dna_slot).
## Si el nivel actual llegó a 3 o 5 y esa especie/equipamiento tiene una
## carta definida para ese nivel, Y todavía no se había desbloqueado antes,
## la devuelve (y la marca como desbloqueada). Si no hay nada nuevo que
## desbloquear, devuelve null.
func check_and_unlock(equipment_slot: String, species_id: String) -> CardResource:
	var species_resource: DNASpeciesResource = _get_species_resource(species_id)
	if species_resource == null:
		return null

	var level: int = get_dna_level(equipment_slot, species_id)
	var tier: int = 0
	var card: CardResource = null

	if level >= 5:
		tier = 5
		card = species_resource.get("%s_level_5_card" % equipment_slot)
	elif level >= 3:
		tier = 3
		card = species_resource.get("%s_level_3_card" % equipment_slot)

	if card == null:
		return null

	var key: String = "%s:%s:%d" % [equipment_slot, species_id, tier]
	if unlocked_abilities.get(key, false):
		return null  # ya se había desbloqueado antes, no se repite

	unlocked_abilities[key] = true
	return card
