extends RefCounted
class_name RunDirector
var graph: RunGraphResource
var seed := 0
var current_node_id: StringName
var visited: Dictionary = {}
var completed: Dictionary = {}
var rng := RandomNumberGenerator.new()
func start(run_graph: RunGraphResource, run_seed: int) -> void:
	graph=run_graph; seed=run_seed; rng.seed=seed; current_node_id=graph.start_node_id; visited={current_node_id:true}; completed={}
func available_nodes() -> Array[RunNodeResource]:
	var result:Array[RunNodeResource]=[]; var current=graph.get_node(current_node_id)
	if current == null: return result
	for id in current.next_node_ids:
		var node=graph.get_node(id)
		if node != null and not completed.has(id): result.append(node)
	return result
func select_node(id: StringName) -> Dictionary:
	for node in available_nodes():
		if node.node_id==id: current_node_id=id; visited[id]=true; return launch(node)
	return {}
func complete_current() -> Dictionary:
	completed[current_node_id]=true
	var node=graph.get_node(current_node_id)
	return {"completed":current_node_id, "reward":node.dungeon.reward_id if node != null and node.dungeon != null else &""}
func launch(node: RunNodeResource) -> Dictionary:
	if node.dungeon == null: return {"kind":"placeholder"}
	var definition: DungeonDefinitionResource=node.dungeon
	if definition.generation_mode==DungeonDefinitionResource.GenerationMode.FIXED: return {"kind":"fixed","scene":definition.fixed_scene}
	return {"kind":"plan","plan":build_plan(definition.template)}
func build_plan(template: DungeonTemplateResource) -> DungeonPlan:
	var cardinality_error := template.validate_cardinality()
	if not cardinality_error.is_empty():
		var invalid := DungeonPlan.new()
		invalid.generation_error = cardinality_error
		return invalid
	if not template.grammar_rules.is_empty():
		# Un template puede descartar una secuencia al aplicar restricciones de
		# transición. Reintentar una vez con RNG derivado del mismo seed evita
		# aceptar un plan parcial sin convertir el director en un solver.
		for attempt in range(template.max_plan_generation_retries + 1):
			var candidate := _build_grammar_plan(template, attempt)
			if candidate.is_valid():
				return candidate
		return _build_grammar_plan(template, template.max_plan_generation_retries)
	var local_rng:=RandomNumberGenerator.new(); local_rng.seed=seed + int(current_node_id.hash())
	var plan:=DungeonPlan.new(); plan.seed=local_rng.seed; var count:=local_rng.randi_range(template.min_modules,template.max_modules)
	plan.module_ids=[&"START"]
	plan.module_types[&"START"]=&"START"
	# El plan lógico selecciona familias topológicas, sin conocer transforms
	# físicos. El assembler 6G decide cómo materializar cada tipo mediante
	# conectores. Los límites vienen del Template y no de nombres de bioma.
	var interior_count:=maxi(0,count-2)
	var requested_turns:=local_rng.randi_range(template.min_turns, template.max_turns) if interior_count>0 else 0
	var turn_count:=clampi(requested_turns, 0, interior_count)
	var turn_indices: Dictionary = {}
	while turn_indices.size() < turn_count:
		turn_indices[local_rng.randi_range(0, interior_count - 1)] = true
	var branch_index: int = -1
	if template.allow_branches and interior_count >= 2 and local_rng.randf() < template.branch_chance:
		branch_index = local_rng.randi_range(0, interior_count - 1)
	var previous_id: StringName = &"START"
	for i in range(interior_count):
		var id:=StringName("ROOM_%d"%i)
		plan.module_ids.append(id)
		var kind: StringName = &"ROOM" if local_rng.randf() < template.room_chance else &"STRAIGHT"
		if turn_indices.has(i):
			kind = &"TURN_LEFT" if local_rng.randi_range(0, 1) == 0 else &"TURN_RIGHT"
		if i == branch_index:
			kind = &"JUNCTION"
		plan.module_types[id] = kind
		plan.links[previous_id] = [id]
		previous_id = id
	var exit_id: StringName = &"EXIT"
	plan.module_ids.append(exit_id)
	plan.module_types[exit_id]=&"EXIT"
	plan.links[previous_id] = [exit_id]
	if branch_index >= 0:
		var junction_id: StringName = StringName("ROOM_%d" % branch_index)
		var side_id: StringName = &"SIDE_ROOM"
		plan.module_ids.append(side_id)
		plan.module_types[side_id] = &"SIDE_ROOM"
		var junction_links: Array = plan.links.get(junction_id, []).duplicate()
		junction_links.append(side_id)
		plan.links[junction_id] = junction_links
	return plan


