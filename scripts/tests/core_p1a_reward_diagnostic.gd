extends Node

## DIAGNOSTIC ONLY. One fresh process per scenario; no production mutations.
## This root sibling survives reload_current_scene of the REAL scene under test.
## Admission is covered by P0: enter via the same public combat_ready boundary
## as the existing reward regression, then real card/victory/reward/UI contracts.
const STAGE := preload("res://scenes/tests/Stage6JArchetypePrototype.tscn")
const FORTRESS := preload("res://scenes/MainFortress6A.tscn")
var operation := "regen"
var checkpoint := "summary"
var stage: Node3D
var player: Node3D
var events: Array = []
var snapshots: Array = []
var issues: Array[String] = []
var setup_errors: Array[String] = []
var roll_seed := -1

func _event(label: String, payload: Variant = null) -> void:
	events.append({"index":events.size(),"frame":Engine.get_physics_frames(),"event":label,"payload":payload,"reward_step":RewardManager.get_step(),"suspended":ExplorationState.is_suspended(),"player_valid":is_instance_valid(player),"frozen":player.is_frozen if is_instance_valid(player) else false})

func _snapshot(label: String) -> Dictionary:
	var cards: Array = []
	for card in RunState.get_full_card_pool(): cards.append(card.resource_path if not card.resource_path.is_empty() else card.card_name)
	cards.sort()
	var timers: Array = []
	var registered_live := 0
	var registered_dead := 0
	for entry: Dictionary in ExplorationState._actors.values():
		if entry.ref.get_ref() == null: registered_dead += 1
		else: registered_live += 1
	if is_instance_valid(stage):
		for timer: Timer in stage.find_children("*","Timer",true,false):
			timers.append({"path":str(timer.get_path()),"paused":timer.paused,"stopped":timer.is_stopped(),"time_left":timer.time_left})
	var row := {"label":label,"step":RewardManager.get_step(),"dna":DNAManager.dna.duplicate(true),"abilities":DNAManager.unlocked_abilities.duplicate(true),"hp":RunState.player_health,"max_hp":RunState.max_player_health,"derived_max_hp":RunState.base_max_player_health+DNAManager.get_suit_max_health_bonus(),"damage_bonus":DNAManager.get_weapon_damage_bonus(),"damage_stat":RunState.get_damage_card_stat(),"deck":cards,"oxygen":RunState.oxygen_current,"run_seed":RunState.run_seed,"suspended":ExplorationState.is_suspended(),"suspend_combat":ExplorationState._combat,"suspend_reward":ExplorationState._reward,"frozen":player.is_frozen if is_instance_valid(player) else false,"player_id":player.get_instance_id() if is_instance_valid(player) else 0,"reward_player_valid":is_instance_valid(RewardManager._player),"reward_player_id":RewardManager._player.get_instance_id() if is_instance_valid(RewardManager._player) else 0,"reward_player_text":str(RewardManager._player),"pending_dna":RewardManager._pending_dna_species.duplicate(),"pending_card":RewardManager._pending_unlocked_card.resource_path if RewardManager._pending_unlocked_card != null else "","pending_kit":RewardManager._kit_offer_pending,"combatants":CombatManager.get_combatant_count(),"encounter_active":CombatEncounterManager.is_encounter_active(),"encounter_pending":CombatEncounterManager.get_debug_pending_count(),"combat_ui":stage.get_node("CombatUI").visible,"reward_ui":stage.get_node("RewardUI").visible,"timers":timers,"signal_count":events.size()}
	snapshots.append(row)
	row["registered_actors_live"] = registered_live
	row["registered_actors_dead"] = registered_dead
	row["reward_signal_connections"] = {"started":RewardManager.get_signal_connection_list("reward_sequence_started").size(),"changed":RewardManager.get_signal_connection_list("reward_step_changed").size(),"finished":RewardManager.get_signal_connection_list("reward_sequence_finished").size()}
	print("P1A_SNAPSHOT="+JSON.stringify(row))
	return row

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--operation="): operation = arg.trim_prefix("--operation=")
		if arg.begins_with("--step="): checkpoint = arg.trim_prefix("--step=")
	call_deferred("_run")

