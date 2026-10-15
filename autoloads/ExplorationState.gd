extends Node

## Logical suspension; actors and their physics bodies stay registered.
## Card UI, combat/reward managers, rendering and the SceneTree remain active.
var _combat := false
var _reward := false
var _positioning := false
var _suspended := false
var _actors := {}

func _ready() -> void:
	CombatManager.combat_started.connect(func(): _combat = true; _refresh())
	CombatManager.combat_ended.connect(func(): _combat = false; _refresh())
	RewardManager.reward_sequence_started.connect(func(): _reward = true; _refresh())
	RewardManager.reward_sequence_finished.connect(func(): _reward = false; _refresh())
	register_actor(CombatEncounterManager)

func is_suspended() -> bool:
	return _suspended

## Only the encounter coordinator and its owned actors may advance physical
## presentation. Perception, patrols and unrelated exploration remain paused.
func can_update_positioning(actor: Node) -> bool:
	return _positioning and not _combat and not _reward and (actor == CombatEncounterManager or (actor.has_method("has_combat_positioning") and actor.has_combat_positioning()))

func set_encounter_positioning(active: bool) -> void:
	_positioning = active
	_refresh()

func register_actor(actor: Node) -> void:
	_prune_invalid_actors()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion(): return
	var id := actor.get_instance_id()
	# The deferred callback binds only an ID, never a strong actor reference.
	# A temporary detach is not destruction; dead-only cleanup preserves it.
	var retired := _remove_invalid_actor.bind(id)
	if not actor.tree_exited.is_connected(retired):
		actor.tree_exited.connect(retired,CONNECT_DEFERRED)
	# Repeated registration must not overwrite original timer pause ownership.
	if not _actors.has(id):
		_actors[id] = {"ref":weakref(actor),"since":-1,"timers":[]}
	if _suspended: _pause_actor(_actors[id])

func _remove_invalid_actor(id: int) -> void:
	if _actors.has(id) and _actors[id].ref.get_ref() == null:
		_actors.erase(id)

func _prune_invalid_actors() -> void:
	for id in _actors.keys(): _remove_invalid_actor(id)

func reset_for_regeneration() -> void:
	_combat = false
	_reward = false
	_positioning = false
	_refresh()

func _pause_actor(entry: Dictionary) -> void:
	var actor: Node = entry.ref.get_ref()
	if actor == null or entry.since >= 0: return
	entry.since = Time.get_ticks_msec()
	if actor is CharacterBody3D: actor.velocity = Vector3.ZERO
	# Timer.paused preserves the remaining timeout without unregistering bodies.
	entry.timers = []
	for timer: Timer in actor.find_children("*", "Timer", true, false):
		entry.timers.append({"ref":weakref(timer),"paused":timer.paused})
		timer.paused = true

func _refresh() -> void:
	# Housekeeping is independent of transitions and cannot release an owner.
	_prune_invalid_actors()
	var next := _combat or _reward or _positioning
	if next == _suspended: return
	_suspended = next
	for id in _actors.keys():
		var entry: Dictionary = _actors[id]
		var actor: Node = entry.ref.get_ref()
		if actor == null:
			_actors.erase(id)
			continue
		if _suspended:
			_pause_actor(entry)
		elif entry.since >= 0:
			if actor.has_method("on_exploration_resumed"):
				actor.on_exploration_resumed(Time.get_ticks_msec()-entry.since)
			for saved: Dictionary in entry.timers:
				var timer: Timer = saved.ref.get_ref()
				if timer != null: timer.paused = saved.paused
			entry.timers = []
			entry.since = -1