func _build_grammar_plan(template: DungeonTemplateResource, generation_attempt := 0) -> DungeonPlan:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed + int(current_node_id.hash()) + generation_attempt * 104729
	var plan := DungeonPlan.new()
	plan.seed = local_rng.seed
	var total_modules := local_rng.randi_range(template.min_modules, template.max_modules)
	var junction_rule := _grammar_rule(template, &"JUNCTION")
	var side_rule := _grammar_rule(template, &"SIDE_ROOM")
	var uses_distribution_rules := not template.branch_rules.is_empty()
	var branch_count := 0
	var distribution_destination_budget := 0
	var required_junctions := 0
	var main_interior := 0
	if uses_distribution_rules:
		distribution_destination_budget = _choose_distribution_destination_budget(template, total_modules, local_rng)
		if distribution_destination_budget < 0:
			plan.generation_error = "No feasible module budget for configured distribution rules"
			return plan
		main_interior = total_modules - 2 - distribution_destination_budget
		if main_interior < template.min_main_path_depth or (template.max_main_path_depth >= 0 and main_interior > template.max_main_path_depth):
			plan.generation_error = "Distribution budget cannot satisfy main-path depth"
			return plan
		if junction_rule != null and not junction_rule.forbidden:
			var junction_min := junction_rule.min_count
			var junction_max := junction_rule.max_count if junction_rule.max_count >= 0 else junction_min
			junction_min = maxi(junction_min, _minimum_junctions_for_main_capacity(template, main_interior))
			if junction_min > junction_max:
				plan.generation_error = "Distribution main path exceeds configured transit-role capacity"
				return plan
			required_junctions = local_rng.randi_range(junction_min, junction_max) if junction_max > junction_min else junction_min
	else:
		var min_branches := junction_rule.min_count if junction_rule != null and not junction_rule.forbidden else 0
		var max_branches := junction_rule.max_count if junction_rule != null and junction_rule.max_count >= 0 else 0
		max_branches = mini(max_branches, maxi(0, (total_modules - 3) / (template.branch_length + 1)))
		branch_count = local_rng.randi_range(min_branches, max_branches) if max_branches >= min_branches else min_branches
		main_interior = total_modules - 2 - branch_count * template.branch_length
		main_interior = maxi(main_interior, template.min_main_path_depth)
		if template.max_main_path_depth >= 0:
			main_interior = mini(main_interior, template.max_main_path_depth)
		# Una rama ocupa un SIDE_ROOM además del JUNCTION; si el límite de profundidad
		# ajustó el camino, volver a derivar el total real de módulos es intencional.
		branch_count = mini(branch_count, maxi(0, main_interior - 1))
		required_junctions = branch_count
	plan.module_ids = [&"START"]
	plan.module_types[&"START"] = &"START"
	plan.main_path_nodes[&"START"] = true
	plan.module_definitions[&"START"] = _find_module_definition(template, &"START")
	plan.module_definition_variants[&"START"] = _find_module_variants(template, &"START")
	var counts: Dictionary = {&"JUNCTION": 0}
	var previous_role := &""
	var previous_run := 0
	# La historia semántica permite aplicar restricciones declaradas por el
	# template antes de que el assembler físico intente colocar nada.
	var main_path_history: Array[StringName] = [&"START"]
	var previous_id: StringName = &"START"
	var junction_ids: Array[StringName] = []
	for index in range(main_interior):
		var role: StringName = &""
		if index < template.main_path_prefix_roles.size():
			var prefix_role: StringName = template.main_path_prefix_roles[index]
			var prefix_rule := _grammar_rule(template, prefix_role)
			if _role_available_for_completion(template, prefix_rule, counts, previous_role, previous_run, required_junctions, main_path_history):
				role = prefix_role
		else:
			role = _choose_grammar_role(template, counts, previous_role, previous_run, main_interior - index, required_junctions, main_path_history, local_rng)
		if role.is_empty():
			# No usar un fallback que pueda saltarse una restricción física. Un
			# template mal configurado debe producir un plan inválido, no una
			# combinación que el assembler ya sabe que no puede materializar.
			plan.generation_error = "No compatible grammar role for main-path slot %d" % index
			return plan
		var id := StringName("NODE_%d" % index)
		plan.module_ids.append(id)
		plan.module_types[id] = role
		plan.module_definitions[id] = _find_module_definition(template, role)
		plan.module_definition_variants[id] = _find_module_variants(template, role)
		plan.main_path_nodes[id] = true
		plan.links[previous_id] = [id]
		previous_id = id
		counts[role] = int(counts.get(role, 0)) + 1
		if role == previous_role:
			previous_run += 1
		else:
			previous_role = role
			previous_run = 1
		if role == &"JUNCTION":
			junction_ids.append(id)
		main_path_history.append(role)
	var exit_id := &"EXIT"
	plan.module_ids.append(exit_id)
	plan.module_types[exit_id] = &"EXIT"
	plan.module_definitions[exit_id] = _find_module_definition(template, &"EXIT")
	plan.module_definition_variants[exit_id] = _find_module_variants(template, &"EXIT")
	plan.main_path_nodes[exit_id] = true
	plan.links[previous_id] = [exit_id]
	if uses_distribution_rules:
		plan.calculate_depths()
		if not _apply_distribution_rules(template, plan, distribution_destination_budget, local_rng):
			plan.generation_error = "No feasible parent/child distribution for configured branch rules"
		return plan
	# 6K.4A: el mismo DungeonPlan puede contener circuitos reales. Cada tramo
	# RECONNECT enlaza dos JUNCTION del camino principal y crea una ruta
	# alternativa; nunca se marca como branch terminal.
	var reconnection_pairs := _choose_reconnection_pairs(template, junction_ids, plan, local_rng)
	var requested_reconnections := mini(template.min_reconnections, template.max_reconnections)
	if requested_reconnections > 0 and reconnection_pairs.size() < requested_reconnections:
		plan.generation_error = "No feasible reconnection pair for configured circulation circuit"
		return plan
	var reconnection_junctions: Dictionary = {}
	for pair in reconnection_pairs:
		var source: StringName = pair.source
		var target: StringName = pair.target
		var reconnect_id := StringName("RECONNECT_%s_%s" % [source, target])
		plan.module_ids.append(reconnect_id)
		plan.module_types[reconnect_id] = &"CORRIDOR"
		plan.module_definitions[reconnect_id] = _find_module_definition(template, &"CORRIDOR")
		plan.module_definition_variants[reconnect_id] = _find_module_variants(template, &"CORRIDOR")
		plan.reconnection_nodes[reconnect_id] = true
		plan.reconnections.append({"id": reconnect_id, "source": source, "target": target})
		var source_children: Array = plan.links.get(source, []).duplicate()
		source_children.append(reconnect_id)
		plan.links[source] = source_children
		plan.links[reconnect_id] = [target]
		reconnection_junctions[source] = true
		reconnection_junctions[target] = true
	# Las branch_rules ya añadieron todos los destinos declarados. No aplicar la
	# expansión legacy por cada JUNCTION encima de una distribución explícita.
	if uses_distribution_rules:
		return plan
	for junction_id in junction_ids:
		# Los extremos de un circuito quedan reservados a circulación. Evita
		# convertir la reconexión en un junction físico de cuatro salidas.
		if reconnection_junctions.has(junction_id):
			continue
		var branch_parent := junction_id
		for segment in range(maxi(0, template.branch_length - 1)):
			var transit_role: StringName = template.branch_transit_roles[segment % template.branch_transit_roles.size()] if not template.branch_transit_roles.is_empty() else &"CORRIDOR"
			var transit_id := StringName("BRANCH_%s_%d" % [junction_id, segment])
			plan.module_ids.append(transit_id)
			plan.module_types[transit_id] = transit_role
			plan.module_definitions[transit_id] = _find_module_definition(template, transit_role)
			plan.module_definition_variants[transit_id] = _find_module_variants(template, transit_role)
			plan.branch_nodes[transit_id] = true
			var transit_children: Array = plan.links.get(branch_parent, []).duplicate()
			transit_children.append(transit_id)
			plan.links[branch_parent] = transit_children
			branch_parent = transit_id
		var side_id := StringName("SIDE_%s" % junction_id)
		var destination_role := template.branch_destination_role
		plan.module_ids.append(side_id)
		plan.module_types[side_id] = destination_role
		plan.module_definitions[side_id] = side_rule.module_definition if destination_role == &"SIDE_ROOM" and side_rule != null else _find_module_definition(template, destination_role)
		plan.module_definition_variants[side_id] = _find_module_variants(template, destination_role)
		plan.branch_nodes[side_id] = true
		var children: Array = plan.links.get(branch_parent, []).duplicate()
		children.append(side_id)
		plan.links[branch_parent] = children
	return plan