func _wait_until(predicate: Callable, frames: int = 720) -> bool:
	for frame in frames:
		if predicate.call(): return true
		await get_tree().physics_frame
		await get_tree().process_frame
	return predicate.call()

func _quiet_fixture() -> void:
	player = stage.get_node("Player")
	# No admission/nav/locomotion claim. Keep other actors from opening unrelated
	# combats while the harness clicks UI. Timer.paused still records suspension.
	for actor in stage.find_children("*","CharacterBody3D",true,false):
		if actor is Enemy:
			actor.perception_timer.stop()
			actor.set_physics_process(false)
	player.set_physics_process(false)

func _run() -> void:
	stage = STAGE.instantiate() if operation in ["regen","dna_sector"] else FORTRESS.instantiate()
	if operation in ["regen","dna_sector"]:
		stage.initial_seed = 65003 if operation == "dna_sector" else 65001
		stage.test_archetype_index = 1
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	if operation in ["regen","dna_sector"]:
		if not await _wait_until(func(): return stage.nav_ready and stage.assembly_valid):
			setup_errors.append("scene generation unavailable")
	_quiet_fixture()
	if operation in ["well_reset","dna_well_reset"]:
		player.global_position = stage.get_node("Fortress6A/WellTrigger").global_position
		if not await _wait_until(func(): return stage.get_node("Fortress6A/FortressEndUI").visible): setup_errors.append("actual Well restart UI not reachable")
	CombatManager.combat_started.connect(func(): _event("combat_started"))
	CombatManager.combat_ended.connect(func(): _event("combat_ended"))
	CombatManager.player_defeated.connect(func(): _event("player_defeated"))
	EventBus.combat_ready.connect(func(_p,_e): _event("combat_ready_listener_after_autoloads"))
	RewardManager.reward_sequence_started.connect(func(): _event("reward_started"))
	RewardManager.reward_step_changed.connect(func(): _event("reward_step_changed"))
	RewardManager.reward_sequence_finished.connect(func(): _event("reward_finished"))
	DNAManager.dna_changed.connect(func(slot,species,amount): _event("dna_changed",[slot,species,amount]))
	RunState.player_health_changed.connect(func(hp,max_hp): _event("hp_changed",[hp,max_hp]))
	_snapshot("COLD_PROCESS_START")
	if operation == "cold_start":
		if DNAManager.get_dna_amount("weapon","varkhen") != 0 or not DNAManager.unlocked_abilities.is_empty() or RunState.max_player_health != RunState.base_max_player_health: issues.append("cold boot not clean")
		_finish()
		return
	# Select a deterministic naturally possible kit roll; exported probability
	# stays 0.10, DNA stays the actual DEV 1.0. No pending/step flags are set.
	for candidate in 10000:
		seed(candidate)
		var dna_roll := randf()
		var kit_roll := randf()
		if dna_roll < RewardManager.dna_drop_chance and kit_roll < RewardManager.recovery_item_chance:
			roll_seed = candidate
			break
	print("P1A_RNG="+JSON.stringify({"seed":roll_seed,"dna_probability":RewardManager.dna_drop_chance,"kit_probability":RewardManager.recovery_item_chance}))
	if roll_seed < 0: setup_errors.append("could not establish natural reward roll")
	if not setup_errors.is_empty():
		_finish()
		return
	# Two real victories/reward choices establish the existing level-3 unlock
	# precondition. Never seed DNA/abilities directly or invent a species.
	for index in 2:
		if not await _victory(): break
		RewardManager.acknowledge_summary()
		RewardManager.choose_dna_slot("weapon")
		_complete_reward()
	if not setup_errors.is_empty():
		_finish()
		return
	if operation in ["dna_sector","dna_runstate","dna_ui_reset","dna_well_reset","defeat_reset"]:
		await _dna_or_defeat()
		_finish()
		return
	if not await _victory():
		_finish()
		return
	_reach_checkpoint()
	var required_step: String = {"summary":"summary","dna_choice":"dna_choice","dna_result":"dna_result","unlock":"card_unlocked","replace_pending":"card_replace_choice","replace_confirmed":"kit_offer","kit_pending":"kit_offer","heal_confirmed":"kit_result","done":"done"}.get(checkpoint,"INVALID")
	if RewardManager.get_step() != required_step: setup_errors.append("checkpoint not reached: expected "+required_step)
	if checkpoint == "replace_confirmed" and not RunState.get_full_card_pool().has(load("res://resources/cards/golpe_pesado.tres")): setup_errors.append("real replacement not confirmed")
	if checkpoint == "heal_confirmed" and RunState.player_health != RunState.max_player_health: setup_errors.append("kit healing not confirmed")
	if not setup_errors.is_empty():
		_finish()
		return
	var before := _snapshot("BEFORE_INTERRUPT")
	var event_boundary := events.size()
	var old_scene_id := stage.get_instance_id()
	if operation == "regen":
		stage.get_node("DebugHUD").reset_button.pressed.emit()
		if not await _wait_until(func(): return stage.nav_ready and stage.assembly_valid and stage.seed == 65002): setup_errors.append("debug regeneration did not finish")
	else:
		if operation == "run_reset": stage.get_node("DebugHUD").reset_button.pressed.emit()
		elif operation == "well_reset": stage.get_node("Fortress6A/FortressEndUI/Panel/VBox/RestartButton").pressed.emit()
		else: setup_errors.append("unknown operation")
		if not await _wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.get_instance_id() != old_scene_id): setup_errors.append("reload did not finish")
		stage = get_tree().current_scene
	_quiet_fixture()
	await get_tree().physics_frame
	await get_tree().process_frame
	var after := _snapshot("AFTER_INTERRUPT")
	_validate_interruption(before, after)
	print("P1A_INTERRUPT_EVENTS="+JSON.stringify(events.slice(event_boundary)))
	# Confirmed effects staying is an observation, not a rollback assertion.
	print("P1A_CONFIRMED_EFFECTS="+JSON.stringify({"before_dna":before.dna,"after_dna":after.dna,"before_deck":before.deck,"after_deck":after.deck,"before_hp":before.hp,"after_hp":after.hp,"rollback_policy":"UNDECIDED_NOT_ASSERTED"}))
	_finish()

