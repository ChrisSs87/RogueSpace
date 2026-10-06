extends Node
const NodeDef:=preload("res://resources/run/RunNodeResource.gd")
const GraphDef:=preload("res://resources/run/RunGraphResource.gd")
const DungeonDef:=preload("res://resources/run/DungeonDefinitionResource.gd")
const TemplateDef:=preload("res://resources/run/DungeonTemplateResource.gd")
const DirectorDef:=preload("res://scripts/world/RunDirector.gd")
func node(id:StringName,next:Array[StringName],dungeon:Resource)->RunNodeResource:
	var n:RunNodeResource=NodeDef.new(); n.node_id=id; n.next_node_ids=next; n.dungeon=dungeon; return n
func _ready()->void:
	var fixed:DungeonDefinitionResource=DungeonDef.new(); fixed.stable_id=&"test_fixed"; fixed.generation_mode=DungeonDef.GenerationMode.FIXED; fixed.fixed_scene=load("res://scenes/MainFortress6A.tscn"); fixed.reward_id=&"test_reward"
	var template:DungeonTemplateResource=TemplateDef.new(); template.stable_id=&"test_template"; template.min_modules=5; template.max_modules=8
	var generated:DungeonDefinitionResource=DungeonDef.new(); generated.stable_id=&"test_template_dungeon"; generated.generation_mode=DungeonDef.GenerationMode.TEMPLATE; generated.template=template; generated.reward_id=&"test_reward_b"
	var graph:RunGraphResource=GraphDef.new(); graph.graph_id=&"fixture_graph"; graph.start_node_id=&"START"
	graph.nodes=[node(&"START",[&"A"],fixed),node(&"A",[&"B",&"C"],fixed),node(&"B",[&"D"],generated),node(&"C",[&"D"],fixed),node(&"D",[&"BOSS"],generated),node(&"BOSS",[],fixed)]
	RunState.reset_run(); RunState.begin_world_run(graph,4242)
	var director:RunDirector=RunState.run_director
	var start_ok:bool=director.current_node_id==&"START" and director.available_nodes().size()==1
	var blocked_ok:bool=director.select_node(&"B").is_empty()
	var launch_a:=director.select_node(&"A"); var fixed_ok:bool=launch_a.kind=="fixed" and launch_a.scene==fixed.fixed_scene
	RunState.apply_damage_to_player(4); RunState.consume_oxygen(7,"movement"); DNAManager.add_dna("weapon","orco",1); RunState.character_stats.set_base(&"damage",3)
	var hp:=RunState.player_health; var o2:=RunState.oxygen_current; var dna:=DNAManager.get_dna_amount("weapon","orco")
	var reward:=director.complete_current(); var available:=director.available_nodes(); var branch_ok:bool=reward.reward==&"test_reward" and available.size()==2
	var launch_b:=director.select_node(&"B"); var plan:DungeonPlan=launch_b.plan
	var plan_ok:bool=launch_b.kind=="plan" and plan.is_valid() and plan.module_ids.size()>=5 and plan.module_ids.size()<=8
	var other:RunDirector=DirectorDef.new(); other.start(graph,4242); other.select_node(&"A"); other.complete_current(); var other_plan:DungeonPlan=other.select_node(&"B").plan
	var deterministic:bool=plan.module_ids==other_plan.module_ids and plan.links==other_plan.links
	var persistence:bool=RunState.player_health==hp and is_equal_approx(RunState.oxygen_current,o2) and DNAManager.get_dna_amount("weapon","orco")==dna and RunState.character_stats.get_value(&"damage")==3
	var passed:bool=start_ok and blocked_ok and fixed_ok and branch_ok and plan_ok and deterministic and persistence
	print("6F graph start=%s blocked=%s fixed=%s branch=%s plan=%s deterministic=%s persistence=%s"%[start_ok,blocked_ok,fixed_ok,branch_ok,plan_ok,deterministic,persistence])
	if passed: print("Stage6F run structure: PASS"); get_tree().quit(0)
	else: push_error("Stage6F run structure: FAIL"); get_tree().quit(1)