## Determina cuánto presupuesto total reserva el plan para destinos de
## distribución. Los valores viven en Resources y el RNG local conserva la
## reproducción por seed; los templates legacy nunca entran en esta ruta.
func _choose_distribution_destination_budget(template: DungeonTemplateResource, total_modules: int, local_rng: RandomNumberGenerator) -> int:
	var minimum := 0
	var maximum := 0
	for rule in template.branch_rules:
		if rule == null:
			continue
		minimum += rule.min_total_children
		maximum += maxi(rule.min_total_children, rule.max_total_children)
	minimum = maxi(minimum, template.min_distribution_destinations)
	if template.max_distribution_destinations >= 0:
		maximum = mini(maximum, template.max_distribution_destinations)
	var required_main := template.min_main_path_depth
	for grammar_rule in template.grammar_rules:
		if grammar_rule == null or grammar_rule.forbidden or not grammar_rule.main_path_allowed:
			continue
		if grammar_rule.role in [&"START", &"EXIT", &"SIDE_ROOM"]:
			continue
		required_main = maxi(required_main, 0)
		# La suma se evalúa abajo; esta asignación documenta que sólo roles de
		# camino principal consumen el presupuesto secuencial.
	var minimum_role_slots := 0
	for grammar_rule in template.grammar_rules:
		if grammar_rule == null or grammar_rule.forbidden or not grammar_rule.main_path_allowed:
			continue
		if grammar_rule.role in [&"START", &"EXIT", &"SIDE_ROOM"]:
			continue
		minimum_role_slots += grammar_rule.min_count
	required_main = maxi(required_main, minimum_role_slots)
	var max_budget := total_modules - 2 - required_main
	if template.max_main_path_depth >= 0:
		max_budget = mini(max_budget, total_modules - 2 - template.max_main_path_depth)
	maximum = mini(maximum, max_budget)
	if maximum < minimum:
		return -1
	return local_rng.randi_range(minimum, maximum) if maximum > minimum else minimum


