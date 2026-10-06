extends Resource
class_name DungeonTemplateResource
@export var stable_id: StringName
@export var theme_id: StringName
@export var min_modules := 5
@export var max_modules := 8
@export var required_tags: Array[StringName] = [&"START", &"EXIT"]
@export var module_pool: Array[Resource] = []
@export var encounter_pool: Resource
@export var lighting_profile_id: StringName

## Reglas lógicas opcionales. 6F las conserva como datos; 6G interpreta los
## tipos resultantes con su catálogo físico. Los defaults preservan planes
## lineales para templates legacy que no habiliten variedad.
@export var min_turns := 0
@export var max_turns := 1
@export_range(0.0, 1.0, 0.05) var room_chance := 0.0
@export var allow_branches := false
@export_range(0.0, 1.0, 0.05) var branch_chance := 0.0
## Longitud de cada rama lógica: 1 preserva JUNCTION→SIDE_ROOM de 6H;
## valores mayores insertan tránsito branch antes del destino terminal.
@export_range(1, 4) var branch_length := 1
@export var branch_transit_roles: Array[StringName] = [&"CORRIDOR"]
@export var branch_destination_role: StringName = &"SIDE_ROOM"

## Gramática 6H. Si está vacía, RunDirector conserva el comportamiento legacy
## 6G. Las reglas viven en Resources para que un futuro bioma no necesite
## condicionales por nombre dentro del generador.
@export var grammar_rules: Array[DungeonGrammarRuleResource] = []
@export var min_main_path_depth := 0
@export var max_main_path_depth := -1
@export var allow_loops := false # Punto de extensión; 6H no genera loops.
## Reconexiones reales: un tramo de tránsito vuelve desde un junction a otro
## nodo ya existente. Defaults 0 conservan los templates legacy como árboles.
@export_range(0, 4) var min_reconnections := 0
@export_range(0, 4) var max_reconnections := 0
@export_range(1, 8) var min_reconnection_separation := 2
## Contrato físico de una arista RECONNECT. El plan lógico conserva una sola
## arista; el assembler puede materializarla con estos roles auxiliares.
@export_range(1, 8) var max_reconnection_route_segments := 1
@export_range(0, 2) var max_reconnection_route_turns := 0
@export var reconnection_route_roles: Array[StringName] = [&"CORRIDOR"]
@export var forbidden_role_sequences: Array[DungeonRoleSequenceConstraintResource] = []

## Límites del placement-aware mínimo 6H.1. Son datos del template: el
## director conserva la topología y el assembler sólo prueba alternativas
## locales de conectores antes de rechazar una materialización imposible.
@export_range(1, 16) var max_placement_candidates_per_node := 4
@export_range(0, 4) var max_placement_retries := 1
## Límite del search espacial reversible del assembler. Sólo reconsidera
## conectores/variantes de la misma secuencia lógica; nunca altera el plan.
@export_range(0, 4) var max_spatial_backtrack_depth := 2
@export_range(0, 4) var max_plan_generation_retries := 1
## Reintentos de sector exclusivamente ante agotamiento del placement físico.
## El intento 0 usa el seed lógico original; los siguientes usan seeds locales
## derivados de run/sector/retry. Templates legacy conservan un único intento.
@export_range(1, 3) var max_physical_sector_attempts := 1
## Cuando está activo, toda boca de módulo sin seam físico se sella localmente
## antes de B+C. Es un contrato de containment del kit, configurable por
## template para no alterar archetypes que aún no hayan pasado este gate.
@export var enforce_walkable_containment := false

## Metadata de contenido futuro: 6H no la resuelve ni la pasa al assembler.
@export var content_profile_id: StringName
@export var loot_profile_id: StringName
@export var event_profile_id: StringName
@export var environmental_profile_id: StringName
@export var allowed_faction_tags: Array[StringName] = []
@export var special_room_pool: Array[Resource] = []


## Detecta combinaciones imposibles antes de construir un plan. JUNCTION es
## especial: cada junction genera una rama SIDE_ROOM, por lo que consume un
## slot de camino principal y otro de branch.
func validate_cardinality() -> String:
	if grammar_rules.is_empty():
		return ""
	var junction: DungeonGrammarRuleResource = null
	var required_non_junction := 0
	for rule in grammar_rules:
		if rule == null or rule.forbidden or rule.role in [&"START", &"EXIT", &"SIDE_ROOM"]:
			continue
		if rule.role == &"JUNCTION":
			junction = rule
		else:
			required_non_junction += maxi(0, rule.min_count)
	var branch_min := junction.min_count if junction != null else 0
	var branch_max_configured := junction.max_count if junction != null and junction.max_count >= 0 else branch_min
	if min_reconnections > 0 and (junction == null or junction.min_count < min_reconnections * 2):
		return "INVALID TEMPLATE CARDINALITY: reconnections=%d require at least %d JUNCTION nodes" % [min_reconnections, min_reconnections * 2]
	var has_feasible_configuration := false
	var last_error := "INVALID TEMPLATE CARDINALITY: no feasible structural combination"
	for total in range(min_modules, max_modules + 1):
		var max_branches := mini(branch_max_configured, maxi(0, (total - 3) / (branch_length + 1)))
		if max_branches < branch_min:
			last_error = "INVALID TEMPLATE CARDINALITY: total=%d cannot host minimum branches=%d" % [total, branch_min]
			continue
		for branches in range(branch_min, max_branches + 1):
			var main_slots := total - 2 - branches * branch_length
			main_slots = maxi(main_slots, min_main_path_depth)
			if max_main_path_depth >= 0:
				main_slots = mini(main_slots, max_main_path_depth)
			var required := required_non_junction + branches
			if required > main_slots:
				last_error = "INVALID TEMPLATE CARDINALITY: total=%d branches=%d requires=%d main_slots=%d" % [total, branches, required, main_slots]
				continue
			# Necesario (aunque no suficiente): un rol limitado por consecutividad
			# necesita separadores. Detecta configuraciones imposibles sin esperar a
			# que la selección llegue al último slot.
			var sequence_feasible := true
			for rule in grammar_rules:
				if rule == null or rule.forbidden or rule.role in [&"START", &"EXIT", &"SIDE_ROOM", &"JUNCTION"] or rule.max_consecutive < 1:
					continue
				var separators_needed := maxi(0, ceili(float(rule.min_count) / float(rule.max_consecutive)) - 1)
				var separator_capacity := main_slots - rule.min_count
				if separators_needed > separator_capacity:
					last_error = "INVALID TEMPLATE SEQUENCE: role=%s min=%d max_consecutive=%d needs_separators=%d capacity=%d" % [rule.role, rule.min_count, rule.max_consecutive, separators_needed, separator_capacity]
					sequence_feasible = false
					break
			if sequence_feasible:
				has_feasible_configuration = true
	return "" if has_feasible_configuration else last_error