## Diagnostic policy kept intact; P1-B overrides this hook with the explicit
## cancelled/DONE contract instead of requiring a live old Player afterwards.
func _validate_interruption(before: Dictionary, after: Dictionary) -> void:
	if checkpoint != "done":
		if after.step != RewardManager.STEP_DONE and not after.reward_ui: issues.append("orphaned pending reward: manager active, new RewardUI hidden")
		if after.step != RewardManager.STEP_DONE and (not after.suspended or not after.frozen): issues.append("pending RewardUI/manager with exploration released")
		if not after.reward_player_valid: issues.append("RewardManager retains freed Player reference")
	else:
		if after.reward_ui or after.combat_ui or after.suspended or after.frozen or after.combatants != 0: issues.append("normal finished flow/reset not clean")
	if after.max_hp != after.derived_max_hp: issues.append("cached max HP disagrees with current DNA")

func _victory() -> bool:
	var actor: Enemy = null
	for candidate in stage.find_children("*","CharacterBody3D",true,false):
		if candidate is Enemy and not candidate.is_queued_for_deletion() and candidate.enemy_resource != null and candidate.enemy_resource.species_id == "varkhen":
			actor = candidate
			break
	if actor == null:
		setup_errors.append("no real Varkhen Enemy available")
		return false
	player.freeze_for_combat()
	EventBus.combat_ready.emit(player,[actor])
	if CombatManager.get_combatant_count() != 1 or not stage.get_node("CombatUI").visible:
		setup_errors.append("real combat/UI entry unavailable")
		return false
	RunState.apply_damage_to_player(10)
	# Test-only lethal card isolates real production resolution/victory. Replace
	# one hand card temporarily, then restore it with the public pool API so
	# diagnostics never mistake fixture cards for progression/deck inflation.
	var original: CardResource = RunState.hand[0]
	var strike := CardResource.new()
	strike.card_name = "P1A diagnostic resolution"
	strike.damage_amount = 999
	strike.stamina_cost = 0
	RunState.hand[0] = strike
	seed(roll_seed)
	CombatManager.play_card(strike)
	if not RunState.replace_card(strike,original): setup_errors.append("fixture card restoration failed")
	await get_tree().process_frame
	if RewardManager.get_step() != RewardManager.STEP_SUMMARY or not RewardManager._kit_offer_pending or not stage.get_node("RewardUI").visible:
		setup_errors.append("victory did not reach natural summary+DNA+kit")
		return false
	return true