func _minimum_junctions_for_main_capacity(template: DungeonTemplateResource, main_interior: int) -> int:
	var non_junction_capacity := 0
	var turn_capacity := 0
	for rule in template.grammar_rules:
		if rule == null or rule.forbidden or not rule.main_path_allowed or rule.role == &"JUNCTION":
			continue
		if rule.role in [&"START", &"EXIT", &"SIDE_ROOM"]:
			continue
		var maximum := rule.max_count if rule.max_count >= 0 else main_interior
		if rule.role in [&"TURN_LEFT", &"TURN_RIGHT"]:
			turn_capacity += maximum
		else:
			non_junction_capacity += maximum
	if template.max_turns >= 0:
		turn_capacity = mini(turn_capacity, template.max_turns)
	return maxi(0, main_interior - non_junction_capacity - turn_capacity)


func _apply_distribution_rules(template: DungeonTemplateResource, plan: DungeonPlan, destination_budget: int, local_rng: RandomNumberGenerator) -> bool:
	var remaining := destination_budget
	var used_parents: Dictionary = {}
	for rule_index in range(template.branch_rules.size()):
		var rule: DungeonBranchRuleResource = template.branch_rules[rule_index]
		if rule == null:
			continue
		var later_minimum := 0
		var later_maximum := 0
		for later_index in range(rule_index + 1, template.branch_rules.size()):
			var later: DungeonBranchRuleResource = template.branch_rules[later_index]
			if later != null:
				later_minimum += later.min_total_children
				later_maximum += maxi(later.min_total_children, later.max_total_children)
		# La regla actual debe dejar como mínimo el presupuesto de los siguientes,
		# pero también debe absorber lo suficiente para que sus máximos puedan
		# completar el total. Evita que una elección local deje destinos huérfanos.
		var minimum := maxi(rule.min_total_children, remaining - later_maximum)
		var maximum := mini(maxi(minimum, rule.max_total_children), remaining - later_minimum)
		if maximum < minimum:
			return false
		var child_total := local_rng.randi_range(minimum, maximum) if maximum > minimum else minimum
		if not _apply_distribution_rule(template, plan, rule, child_total, used_parents, local_rng):
			return false
		remaining -= child_total
	return remaining == 0


func _apply_distribution_rule(template: DungeonTemplateResource, plan: DungeonPlan, rule: DungeonBranchRuleResource, child_total: int, used_parents: Dictionary, local_rng: RandomNumberGenerator) -> bool:
	var candidates: Array[StringName] = []
	for node_id in plan.module_ids:
		if used_parents.has(node_id):
			continue
		if rule.require_main_path_parent and not plan.main_path_nodes.has(node_id):
			continue
		var depth := int(plan.node_depths.get(node_id, -1))
		if depth < rule.min_parent_depth or (rule.max_parent_depth >= 0 and depth > rule.max_parent_depth):
			continue
		if not rule.parent_after_plan_tag.is_empty() and depth <= _tagged_parent_max_depth(plan, rule.parent_after_plan_tag):
			continue
		if not _distribution_parent_respects_clearance_neighborhood(plan, node_id, rule):
			continue
		var role: StringName = plan.module_types.get(node_id, &"")
		if _matches_any_selector(template, role, plan.module_definitions.get(node_id, null), rule.parent_selectors):
			candidates.append(node_id)
	if candidates.is_empty():
		return false
	var viable_parent_counts: Array[int] = []
	var parent_min := mini(rule.min_parent_count, rule.max_parent_count)
	var parent_max := mini(maxi(rule.min_parent_count, rule.max_parent_count), candidates.size())
	for parent_count in range(parent_min, parent_max + 1):
		if parent_count <= 0:
			continue
		if child_total >= parent_count * rule.min_children_per_parent and child_total <= parent_count * rule.max_children_per_parent:
			viable_parent_counts.append(parent_count)
	if viable_parent_counts.is_empty():
		return false
	var parent_count := viable_parent_counts[local_rng.randi_range(0, viable_parent_counts.size() - 1)]
	var parents := _select_distribution_parents(candidates, parent_count, rule.parent_selection, plan, local_rng)
	if parents.size() != parent_count:
		return false
	var children_per_parent: Dictionary = {}
	for parent in parents:
		children_per_parent[parent] = rule.min_children_per_parent
	var remaining_children := child_total - parent_count * rule.min_children_per_parent
	while remaining_children > 0:
		var expandable: Array[StringName] = []
		for parent in parents:
			if int(children_per_parent[parent]) < rule.max_children_per_parent:
				expandable.append(parent)
		if expandable.is_empty():
			return false
		var selected_parent := expandable[local_rng.randi_range(0, expandable.size() - 1)]
		children_per_parent[selected_parent] = int(children_per_parent[selected_parent]) + 1
		remaining_children -= 1
	var rule_name := String(rule.stable_id) if not rule.stable_id.is_empty() else "RULE_%d" % template.branch_rules.find(rule)
	for parent in parents:
		used_parents[parent] = true
		_apply_distribution_parent_variants(plan, parent, rule)
		if not rule.parent_plan_tag.is_empty():
			var tags: Array = plan.node_tags.get(parent, []).duplicate()
			if not tags.has(rule.parent_plan_tag):
				tags.append(rule.parent_plan_tag)
			plan.node_tags[parent] = tags
		for child_index in range(int(children_per_parent[parent])):
			var child_id := StringName("BRANCH_%s_%s_%d" % [rule_name, parent, child_index])
			plan.module_ids.append(child_id)
			plan.module_types[child_id] = rule.destination_role
			plan.module_definitions[child_id] = _find_module_definition(template, rule.destination_role)
			plan.module_definition_variants[child_id] = _find_module_variants(template, rule.destination_role)
			plan.branch_nodes[child_id] = true
			var children: Array = plan.links.get(parent, []).duplicate()
			children.append(child_id)
			plan.links[parent] = children
	return true


