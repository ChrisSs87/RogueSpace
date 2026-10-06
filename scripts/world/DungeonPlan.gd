extends RefCounted
class_name DungeonPlan
var seed := 0
var module_ids: Array[StringName] = []
var links: Dictionary = {}
# El plan describe semántica, no transforms físicos. El assembler 6G decide
# cómo alinear los conectores de un módulo que represente cada tipo.
var module_types: Dictionary = {}
# Datos consultables por placement futuro: no se infieren desde la geometría.
var main_path_nodes: Dictionary = {}
var branch_nodes: Dictionary = {}
# Tramos de circulación que vuelven a conectar dos nodos existentes. No son
# ramas terminales: conservan el mismo DungeonPlan como fuente de verdad.
var reconnection_nodes: Dictionary = {}
var reconnections: Array[Dictionary] = []
var module_definitions: Dictionary = {}
var module_definition_variants: Dictionary = {}
var assembly_transforms: Dictionary = {}
var generation_error := ""
var node_depths: Dictionary = {}
var semantic_locations: Array[DungeonSemanticLocation] = []
var semantic_error := ""
## Telemetría determinista de candidatos REQUIRED evaluados físicamente.
## No forma parte de la topología ni modifica las reglas de generación.
var semantic_feasibility: Array[Dictionary] = []
## Clasificación del probe REQUIRED. Distingue un candidato semántico malo de
## un sector que ya agotó placement sin aplicar la semantic requerida.
var required_feasibility_status: StringName = &""
var required_feasibility_error := ""


## Copia aislada para consultas de assembly. Conserva la misma estructura y
## Resources, pero no comparte diccionarios mutables de placement/transforms
## con el plan que terminará persistiendo en la run.
func duplicate_for_assembly_probe() -> DungeonPlan:
	var copy := DungeonPlan.new()
	copy.seed = seed
	copy.module_ids = module_ids.duplicate()
	copy.links = links.duplicate(true)
	copy.module_types = module_types.duplicate()
	copy.main_path_nodes = main_path_nodes.duplicate()
	copy.branch_nodes = branch_nodes.duplicate()
	copy.reconnection_nodes = reconnection_nodes.duplicate()
	copy.reconnections = reconnections.duplicate(true)
	copy.module_definitions = module_definitions.duplicate()
	copy.module_definition_variants = module_definition_variants.duplicate(true)
	copy.assembly_transforms = assembly_transforms.duplicate(true)
	copy.generation_error = generation_error
	copy.node_depths = node_depths.duplicate()
	copy.semantic_locations = semantic_locations.duplicate()
	copy.semantic_error = semantic_error
	copy.semantic_feasibility = semantic_feasibility.duplicate(true)
	copy.required_feasibility_status = required_feasibility_status
	copy.required_feasibility_error = required_feasibility_error
	return copy


## Firma estructural: deliberadamente ignora seed, transforms y dimensiones.
## Permite distinguir topologías/familias reales de simples variaciones de
## longitud o escala que pertenezcan al mismo recorrido lógico.
func get_topology_signature() -> String:
	if not module_ids.has(&"START"):
		return "INVALID"
	return _topology_signature_from(&"START", {})


func _topology_signature_from(node_id: StringName, visiting: Dictionary) -> String:
	if visiting.has(node_id):
		return "CYCLE"
	var next_visiting := visiting.duplicate()
	next_visiting[node_id] = true
	var children: Array[String] = []
	for child_id in links.get(node_id, []):
		children.append(_topology_signature_from(child_id, next_visiting))
	children.sort()
	var node_type: StringName = module_types.get(node_id, &"GENERIC")
	return "%s[%s]" % [node_type, ",".join(children)]
func is_valid() -> bool:
	if not generation_error.is_empty() or not semantic_error.is_empty(): return false
	if module_ids.count(&"START") != 1 or not module_ids.has(&"EXIT"): return false
	var seen := {&"START":true}; var queue: Array[StringName]=[&"START"]
	while not queue.is_empty():
		var current=queue.pop_front()
		for next in links.get(current, []): if not seen.has(next): seen[next]=true; queue.append(next)
	return seen.has(&"EXIT") and seen.size()==module_ids.size()