func _complete_reward() -> void:
	for step in 16:
		match RewardManager.get_step():
			RewardManager.STEP_SUMMARY: RewardManager.acknowledge_summary()
			RewardManager.STEP_DNA_CHOICE: RewardManager.choose_dna_slot("weapon")
			RewardManager.STEP_DNA_RESULT, RewardManager.STEP_KIT_RESULT: RewardManager.acknowledge_message()
			RewardManager.STEP_CARD_UNLOCKED: RewardManager.leave_unlocked_card_out()
			RewardManager.STEP_CARD_REPLACE_CHOICE:
				var cards := RewardManager.get_replaceable_cards()
				if not cards.is_empty(): RewardManager.choose_card_to_replace(cards[0])
			RewardManager.STEP_KIT_OFFER: RewardManager.use_first_aid_kit()
			RewardManager.STEP_DONE: return
	setup_errors.append("normal reward completion unavailable")

func _reach_checkpoint() -> void:
	if checkpoint == "summary": return
	RewardManager.acknowledge_summary()
	if checkpoint == "dna_choice": return
	RewardManager.choose_dna_slot("weapon")
	if checkpoint == "dna_result": return
	RewardManager.acknowledge_message()
	if RewardManager.get_step() != RewardManager.STEP_CARD_UNLOCKED:
		setup_errors.append("real level-3 unlock not reached")
		return
	if checkpoint == "unlock": return
	if checkpoint in ["replace_pending","replace_confirmed"]:
		RewardManager.incorporate_unlocked_card()
		if checkpoint == "replace_pending": return
		var cards := RewardManager.get_replaceable_cards()
		if cards.is_empty():
			setup_errors.append("no eligible card replacement")
			return
		RewardManager.choose_card_to_replace(cards[0])
		return
	RewardManager.leave_unlocked_card_out()
	if checkpoint == "kit_pending": return
	RewardManager.use_first_aid_kit()
	if checkpoint == "heal_confirmed": return
	if checkpoint == "done": RewardManager.acknowledge_message()
	else: setup_errors.append("unknown checkpoint")