## Compatibilidad declarativa de clearance para distribuidores. Un parent que
## sostiene destinos laterales obligatorios necesita una franja de circulación
## despejada antes y después de él; este chequeo cuenta TURN_* en un radio
## lógico bilateral. No conoce orientación, arquetipos ni AABBs. Los templates
## legacy usan 0/-1 y nunca restringen la selección.
func _distribution_parent_respects_clearance_neighborhood(plan: DungeonPlan, parent_id: StringName, rule: DungeonBranchRuleResource) -> bool:
	if rule.distribution_clearance_main_path_radius <= 0 or rule.max_turns_in_distribution_clearance < 0:
		return true
	var main_path: Array[StringName] = []
	for node_id in plan.module_ids:
		if plan.main_path_nodes.has(node_id):
			main_path.append(node_id)
	var parent_index := main_path.find(parent_id)
	if parent_index < 0:
		return true
	var first := maxi(0, parent_index - rule.distribution_clearance_main_path_radius)
	var last := mini(main_path.size() - 1, parent_index + rule.distribution_clearance_main_path_radius)
	var turns := 0
	for index in range(first, last + 1):
		if plan.module_types.get(main_path[index], &"") in [&"TURN_LEFT", &"TURN_RIGHT"]:
			turns += 1
	return turns <= rule.max_turns_in_distribution_clearance


func _tagged_parent_max_depth(plan: DungeonPlan, plan_tag: StringName) -> int:
	var latest := -1
	for node_id in plan.node_tags:
		if (plan.node_tags[node_id] as Array).has(plan_tag):
			latest = maxi(latest, int(plan.node_depths.get(node_id, -1)))
	return latest


func _select_distribution_parents(candidates: Array[StringName], count: int, mode: DungeonBranchRuleResource.ParentSelection, plan: DungeonPlan, local_rng: RandomNumberGenerator) -> Array[StringName]:
	var ordered := candidates.duplicate()
	if mode == DungeonBranchRuleResource.ParentSelection.EARLIEST or mode == DungeonBranchRuleResource.ParentSelection.LATEST:
		ordered.sort_custom(func(a: StringName, b: StringName) -> bool:
			var depth_a := int(plan.node_depths.get(a, 0))
			var depth_b := int(plan.node_depths.get(b, 0))
			if depth_a == depth_b:
				return String(a) < String(b) if mode == DungeonBranchRuleResource.ParentSelection.EARLIEST else String(a) > String(b)
			return depth_a < depth_b if mode == DungeonBranchRuleResource.ParentSelection.EARLIEST else depth_a > depth_b
		)
		return ordered.slice(0, count)
	var selected: Array[StringName] = []
	while not ordered.is_empty() and selected.size() < count:
		selected.append(ordered.pop_at(local_rng.randi_range(0, ordered.size() - 1)))
	return selected


func _apply_distribution_parent_variants(plan: DungeonPlan, node_id: StringName, rule: DungeonBranchRuleResource) -> void:
	if rule.parent_module_variants.is_empty():
		return
	var variants: Array[ModuleDefinitionResource] = []
	for definition in rule.parent_module_variants:
		if definition != null and not variants.has(definition):
			variants.append(definition)
	if not rule.parent_variant_required:
		for existing in plan.module_definition_variants.get(node_id, []):
			if existing != null and not variants.has(existing):
				variants.append(existing)
	if variants.is_empty():
		return
	plan.module_definition_variants[node_id] = variants
	if rule.parent_variant_required:
		plan.module_definitions[node_id] = variants[0]


func _choose_reconnection_pairs(template: DungeonTemplateResource, junction_ids: Array[StringName], plan: DungeonPlan, local_rng: RandomNumberGenerator) -> Array[Dictionary]:
	var requested_min := mini(template.min_reconnections, template.max_reconnections)
	var requested_max := maxi(template.min_reconnections, template.max_reconnections)
	var requested := local_rng.randi_range(requested_min, requested_max) if requested_max > requested_min else requested_min
	if requested <= 0: return []
	var pairs: Array[Dictionary] = []
	var used: Dictionary = {}
	for source_index in range(junction_ids.size()):
		var source := junction_ids[source_index]
		if used.has(source): continue
		for target_index in range(source_index + 1, junction_ids.size()):
			var target := junction_ids[target_index]
			if used.has(target): continue
			var source_index_in_path := plan.module_ids.find(source)
			var target_index_in_path := plan.module_ids.find(target)
			if target_index_in_path - source_index_in_path < template.min_reconnection_separation:
				continue
			pairs.append({"source": source, "target": target})
			used[source] = true
			used[target] = true
			break
		if pairs.size() >= requested: break
	if pairs.size() < requested:
		# Este error es una configuración cardinal/topológica, no un fallback
		# silencioso que degradaría MEDIUM/LARGE nuevamente a cadena lineal.
		return []
	return pairs


