extends "res://scripts/tests/core_p1a_reward_diagnostic.gd"

var finishes := 0
var previous_back := true

func _check(ok: bool, label: String) -> void:
	print("P1C_CHECK %s %s" % [ok,label])
	if not ok: issues.append(label)

func _skip() -> bool:
	return RewardManager.skip_optional_reward(RewardManager.get_sequence_id(),RewardManager.get_decision_id())

func _pending(label: String) -> void:
	_check(RewardManager.is_reward_active() and player.is_frozen and ExplorationState.is_suspended() and stage.get_node("RewardUI").visible,label)

func _done(expected_finishes: int) -> void:
	_check(not RewardManager.is_reward_active() and RewardManager.get_step() == RewardManager.STEP_DONE and not player.is_frozen and not ExplorationState.is_suspended() and not stage.get_node("RewardUI").visible,"complete sequence releases exploration")
	_check(finishes == expected_finishes and RewardManager.get_last_close_result().kind == "completed","one normal terminal, not technical abort")
	_check(get_tree().quit_on_go_back == previous_back,"BACK policy restored")

func _run() -> void:
	previous_back = get_tree().quit_on_go_back
	stage = FORTRESS.instantiate()
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	_quiet_fixture()
	roll_seed = 5
	RewardManager.reward_sequence_finished.connect(func(): finishes += 1)
	if operation in ["card_skip","replace_skip"]:
		for index in 2:
			if not await _victory():
				_finish()
				return
			_complete_reward()
	if not await _victory():
		_finish()
		return
	var expected_finishes := finishes+1
	var id := RewardManager.get_sequence_id()
	var hp_before := RunState.player_health
	var dna_before := DNAManager.get_dna_amount("weapon","varkhen")
	_check(not _skip() and RewardManager.get_step() == RewardManager.STEP_SUMMARY,"summary is acknowledgement, not optional effect")
	RewardManager.acknowledge_summary()
	_pending("decision retains UI/freeze/suspension")
	match operation:
		"accept":
			_complete_reward()
			_check(DNAManager.get_dna_amount("weapon","varkhen") == dna_before+1 and RunState.player_health == RunState.max_player_health,"accept DNA and healing once")
			_done(expected_finishes)
		"skip", "skip_accept", "skip_all":
			_check(_skip(),"skip current DNA")
			_pending("skip one decision does not end sequence")
			_check(DNAManager.get_dna_amount("weapon","varkhen") == dna_before and RewardManager.get_step() == RewardManager.STEP_KIT_OFFER,"pending DNA not applied, next kit offered")
			if operation == "skip_accept":
				RewardManager.use_first_aid_kit()
				RewardManager.acknowledge_message()
				_check(RunState.player_health == RunState.max_player_health,"accept following kit")
			else:
				_check(_skip(),"skip final kit")
				_check(RunState.player_health == hp_before,"omitted kit does not heal")
			_done(expected_finishes)
		"accept_skip", "abort_after_skip":
			RewardManager.choose_dna_slot("weapon")
			RewardManager.acknowledge_message()
			_check(_skip(),"skip kit after confirmed DNA")
			_check(DNAManager.get_dna_amount("weapon","varkhen") == dna_before+1 and RunState.player_health == hp_before,"confirmed DNA retained, omitted kit no HP")
			_done(expected_finishes)
			if operation == "abort_after_skip":
				_check(not RewardManager.abort_reward_sequence("after_normal_skip",id) and finishes == expected_finishes,"abort after final omission is no-op")
		"card_skip", "replace_skip":
			RewardManager.choose_dna_slot("weapon")
			RewardManager.acknowledge_message()
			_check(RewardManager.get_step() == RewardManager.STEP_CARD_UNLOCKED,"real level-3 unlock offered")
			if operation == "replace_skip": RewardManager.incorporate_unlocked_card()
			var ui: Node = stage.get_node("RewardUI")
			var path := "Root/CardReplacePanel/SkipButton" if operation == "replace_skip" else "Root/CardUnlockedPanel/LeaveOutButton"
			var button: Button = ui.get_node(path)
			_check(button.text == "OMITIR" and button.is_visible_in_tree(),"visible card omission control")
			button.pressed.emit()
			_check(RewardManager.get_step() == RewardManager.STEP_KIT_OFFER and DNAManager.get_dna_amount("weapon","varkhen") == 3 and DNAManager.unlocked_abilities.get("weapon:varkhen:3",false),"skip card retains confirmed DNA/unlock")
			var heavy := 0
			for card in RunState.get_full_card_pool():
				if card.card_name == "Golpe Pesado": heavy += 1
			_check(heavy == 0 and RunState.get_full_card_pool().size() == 10,"omitted card not added/replaced")
			_check(_skip(),"finish by omitting kit")
			_done(expected_finishes)
		"repeat":
			var token := RewardManager.get_decision_id()
			_check(RewardManager.skip_optional_reward(id,token),"first skip accepted")
			for count in 8: _check(not RewardManager.skip_optional_reward(id,token),"repeated token cannot skip following kit")
			_pending("repeated request leaves next choice pending")
			_check(_skip(),"fresh token resolves following kit")
			_done(expected_finishes)
			# Explicit manager boundary: two real resource species, same STEP.
			player.freeze_for_combat()
			var species: String = load("res://resources/enemies/orco_melee.tres").species_id
			RewardManager.start_reward_sequence([species,species],player)
			RewardManager.acknowledge_summary()
			id = RewardManager.get_sequence_id()
			token = RewardManager.get_decision_id()
			_check(RewardManager.skip_optional_reward(id,token) and RewardManager.get_step() == RewardManager.STEP_DNA_CHOICE,"one of two identical DNA choices omitted")
			_check(not RewardManager.skip_optional_reward(id,token) and RewardManager._pending_dna_species.size() == 1,"same-step replay rejected")
			RewardManager.abort_reward_sequence("fixture_cleanup")
		"repeat_ui":
			var button: Button = stage.get_node("RewardUI/Root/DNAChoicePanel/SkipButton")
			_check(button.text == "OMITIR" and button.is_visible_in_tree(),"DNA skip visible")
			for count in 8: button.pressed.emit()
			_check(RewardManager.get_step() == RewardManager.STEP_KIT_OFFER,"repeated synchronous UI signals resolve only one step")
			_pending("UI repeats cannot resume exploration")
			await get_tree().process_frame
			stage.get_node("RewardUI/Root/KitOfferPanel/DeclineKitButton").pressed.emit()
			_done(expected_finishes)
		"back_escape":
			_check(not get_tree().quit_on_go_back,"Android BACK cannot quit during reward")
			var mouse_before := Input.mouse_mode
			var cancel := InputEventAction.new()
			cancel.action = "ui_cancel"
			cancel.pressed = true
			Input.parse_input_event(cancel)
			stage.get_node("RewardUI").notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			await get_tree().process_frame
			_pending("ESC/BACK preserve unresolved choice")
			_check(Input.mouse_mode == mouse_before and RewardManager.get_step() == RewardManager.STEP_DNA_CHOICE,"cancel consumed, no action/abort")
			# Movement request during a real reward, with real Player physics.
			player.set_physics_process(true)
			var position_before := player.global_position
			Input.action_press("move_forward")
			for frame in 4: await get_tree().physics_frame
			Input.action_release("move_forward")
			_check(player.global_position.distance_to(position_before) < 0.01,"movement input cannot return to exploration")
			_complete_reward()
			_done(expected_finishes)
		"abort_choice", "abort_pending_after_skip":
			if operation == "abort_pending_after_skip": _check(_skip(),"omit DNA before technical reset")
			_check(RewardManager.abort_reward_sequence("test_technical",id),"technical abort accepted")
			_check(RewardManager.get_last_close_result().kind == "cancelled" and finishes == expected_finishes and not RewardManager.is_reward_active() and not player.is_frozen and not ExplorationState.is_suspended(),"technical abort retains P1-B terminal contract")
			_check(DNAManager.get_dna_amount("weapon","varkhen") == dna_before and RunState.player_health == hp_before,"pending effects not applied by abort")
			_check(get_tree().quit_on_go_back == previous_back,"abort restores BACK policy")
		"new_reward":
			_check(_skip() and _skip(),"finish first by individual omissions")
			_done(expected_finishes)
			if await _victory():
				_check(RewardManager.get_sequence_id() > id,"new reward owns new sequence")
				_complete_reward()
				_done(expected_finishes+1)
				_check(DNAManager.get_dna_amount("weapon","varkhen") == dna_before+1,"only accepted reward grants DNA")
		_:
			setup_errors.append("unknown P1-C case")
	print("P1C_RESULT="+JSON.stringify({"case":operation,"valid":issues.is_empty() and setup_errors.is_empty(),"issues":issues,"setup_errors":setup_errors,"finishes":finishes}))
	_finish()
