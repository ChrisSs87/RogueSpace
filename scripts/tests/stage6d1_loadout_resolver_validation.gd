extends Node3D
const EnemyScene := preload("res://scenes/enemies/Enemy.tscn")
const Carnotauro := preload("res://resources/enemies/orco_melee.tres")
const CardDef := preload("res://resources/cards/CardResource.gd")
const WeaponDef := preload("res://resources/equipment/WeaponResource.gd")
const LoadoutDef := preload("res://resources/equipment/LoadoutResource.gd")
const ArtifactDef := preload("res://resources/equipment/ArtifactResource.gd")
const ModifierDef := preload("res://resources/equipment/ValueModifierResource.gd")

func card(name: String, damage := 0, block := 0) -> CardResource:
	var c: CardResource = CardDef.new(); c.card_name = name; c.damage_amount = damage; c.block_amount = block; c.tags = [&"physical"]; return c
func modifier(kind: int, op: int, amount: float) -> ValueModifierResource:
	var m: ValueModifierResource = ModifierDef.new(); m.value_kind = kind; m.operation = op; m.amount = amount; m.required_card_tags = [&"physical"]; return m
func _ready() -> void:
	var primary_cards: Array[CardResource] = [card("P1"),card("P2"),card("P3"),card("P4"),card("P5"),card("P6")]
	var secondary_cards: Array[CardResource] = [card("S1"),card("S2"),card("S3"),card("S4"),card("S5")]
	var fallback := card("Fallback")
	var primary: WeaponResource = WeaponDef.new(); primary.contributed_cards = primary_cards; primary.modifiers = [modifier(ModifierDef.ValueKind.DAMAGE, ModifierDef.Operation.PERCENT, 0.10)]
	var secondary: WeaponResource = WeaponDef.new(); secondary.contributed_cards = secondary_cards; secondary.modifiers = [modifier(ModifierDef.ValueKind.BLOCK, ModifierDef.Operation.PERCENT, 0.50)]
	var artifact: ArtifactResource = ArtifactDef.new(); artifact.modifiers = [modifier(ModifierDef.ValueKind.DAMAGE, ModifierDef.Operation.PERCENT, 0.05)]
	var modular: LoadoutResource = LoadoutDef.new(); modular.deck_size = 10; modular.primary_weapon = primary; modular.secondary_weapon = secondary; modular.fallback_cards = [fallback]; modular.active_artifacts = [artifact]
	var composed := modular.compose_starting_deck()
	var composition_ok := composed.size() == 10 and composed.slice(0,6) == primary_cards and composed[6] == secondary_cards[0] and composed[9] == secondary_cards[3]
	var two_handed: LoadoutResource = LoadoutDef.new(); primary.allows_secondary = false; two_handed.deck_size = 10; two_handed.primary_weapon = primary; two_handed.secondary_weapon = secondary; two_handed.fallback_cards = [fallback]
	var two_hand_ok := two_handed.compose_starting_deck().slice(0,6) == primary_cards and not two_handed.compose_starting_deck().has(secondary_cards[0]) and two_handed.compose_starting_deck().size() == 10
	primary.allows_secondary = true
	var strike := card("Resolver Strike", 6); var defense := card("Resolver Guard", 0, 6)
	RunState.reset_run(); RunState.equipped_loadout = modular; RunState.equipped_weapon = null; RunState.equipped_shield = null
	var values := CardValueResolver.get_resolved_card_values(strike)
	var block_values := CardValueResolver.get_resolved_card_values(defense)
	# 6 * 1.05 * 1.10 = 6.93 -> roundi = 7; 6 * 1.50 = 9.
	var resolver_ok: bool = values.damage == 7 and block_values.block == 9 and defense.block_amount == 6
	var enemy: Enemy = EnemyScene.instantiate(); var fixture: EnemyResource = Carnotauro.duplicate() as EnemyResource; fixture.combat_deck=[]; fixture.opening_block=0; enemy.enemy_resource=fixture; add_child(enemy)
	CombatManager.reset_after_defeat(); CombatEncounterManager.reset(); EventBus.combat_ready.emit($MainFortress6A/Player,[enemy]); CombatManager.select_target(0)
	var target: EnemyCombatant = CombatManager._combatants[0]; var hp := target.current_health; strike.stamina_cost=0; RunState.hand=[strike]; CombatManager.play_card(strike)
	var runtime_damage_ok := target.current_health == hp - int(values.damage)
	defense.stamina_cost=0; RunState.hand=[defense]; CombatManager.play_card(defense)
	var runtime_block_ok := RunState.block == int(block_values.block)
	RunState.equipped_loadout = null; var legacy_ok := RunState.get_starting_deck_for_loadout() == RunState.starting_deck
	var passed: bool = composition_ok and two_hand_ok and resolver_ok and runtime_damage_ok and runtime_block_ok and legacy_ok
	print("6D1 composition=%s two_hand=%s resolver=%s preview_damage=%d runtime_damage=%s preview_block=%d runtime_block=%s legacy=%s" % [composition_ok,two_hand_ok,resolver_ok,values.damage,runtime_damage_ok,block_values.block,runtime_block_ok,legacy_ok])
	if passed: print("Stage6D1 loadout/resolver: PASS"); get_tree().quit(0)
	else: push_error("Stage6D1 loadout/resolver: FAIL"); get_tree().quit(1)