func calculate_depths() -> void:
	node_depths.clear()
	if not module_ids.has(&"START"):
		return
	var queue: Array[StringName] = [&"START"]
	node_depths[&"START"] = 0
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for child_variant in links.get(current, []):
			var child: StringName = child_variant
			if not node_depths.has(child):
				node_depths[child] = int(node_depths[current]) + 1
				queue.append(child)


func get_nodes_by_role(role: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in module_ids:
		if module_types.get(id, &"") == role:
			result.append(id)
	return result


func get_branch_node_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in module_ids:
		if branch_nodes.has(id):
			result.append(id)
	return result


func get_reconnection_node_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in module_ids:
		if reconnection_nodes.has(id):
			result.append(id)
	return result


## Adyacencia física/topológica no dirigida. Los links conservan dirección de
## recorrido para compatibilidad, pero una reconexión se evalúa como circuito
## de circulación bidireccional para métricas y validación de diseño.
func get_undirected_adjacency() -> Dictionary:
	var adjacency: Dictionary = {}
	for id in module_ids:
		adjacency[id] = []
	for source_variant in links:
		var source: StringName = source_variant
		for target_variant in links[source]:
			var target: StringName = target_variant
			if not adjacency.has(source): adjacency[source] = []
			if not adjacency.has(target): adjacency[target] = []
			if not adjacency[source].has(target): adjacency[source].append(target)
			if not adjacency[target].has(source): adjacency[target].append(source)
	return adjacency


func get_undirected_edge_count() -> int:
	var count := 0
	for source_variant in links:
		count += (links[source_variant] as Array).size()
	return count


## Número de circuitos independientes de un grafo conectado: E - V + 1.
## Una rama terminal no aumenta E-V+1; una reconexión real sí.
func get_independent_circuit_count() -> int:
	if module_ids.is_empty(): return 0
	return maxi(0, get_undirected_edge_count() - module_ids.size() + 1)


func shortest_path_length(from_id: StringName, to_id: StringName, blocked_edges: Dictionary = {}) -> int:
	if not module_ids.has(from_id) or not module_ids.has(to_id): return -1
	var adjacency := get_undirected_adjacency()
	var queue: Array[StringName] = [from_id]
	var distance: Dictionary = {from_id: 0}
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		if current == to_id: return int(distance[current])
		for next_variant in adjacency.get(current, []):
			var next: StringName = next_variant
			var edge_key := _undirected_edge_key(current, next)
			if blocked_edges.has(edge_key) or distance.has(next): continue
			distance[next] = int(distance[current]) + 1
			queue.append(next)
	return -1


## Hay dos rutas si ninguna arista individual de una ruta corta la conexión.
## Es suficiente y determinista para medir circuitos de circulación de 6K.4A.
func has_alternative_route(from_id: StringName, to_id: StringName) -> bool:
	var adjacency := get_undirected_adjacency()
	if not adjacency.has(from_id) or not adjacency.has(to_id): return false
	var queue: Array[StringName] = [from_id]
	var parent: Dictionary = {from_id: &""}
	while not queue.is_empty() and not parent.has(to_id):
		var current: StringName = queue.pop_front()
		for next_variant in adjacency.get(current, []):
			var next: StringName = next_variant
			if parent.has(next): continue
			parent[next] = current
			queue.append(next)
	if not parent.has(to_id): return false
	var cursor: StringName = to_id
	while cursor != from_id:
		var previous: StringName = parent[cursor]
		if shortest_path_length(from_id, to_id, {_undirected_edge_key(previous, cursor): true}) >= 0:
			return true
		cursor = previous
	return false


func _undirected_edge_key(a: StringName, b: StringName) -> StringName:
	return StringName("%s<->%s" % [a, b]) if String(a) < String(b) else StringName("%s<->%s" % [b, a])
