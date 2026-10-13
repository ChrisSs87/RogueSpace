extends "res://scripts/tests/core_p1a_reward_diagnostic.gd"

## Same 26 scenarios, physical setup, real callers and effects as P1-A.
## Stronger terminal contract: no pending reward/ref/ownership after interrupt.
func _validate_interruption(before: Dictionary, after: Dictionary) -> void:
	if RewardManager.is_reward_active() or after.step != RewardManager.STEP_DONE: issues.append("reward remains active after interruption")
	if after.reward_player_valid or after.reward_player_text != "<null>": issues.append("reward Player reference not cleared")
	if not after.pending_dna.is_empty() or not after.pending_card.is_empty() or after.pending_kit: issues.append("pending choices survived cancellation")
	if after.reward_ui or after.combat_ui or after.suspended or after.frozen or after.combatants != 0 or after.encounter_active or after.encounter_pending != 0: issues.append("interruption leaves UI/freeze/ownership active")
	var finished := 0
	for event: Dictionary in events.slice(before.signal_count):
		if event.event == "reward_finished": finished += 1
	if finished != (0 if checkpoint == "done" else 1): issues.append("terminal signal missing or duplicated")
	var terminal := RewardManager.get_last_close_result()
	if terminal.get("kind") != ("completed" if checkpoint == "done" else "cancelled"): issues.append("normal completion/cancellation not distinguished")
	if operation == "regen":
		if before.dna != after.dna or before.abilities != after.abilities or before.deck != after.deck or before.hp != after.hp: issues.append("regeneration changed confirmed effects or applied pending reward")
	elif operation == "run_reset":
		if DNAManager.get_dna_amount("weapon","varkhen") != 0 or not after.abilities.is_empty() or after.damage_bonus != 0: issues.append("full DebugHUD reset semantics changed")
	elif operation == "well_reset":
		if before.dna != after.dna or before.abilities != after.abilities or before.damage_bonus != after.damage_bonus: issues.append("Well DNA preservation changed")
	if after.max_hp != after.derived_max_hp: issues.append("derived HP inconsistent with DNA")
	print("P1B_TERMINAL="+JSON.stringify({"result":terminal,"finish_signals":finished,"active":RewardManager.is_reward_active()}))

func _finish() -> void:
	print("P1B_STATUS="+JSON.stringify({"operation":operation,"checkpoint":checkpoint,"terminal":RewardManager.get_last_close_result(),"issues":issues,"setup_errors":setup_errors}))
	super._finish()
