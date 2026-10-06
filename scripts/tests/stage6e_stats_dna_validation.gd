extends Node3D
const EnemyScene := preload("res://scenes/enemies/Enemy.tscn")
const Carnotauro := preload("res://resources/enemies/orco_melee.tres")
const CardDef := preload("res://resources/cards/CardResource.gd")
const DNADef := preload("res://resources/dna/DNASpeciesResource.gd")
const ModDef := preload("res://resources/equipment/ValueModifierResource.gd")
const ArtifactDef := preload("res://resources/equipment/ArtifactResource.gd")
const WeaponDef := preload("res://resources/equipment/WeaponResource.gd")
const LoadoutDef := preload("res://resources/equipment/LoadoutResource.gd")
func mod(kind: int, amount: float) -> ValueModifierResource:
	var m: ValueModifierResource = ModDef.new(); m.value_kind=kind; m.operation=ModDef.Operation.FLAT; m.amount=amount; return m
func pct(kind: int, amount: float) -> ValueModifierResource:
	var m: ValueModifierResource = ModDef.new(); m.value_kind=kind; m.operation=ModDef.Operation.PERCENT; m.amount=amount; m.required_card_tags=[&"physical"]; return m
func _ready() -> void:
	var species: DNASpeciesResource = DNADef.new(); species.species_id="test_dna"; species.units_per_level=5; species.stat_modifiers=[mod(ModDef.ValueKind.DAMAGE,3),mod(ModDef.ValueKind.BLOCK,1)]
	var original_species := DNAManager.species_resources.duplicate(); DNAManager.species_resources.append(species); DNAManager.reset()
	var add_invalid_before := DNAManager.get_dna_amount("weapon","test_dna"); DNAManager.add_dna("invalid","test_dna",5); var invalid_ok := DNAManager.get_dna_amount("weapon","test_dna") == add_invalid_before
	DNAManager.add_dna("weapon","test_dna",12); DNAManager.add_dna("shield","test_dna",10)
	var levels_ok := DNAManager.get_dna_level("weapon","test_dna")==2 and DNAManager.get_dna_level("shield","test_dna")==2
	var stats_ok := DNAManager.get_stat_bonus("weapon",ModDef.ValueKind.DAMAGE)==6 and DNAManager.get_stat_bonus("shield",ModDef.ValueKind.BLOCK)==2
	var artifact: ArtifactResource = ArtifactDef.new(); artifact.modifiers=[pct(ModDef.ValueKind.DAMAGE,0.05)]
	var primary: WeaponResource = WeaponDef.new(); primary.modifiers=[pct(ModDef.ValueKind.DAMAGE,0.10)]
	var secondary: WeaponResource = WeaponDef.new(); secondary.modifiers=[pct(ModDef.ValueKind.BLOCK,0.50)]
	var loadout: LoadoutResource = LoadoutDef.new(); loadout.primary_weapon=primary; loadout.secondary_weapon=secondary; loadout.active_artifacts=[artifact]
	var damage: CardResource=CardDef.new(); damage.damage_amount=6; damage.derive_damage_from_weapon=true; damage.tags=[&"physical"]; damage.stamina_cost=0
	var block: CardResource=CardDef.new(); block.block_amount=6; block.derive_block_from_shield=true; block.tags=[&"physical"]; block.stamina_cost=0
	RunState.reset_run(); RunState.equipped_loadout=loadout; RunState.equipped_weapon=null; RunState.equipped_shield=null; RunState.character_stats.set_base(&"damage",0); RunState.character_stats.set_base(&"block",0)
	var preview_d := CardValueResolver.get_resolved_card_values(damage); var preview_b := CardValueResolver.get_resolved_card_values(block)
	# (6 + DNA 6) * 1.05 * 1.10 = 13.86 -> 14; (6 + DNA 2) * 1.50 = 12.
	var resolver_ok: bool=preview_d.damage==14 and preview_b.block==12 and damage.damage_amount==6 and block.block_amount==6
	var enemy: Enemy=EnemyScene.instantiate(); var fixture: EnemyResource=Carnotauro.duplicate() as EnemyResource; fixture.combat_deck=[]; fixture.opening_block=0; enemy.enemy_resource=fixture; add_child(enemy)
	CombatManager.reset_after_defeat(); CombatEncounterManager.reset(); EventBus.combat_ready.emit($MainFortress6A/Player,[enemy]); CombatManager.select_target(0)
	var combatant: EnemyCombatant=CombatManager._combatants[0]; var hp:=combatant.current_health; RunState.hand=[damage]; CombatManager.play_card(damage); var runtime_d:=combatant.current_health==hp-14
	RunState.hand=[block]; CombatManager.play_card(block); var runtime_b:=RunState.block==12
	DNAManager.add_dna("weapon","test_dna",3); var reassigned_ok:=DNAManager.get_dna_level("weapon","test_dna")==3 and DNAManager.get_stat_bonus("weapon",ModDef.ValueKind.DAMAGE)==9
	DNAManager.species_resources=original_species; DNAManager.reset()
	var passed: bool=invalid_ok and levels_ok and stats_ok and resolver_ok and runtime_d and runtime_b and reassigned_ok
	print("6E stats invalid=%s levels=%s stats=%s resolver=%s damage_runtime=%s block_runtime=%s reassigned=%s values=%d/%d" % [invalid_ok,levels_ok,stats_ok,resolver_ok,runtime_d,runtime_b,reassigned_ok,preview_d.damage,preview_b.block])
	if passed: print("Stage6E stats/DNA validation: PASS"); get_tree().quit(0)
	else: push_error("Stage6E stats/DNA validation: FAIL"); get_tree().quit(1)
