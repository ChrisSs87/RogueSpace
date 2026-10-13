extends "res://scripts/tests/core_p1a_reward_diagnostic.gd"

var finished := 0
var started := 0

func _check(ok: bool, label: String) -> void:
	if not ok: issues.append(label)
	print("P1B_ABORT_CHECK %s %s" % [ok,label])

func _clean() -> bool:
	return not RewardManager.is_reward_active() and RewardManager.get_step() == RewardManager.STEP_DONE and RewardManager._player == null and RewardManager._pending_dna_species.is_empty() and RewardManager._pending_unlocked_card == null and not RewardManager._kit_offer_pending

func _effects() -> String:
	var cards: Array = []
	for card in RunState.get_full_card_pool(): cards.append(card.resource_path)
	cards.sort()
	return var_to_str([DNAManager.dna,DNAManager.unlocked_abilities,RunState.player_health,cards])

func _run() -> void:
	stage = FORTRESS.instantiate()
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	_quiet_fixture()
	roll_seed = 5 # Same naturally possible, unmodified .10 kit probability as P1-A.
	RewardManager.reward_sequence_finished.connect(func(): finished += 1)
	RewardManager.reward_sequence_started.connect(func(): started += 1)
	if operation == "confirmed_pending":
		for index in 2:
			if not await _victory():
				_finish()
				return
			_complete_reward()
	if not await _victory():
		_finish()
		return
	var id := RewardManager.get_sequence_id()
	var baseline_finishes := finished
	var initial_effects := _effects()
	match operation:
		"abort_repeat", "finish_after_abort":
			_check(RewardManager.abort_reward_sequence("test_abort",id),"first abort accepted")
			var terminal := RewardManager.get_last_close_result()
			_check(not RewardManager.abort_reward_sequence("duplicate",id),"repeat abort no-op")
			RewardManager.acknowledge_summary()
			RewardManager.choose_dna_slot("weapon")
			RewardManager.acknowledge_message()
			RewardManager.use_first_aid_kit()
			# White-box terminal race only: this does NOT fabricate a reward.
			RewardManager._finish()
			_check(_clean() and finished == baseline_finishes+1 and RewardManager.get_last_close_result() == terminal,"completion after abort cannot close twice")
			_check(_effects() == initial_effects,"pending DNA/kit not applied")
		"abort_after_finish":
			_complete_reward()
			var terminal := RewardManager.get_last_close_result()
			var confirmed := _effects()
			_check(not RewardManager.abort_reward_sequence("too_late",id),"abort after normal finish no-op")
			RewardManager._finish()
			_check(_clean() and finished == baseline_finishes+1 and terminal.kind == "completed" and RewardManager.get_last_close_result() == terminal and _effects() == confirmed,"normal closure remains completed once")
		"player_destroyed":
			player.queue_free()
			await get_tree().process_frame
			await get_tree().physics_frame
			_check(_clean() and finished == baseline_finishes+1 and RewardManager.get_last_close_result().reason == "player_exiting","Player tree exit cancels and clears reference")
			_check(not stage.get_node("RewardUI").visible and not ExplorationState.is_suspended(),"departing Player releases only reward suspension")
		"ui_destroyed":
			stage.get_node("RewardUI").queue_free()
			await get_tree().process_frame
			_check(_clean() and finished == baseline_finishes+1 and RewardManager.get_last_close_result().reason == "reward_ui_exiting","UI tree exit cancels its sequence")
			_check(not player.is_frozen and not ExplorationState.is_suspended(),"remaining Player resumes after UI loss")
		"scene_change":
			var previous := stage.get_instance_id()
			get_tree().change_scene_to_file("res://scenes/MainFortress6A.tscn")
			_check(await _wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.get_instance_id() != previous),"real scene change completed")
			stage = get_tree().current_scene
			_quiet_fixture()
			_check(_clean() and finished == baseline_finishes+1 and not stage.get_node("RewardUI").visible and not ExplorationState.is_suspended() and not player.is_frozen,"generic scene replacement cancels through owner exit")
		"new_reward":
			RewardManager.abort_reward_sequence("old",id)
			if await _victory():
				_check(RewardManager.get_sequence_id() > id and RewardManager.is_reward_active() and stage.get_node("RewardUI").visible,"new UI/reward opens after cancellation")
				_check(not RewardManager.abort_reward_sequence("stale_owner",id) and RewardManager.is_reward_active(),"stale callback cannot cancel new sequence")
				_complete_reward()
				_check(finished == baseline_finishes+2 and DNAManager.get_dna_amount("weapon","varkhen") == 1 and _clean(),"only new reward applies once")
		"confirmed_pending":
			RewardManager.acknowledge_summary()
			RewardManager.choose_dna_slot("weapon")
			var confirmed := _effects()
			_check(DNAManager.get_dna_amount("weapon","varkhen") == 3 and DNAManager.unlocked_abilities.get("weapon:varkhen:3",false),"real DNA/unlock confirmed")
			RewardManager.abort_reward_sequence("keep_confirmed",id)
			RewardManager.incorporate_unlocked_card()
			RewardManager.use_first_aid_kit()
			_check(_effects() == confirmed and _clean() and finished == baseline_finishes+1,"confirmed effects kept; pending card/kit discarded")
		"foreign_combat":
			var actor: Enemy = null
			for node in stage.find_children("*","CharacterBody3D",true,false):
				if node is Enemy and not node.is_queued_for_deletion(): actor = node; break
			player.freeze_for_combat()
			EventBus.combat_ready.emit(player,[actor])
			RewardManager.abort_reward_sequence("own_reward_only",id)
			_check(_clean() and ExplorationState._combat and not ExplorationState._reward and ExplorationState.is_suspended() and player.is_frozen and CombatManager.get_combatant_count() == 1,"foreign combat and freeze remain owned")
			CombatManager.reset_after_defeat()
			player.unfreeze_after_combat()
		"close_races":
			RewardManager.reward_sequence_finished.connect(func():
				_check(not RewardManager.abort_reward_sequence("during_terminal"),"terminal listener abort no-op"))
			_complete_reward()
			_check(finished == baseline_finishes+1 and _clean(),"normal finish vs synchronous abort closes once")
			if await _victory():
				var second_id := RewardManager.get_sequence_id()
				var abort_dna := func(_slot,_species,_amount): RewardManager.abort_reward_sequence("during_dna_signal",second_id)
				DNAManager.dna_changed.connect(abort_dna,CONNECT_ONE_SHOT)
				RewardManager.acknowledge_summary()
				RewardManager.choose_dna_slot("weapon")
				_check(_clean() and finished == baseline_finishes+2 and DNAManager.get_dna_amount("weapon","varkhen") == 2,"DNA signal abort cannot resurrect pending UI")
			RewardManager.reward_sequence_started.connect(func(): RewardManager.abort_reward_sequence("during_start"),CONNECT_ONE_SHOT)
			# Entry callback cancels synchronously: exercise manager initialization,
			# not _victory's expectation that SUMMARY will remain visible.
			player.freeze_for_combat()
			RewardManager.start_reward_sequence(["varkhen"],player)
			_check(_clean() and finished == baseline_finishes+3 and not stage.get_node("RewardUI").visible,"started listener abort remains terminal")
		_:
			setup_errors.append("unknown abort contract case")
	print("P1B_ABORT_RESULT="+JSON.stringify({"case":operation,"valid":issues.is_empty() and setup_errors.is_empty(),"issues":issues,"setup_errors":setup_errors,"started":started,"finished":finished,"terminal":RewardManager.get_last_close_result()}))
	_finish()