func _choose_grammar_role(template: DungeonTemplateResource, counts: Dictionary, previous_role: StringName, previous_run: int, slots_remaining: int, required_junctions: int, main_path_history: Array[StringName], local_rng: RandomNumberGenerator) -> StringName:
	var candidates: Array[DungeonGrammarRuleResource] = []
	var weights: Array[float] = []
	for rule in template.grammar_rules:
		if rule == null or rule.forbidden or rule.role in [&"START", &"EXIT", &"SIDE_ROOM"]:
			continue
		if not rule.main_path_allowed:
			continue
		if main_path_history.size() < rule.min_depth_from_start:
			continue
		if rule.max_depth_from_start >= 0 and main_path_history.size() > rule.max_depth_from_start:
			continue
		var count := int(counts.get(rule.role, 0))
		var max_count := rule.max_count if rule.max_count >= 0 else 9999
		if count >= max_count:
			continue
		if rule.role == &"JUNCTION" and count >= required_junctions:
			continue
		if rule.role in [&"TURN_LEFT", &"TURN_RIGHT"] and template.max_turns >= 0:
			var turns_used := int(counts.get(&"TURN_LEFT", 0)) + int(counts.get(&"TURN_RIGHT", 0))
			if turns_used >= template.max_turns:
				continue
		if rule.role == previous_role and rule.max_consecutive >= 0 and previous_run >= rule.max_consecutive:
			continue
		if not _reconnection_junction_spacing_allowed(template, main_path_history, rule.role):
			continue
		if not _main_path_distribution_clearance_allowed(template, main_path_history, rule.role):
			continue
		if not _is_grammar_transition_allowed(template, main_path_history, rule.role):
			continue
		# Lookahead lógico acotado: no toma una opción que deje los slots futuros
		# incapaces de satisfacer mínimos/consecutividad. No conoce geometría ni
		# hace backtracking espacial.
		var simulated_counts := counts.duplicate()
		simulated_counts[rule.role] = count + 1
		var simulated_run := previous_run + 1 if rule.role == previous_role else 1
		var simulated_history: Array[StringName] = main_path_history.duplicate()
		simulated_history.append(rule.role)
		if not _has_feasible_role_completion(template, simulated_counts, rule.role, simulated_run, slots_remaining - 1, required_junctions, simulated_history, {}):
			continue
		var missing_after := 0
		for other in template.grammar_rules:
			if other == null or other.forbidden or other.role in [&"START", &"EXIT", &"SIDE_ROOM", &"JUNCTION"]:
				continue
			var next_count := int(counts.get(other.role, 0)) + (1 if other.role == rule.role else 0)
			missing_after += maxi(0, other.min_count - next_count)
		var junction_missing := maxi(0, required_junctions - (int(counts.get(&"JUNCTION", 0)) + (1 if rule.role == &"JUNCTION" else 0)))
		if missing_after + junction_missing > slots_remaining - 1:
			continue
		candidates.append(rule)
		weights.append(maxf(0.0, rule.selection_weight))
	if candidates.is_empty():
		return &""
	var total_weight := 0.0
	for weight in weights:
		total_weight += weight
	if total_weight <= 0.0:
		return candidates[0].role
	var roll := local_rng.randf() * total_weight
	for index in range(candidates.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index].role
	return candidates.back().role


## Búsqueda de roles estrictamente limitada por la longitud del main path
## (máximo de los templates TEST actuales: 11). Su estado es sólo secuencial:
## no toca RNG, transforms, conectores, navegación ni assembly.
func _has_feasible_role_completion(template: DungeonTemplateResource, counts: Dictionary, previous_role: StringName, previous_run: int, slots_remaining: int, required_junctions: int, history: Array[StringName], memo: Dictionary) -> bool:
	var state_key := "%d|%s|%d|%d|%s|%s" % [slots_remaining, previous_role, previous_run, required_junctions, ",".join(history.slice(maxi(0, history.size() - 3)).map(func(v): return String(v))), _count_key(counts)]
	if memo.has(state_key):
		return bool(memo[state_key])
	if slots_remaining == 0:
		var complete := _minimums_satisfied(template, counts, required_junctions)
		memo[state_key] = complete
		return complete
	if _minimums_missing(template, counts, required_junctions) > slots_remaining:
		memo[state_key] = false
		return false
	for rule in template.grammar_rules:
		if not _role_available_for_completion(template, rule, counts, previous_role, previous_run, required_junctions, history):
			continue
		var count := int(counts.get(rule.role, 0))
		var next_counts := counts.duplicate()
		next_counts[rule.role] = count + 1
		var next_run := previous_run + 1 if rule.role == previous_role else 1
		var next_history: Array[StringName] = history.duplicate()
		next_history.append(rule.role)
		if _has_feasible_role_completion(template, next_counts, rule.role, next_run, slots_remaining - 1, required_junctions, next_history, memo):
			memo[state_key] = true
			return true
	memo[state_key] = false
	return false


