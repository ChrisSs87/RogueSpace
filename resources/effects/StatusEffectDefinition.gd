extends Resource
class_name StatusEffectDefinition

enum ReapplyPolicy { NO_STACK, ADD_STACK, REFRESH_DURATION }
enum TurnOperation { NONE, DAMAGE, BLOCK }
@export var effect_id: StringName
@export var display_name := ""
@export var tags: Array[StringName] = []
@export var positive := false
@export var base_duration_turns := 1
@export var magnitude := 0
@export var max_stacks := 1
@export var reapply_policy := ReapplyPolicy.NO_STACK
@export var turn_start_operation := TurnOperation.NONE
@export var dispellable := true