func _dna_or_defeat() -> void:
	if operation == "defeat_reset":
		var actor: Enemy = null
		for candidate in stage.find_children("*","CharacterBody3D",true,false):
			if candidate is Enemy and not candidate.is_queued_for_deletion():
				actor = candidate
				break
		if actor == null:
			setup_errors.append("no defeat participant available")
			return
		player.freeze_for_combat()
		EventBus.combat_ready.emit(player,[actor])
		RunState.apply_damage_to_player(9999)
		CombatManager.end_turn()
		_snapshot("REAL_DEFEAT")
		var old_id := stage.get_instance_id()
		stage.get_node("CombatUI").restart_button.pressed.emit()
		if not await _wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.get_instance_id() != old_id): setup_errors.append("defeat restart unavailable")
		stage = get_tree().current_scene
		_quiet_fixture()
		var restarted := _snapshot("AFTER_COMBATUI_RESTART")
		if DNAManager.get_dna_amount("weapon","varkhen") != 0 or restarted.suspended or restarted.frozen or restarted.combat_ui or restarted.reward_ui: issues.append("real defeat restart incoherent")
		return
	if not await _victory(): return
	RewardManager.acknowledge_summary()
	RewardManager.choose_dna_slot("suit")
	_complete_reward()
	# Fourth actual victory confirms an unlock AND replacement, alongside suit
	# HP and weapon bonus, before testing same-run transition/reset semantics.
	if not await _victory(): return
	RewardManager.acknowledge_summary()
	RewardManager.choose_dna_slot("weapon")
	RewardManager.acknowledge_message()
	if RewardManager.get_step() != RewardManager.STEP_CARD_UNLOCKED:
		setup_errors.append("DNA persistence setup did not unlock existing card")
		return
	RewardManager.incorporate_unlocked_card()
	var cards := RewardManager.get_replaceable_cards()
	if cards.is_empty():
		setup_errors.append("DNA persistence setup lacks replacement candidate")
		return
	RewardManager.choose_card_to_replace(cards[0])
	_complete_reward()
	var before := _snapshot("DNA_EARNED_REAL_REWARDS")
	if operation in ["dna_ui_reset","dna_well_reset"]:
		var old_id := stage.get_instance_id()
		if operation == "dna_ui_reset": stage.get_node("DebugHUD").reset_button.pressed.emit()
		else: stage.get_node("Fortress6A/FortressEndUI/Panel/VBox/RestartButton").pressed.emit()
		if not await _wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.get_instance_id() != old_id): setup_errors.append("DNA caller reload unavailable")
		stage = get_tree().current_scene
		_quiet_fixture()
		var reset := _snapshot("AFTER_DNA_REAL_RESET_CALLER")
		if operation == "dna_ui_reset":
			if DNAManager.get_dna_amount("weapon","varkhen") != 0 or DNAManager.get_dna_amount("suit","varkhen") != 0 or not DNAManager.unlocked_abilities.is_empty() or reset.max_hp != RunState.base_max_player_health or reset.damage_bonus != 0: issues.append("combined UI reset leaves prior DNA bonuses")
		else:
			if reset.dna != before.dna or reset.abilities != before.abilities or reset.max_hp != before.max_hp or reset.damage_bonus != before.damage_bonus: issues.append("Well reset not coherent with retained DNA")
		return
	if operation == "dna_runstate":
		for index in 3:
			RunState.reset_run()
			var repeated := _snapshot("RUNSTATE_ONLY_RESET_%d" % index)
			if repeated.dna != before.dna or repeated.max_hp != before.max_hp or repeated.damage_bonus != before.damage_bonus: issues.append("reset_run alone unexpectedly changes/duplicates DNA bonus")
		return
	if stage.sector_run.sector_count() < 2:
		setup_errors.append("sector transition unavailable in selected real run")
		return
	await stage.advance_sector_from_debug()
	_quiet_fixture()
	var after := _snapshot("AFTER_REAL_SECTOR_TRANSITION")
	if after.dna != before.dna or after.abilities != before.abilities or after.deck != before.deck or after.hp != before.hp or after.max_hp != before.max_hp or after.damage_bonus != before.damage_bonus or after.suspended or after.frozen: issues.append("same-run sector transition corrupts progression")

func _finish() -> void:
	var classification := "INCOMPLETE" if not setup_errors.is_empty() else ("PASS" if issues.is_empty() else "FAIL")
	print("P1A_EVENTS="+JSON.stringify(events))
	print("P1A_RESULT="+JSON.stringify({"operation":operation,"checkpoint":checkpoint,"classification":classification,"issues":issues,"setup_errors":setup_errors,"snapshots":snapshots,"signals":events.size(),"production_modified":false,"rollback_asserted":false}))
	get_tree().quit(2 if classification == "INCOMPLETE" else (0 if classification == "PASS" else 1))