func _role_available_for_completion(template: DungeonTemplateResource, rule: DungeonGrammarRuleResource, counts: Dictionary, previous_role: StringName, previous_run: int, required_junctions: int, history: Array[StringName]) -> bool:
	if rule == null or rule.forbidden or rule.role in [&"START", &"EXIT", &"SIDE_ROOM"]:
		return false
	if not rule.main_path_allowed:
		return false
	if history.size() < rule.min_depth_from_start:
		return false
	if rule.max_depth_from_start >= 0 and history.size() > rule.max_depth_from_start:
		return false
	var count := int(counts.get(rule.role, 0))
	var max_count := rule.max_count if rule.max_count >= 0 else 9999
	if count >= max_count:
		return false
	if rule.role == &"JUNCTION" and count >= required_junctions:
		return false
	if rule.role in [&"TURN_LEFT", &"TURN_RIGHT"] and template.max_turns >= 0:
		var turns := int(counts.get(&"TURN_LEFT", 0)) + int(counts.get(&"TURN_RIGHT", 0))
		if turns >= template.max_turns:
			return false
	if rule.role == previous_role and rule.max_consecutive >= 0 and previous_run >= rule.max_consecutive:
		return false
	if not _reconnection_junction_spacing_allowed(template, history, rule.role):
		return false
	if not _main_path_distribution_clearance_allowed(template, history, rule.role):
		return false
	return _is_grammar_transition_allowed(template, history, rule.role)


## Durante la construcción de la espina aplica la misma aproximación bilateral
## a todos los parents distribuidores posibles. Es conservadora a propósito:
## una regla SEEDED o dependiente de tags podría elegir cualquiera de esos
## parents después; validar todos evita aceptar una espina que luego no pueda
## hospedar sus destinos. La configuración sigue siendo enteramente del Resource.
func _main_path_distribution_clearance_allowed(template: DungeonTemplateResource, history: Array[StringName], candidate_role: StringName) -> bool:
	var future: Array[StringName] = history.duplicate()
	future.append(candidate_role)
	for branch_rule in template.branch_rules:
		if branch_rule == null or branch_rule.distribution_clearance_main_path_radius <= 0 or branch_rule.max_turns_in_distribution_clearance < 0:
			continue
		if not branch_rule.require_main_path_parent:
			continue
		for parent_index in _predicted_distribution_parent_indices(template, branch_rule, future):
			var first := maxi(0, parent_index - branch_rule.distribution_clearance_main_path_radius)
			var last := mini(future.size() - 1, parent_index + branch_rule.distribution_clearance_main_path_radius)
			var turns := 0
			for index in range(first, last + 1):
				if future[index] in [&"TURN_LEFT", &"TURN_RIGHT"]:
					turns += 1
			if turns > branch_rule.max_turns_in_distribution_clearance:
				return false
	return true


## Devuelve sólo los parents que la selección declarada todavía podría elegir.
## Para EARLIEST/LATEST no penaliza cada corredor compatible de la espina: la
## restricción se aplica a la porción que el propio Resource puede seleccionar.
## SEEDED conserva una comprobación conservadora porque cualquiera puede salir
## elegido por su RNG. Las dependencias por tag se resuelven contra la regla que
## emite ese tag cuando es predecible desde la misma historia de roles.
func _predicted_distribution_parent_indices(template: DungeonTemplateResource, rule: DungeonBranchRuleResource, history: Array[StringName]) -> Array[int]:
	var eligible: Array[int] = []
	for index in range(history.size()):
		if index < rule.min_parent_depth or (rule.max_parent_depth >= 0 and index > rule.max_parent_depth):
			continue
		var role: StringName = history[index]
		if _matches_any_selector(template, role, _find_module_definition(template, role), rule.parent_selectors):
			eligible.append(index)
	if not rule.parent_after_plan_tag.is_empty():
		var tagged_depth := _predicted_plan_tag_depth(template, rule.parent_after_plan_tag, history)
		if tagged_depth >= 0:
			eligible = eligible.filter(func(index: int) -> bool: return index > tagged_depth)
		else:
			return []
	if rule.parent_selection == DungeonBranchRuleResource.ParentSelection.SEEDED:
		return eligible
	var maximum := mini(maxi(1, rule.max_parent_count), eligible.size())
	if rule.parent_selection == DungeonBranchRuleResource.ParentSelection.EARLIEST:
		return eligible.slice(0, maximum)
	var first := maxi(0, eligible.size() - maximum)
	return eligible.slice(first, eligible.size())


