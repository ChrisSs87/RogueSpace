extends Node3D

const EnemyScene := preload("res://scenes/enemies/Enemy.tscn")
const Carnotauro := preload("res://resources/enemies/orco_melee.tres")
const CardDef := preload("res://resources/cards/CardResource.gd")
const LoadoutDef := preload("res://resources/equipment/LoadoutResource.gd")
const EffectDef := preload("res://resources/effects/StatusEffectDefinition.gd")

func _card(id: String, cost: int, damage: int = 0, block: int = 0) -> CardResource:
	var card: CardResource = CardDef.new()
	card.card_name = id; card.stamina_cost = cost; card.damage_amount = damage; card.block_amount = block
	return card

func _ready() -> void:
	var attack := _card("Test Strike", 1, 5)
	var guard := _card("Test Guard", 1, 0, 4)
	var combo := _card("Test Combo", 0, 2, 2)
	var poison: StatusEffectDefinition = EffectDef.new()
	poison.effect_id = &"test_card_poison"; poison.tags = [&"toxin"]; poison.base_duration_turns = 1; poison.magnitude = 2
	poison.turn_start_operation = EffectDef.TurnOperation.DAMAGE
	var toxin := _card("Test Toxin", 0); toxin.apply_effects = [poison]
	var loadout_a: LoadoutResource = LoadoutDef.new(); loadout_a.loadout_id = &"test_a"; loadout_a.starting_cards = [attack, guard, combo, toxin]
	var loadout_b: LoadoutResource = LoadoutDef.new(); loadout_b.loadout_id = &"test_b"; loadout_b.starting_cards = [guard, guard, toxin, attack]
	RunState.reset_run(); RunState.equipped_loadout = loadout_a; RunState.rebuild_deck_from_loadout()
	var loadout_a_ok := RunState.deck.size() == 4 and RunState.deck.has(combo) and loadout_a.starting_cards.size() == 4
	RunState.draw_cards(4); var draw_ok := RunState.hand.size() == 4
	RunState.discard_hand(); RunState.draw_cards(4); var reshuffle_ok := RunState.hand.size() == 4
	RunState.equipped_loadout = loadout_b; RunState.rebuild_deck_from_loadout()
	var loadout_b_ok := RunState.deck.size() == 4 and RunState.deck.count(guard) == 2 and not RunState.deck.has(combo) and loadout_a.starting_cards.size() == 4
	var enemy: Enemy = EnemyScene.instantiate()
	var fixture: EnemyResource = Carnotauro.duplicate() as EnemyResource; fixture.combat_deck = []; fixture.opening_block = 0; enemy.enemy_resource = fixture; add_child(enemy)
	RunState.reset_run(); RunState.equipped_loadout = loadout_a; CombatManager.reset_after_defeat(); CombatEncounterManager.reset()
	EventBus.combat_ready.emit($MainFortress6A/Player, [enemy])
	CombatManager.select_target(0)
	var combatant: EnemyCombatant = CombatManager._combatants[0]
	var hp0 := combatant.current_health
	RunState.hand = [attack]; CombatManager.play_card(attack)
	var attack_ok := combatant.current_health == hp0 - 5 and RunState.stamina == RunState.max_stamina - 1
	RunState.hand = [guard]; CombatManager.play_card(guard)
	var guard_ok := RunState.block == 4
	var hp1 := combatant.current_health
	RunState.hand = [combo]; CombatManager.play_card(combo)
	var combo_ok := combatant.current_health == hp1 - 2 and RunState.block == 6
	RunState.hand = [toxin]; CombatManager.play_card(toxin)
	var applied_ok := combatant.effects.has_effect(&"test_card_poison")
	var hp2 := combatant.current_health
	CombatManager.end_turn()
	var effect_ok := combatant.current_health == hp2 - 2 and not combatant.effects.has_effect(&"test_card_poison")
	var passed := loadout_a_ok and draw_ok and reshuffle_ok and loadout_b_ok and attack_ok and guard_ok and combo_ok and applied_ok and effect_ok
	print("6D LOADOUT | A=%s B=%s draw=%s reshuffle=%s" % [loadout_a_ok, loadout_b_ok, draw_ok, reshuffle_ok])
	print("6D COMBAT | damage=%s block=%s combo=%s status_apply=%s status_tick=%s" % [attack_ok, guard_ok, combo_ok, applied_ok, effect_ok])
	if passed:
		print("Stage6D cards/loadout validation: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6D cards/loadout validation: FAIL")
		get_tree().quit(1)