func _predicted_plan_tag_depth(template: DungeonTemplateResource, plan_tag: StringName, history: Array[StringName]) -> int:
	for candidate_rule in template.branch_rules:
		if candidate_rule == null or candidate_rule.parent_plan_tag != plan_tag:
			continue
		# Una dependencia encadenada no puede deducirse sin simular la fase de
		# distribución completa; se deja al validador exacto posterior.
		if not candidate_rule.parent_after_plan_tag.is_empty():
			return -1
		var parents := _predicted_distribution_parent_indices(template, candidate_rule, history)
		if parents.is_empty():
			return -1
		return parents.back()
	return -1


## Si un template exige circuitos, los JUNCTION que los originan no pueden
## ser consecutivos: dos puertas contiguas no forman una ruta alternativa
## significativa. La distancia es un dato del template, no un caso Ship.
func _reconnection_junction_spacing_allowed(template: DungeonTemplateResource, history: Array[StringName], candidate_role: StringName) -> bool:
	if candidate_role != &"JUNCTION" or template.min_reconnections <= 0:
		return true
	for index in range(history.size() - 1, -1, -1):
		if history[index] != &"JUNCTION":
			continue
		return history.size() - index >= template.min_reconnection_separation
	return true


func _minimums_missing(template: DungeonTemplateResource, counts: Dictionary, required_junctions: int) -> int:
	var missing := 0
	for rule in template.grammar_rules:
		if rule == null or rule.forbidden or not rule.main_path_allowed or rule.role in [&"START", &"EXIT", &"SIDE_ROOM"]:
			continue
		var needed := required_junctions if rule.role == &"JUNCTION" else rule.min_count
		missing += maxi(0, needed - int(counts.get(rule.role, 0)))
	return missing


func _minimums_satisfied(template: DungeonTemplateResource, counts: Dictionary, required_junctions: int) -> bool:
	return _minimums_missing(template, counts, required_junctions) == 0


func _count_key(counts: Dictionary) -> String:
	var keys: Array[String] = []
	for key in counts.keys(): keys.append(String(key))
	keys.sort()
	var values: Array[String] = []
	for key in keys: values.append("%s=%d" % [key, int(counts[StringName(key)])])
	return ";".join(values)


func _is_grammar_transition_allowed(template: DungeonTemplateResource, history: Array[StringName], candidate_role: StringName) -> bool:
	var candidate_definition: ModuleDefinitionResource = _find_module_definition(template, candidate_role)
	if not history.is_empty():
		var previous_role: StringName = history.back()
		var previous_definition: ModuleDefinitionResource = _find_module_definition(template, previous_role)
		if previous_definition != null:
			if not previous_definition.allowed_next_selectors.is_empty() and not _matches_any_selector(template, candidate_role, candidate_definition, previous_definition.allowed_next_selectors):
				return false
			if _matches_any_selector(template, candidate_role, candidate_definition, previous_definition.forbidden_next_selectors):
				return false
	var sequence: Array[StringName] = history.duplicate()
	sequence.append(candidate_role)
	for constraint in template.forbidden_role_sequences:
		if constraint != null and not constraint.selector_pattern.is_empty() and _sequence_ends_with_selectors(template, sequence, constraint.selector_pattern):
			return false
	return true


func _matches_any_selector(template: DungeonTemplateResource, role: StringName, definition: ModuleDefinitionResource, selectors: Array[StringName]) -> bool:
	for selector in selectors:
		if _matches_selector(template, role, definition, selector):
			return true
	return false


func _sequence_ends_with_selectors(template: DungeonTemplateResource, sequence: Array[StringName], selectors: Array[StringName]) -> bool:
	if selectors.size() > sequence.size():
		return false
	var offset := sequence.size() - selectors.size()
	for index in range(selectors.size()):
		var role: StringName = sequence[offset + index]
		if not _matches_selector(template, role, _find_module_definition(template, role), selectors[index]):
			return false
	return true


func _matches_selector(_template: DungeonTemplateResource, role: StringName, definition: ModuleDefinitionResource, selector: StringName) -> bool:
	if selector.is_empty():
		return false
	if role == selector:
		return true
	return definition != null and (definition.roles.has(selector) or definition.tags.has(selector))


func _grammar_rule(template: DungeonTemplateResource, role: StringName) -> DungeonGrammarRuleResource:
	for rule in template.grammar_rules:
		if rule != null and rule.role == role:
			return rule
	return null


func _find_module_definition(template: DungeonTemplateResource, role: StringName) -> ModuleDefinitionResource:
	var rule := _grammar_rule(template, role)
	if rule != null and rule.module_definition != null:
		return rule.module_definition
	for resource in template.module_pool:
		if resource is ModuleDefinitionResource and ((resource as ModuleDefinitionResource).roles.has(role) or (resource as ModuleDefinitionResource).tags.has(role)):
			return resource as ModuleDefinitionResource
	return null


func _find_module_variants(template: DungeonTemplateResource, role: StringName) -> Array[ModuleDefinitionResource]:
	var result: Array[ModuleDefinitionResource] = []
	var rule := _grammar_rule(template, role)
	if rule != null and rule.module_definition != null:
		result.append(rule.module_definition)
	if rule != null:
		for variant in rule.module_variants:
			if variant != null and not result.has(variant):
				result.append(variant)
	if result.is_empty():
		var fallback := _find_module_definition(template, role)
		if fallback != null:
			result.append(fallback)
	return result
