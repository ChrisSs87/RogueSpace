extends CanvasLayer

## Local manual-test composition; does not alter the shared debug HUD or run rules.
@onready var stage = get_parent()
@onready var info: Label = $Panel/Info
@onready var new_seed: Button = $Panel/Buttons/NewSeed
@onready var next_sector: Button = $Panel/Buttons/NextSector
var busy := false


func _ready() -> void:
	stage.get_node("DebugHUD/Root/ButtonsContainer").hide()
	new_seed.pressed.connect(_new_seed)
	next_sector.pressed.connect(_next_sector)


func _process(_delta: float) -> void:
	if stage.sector_run == null:
		return
	var index: int = stage.current_sector_index
	var size_id: StringName = stage.sector_run.sector_size_profiles[index].size_id
	info.text = "VARKHEM V2.1 | %s | SEED %d\nSECTOR %d/%d | EFFECTIVE %d | ATTEMPT %d\nCOMMAND ROOM: future objective; EXIT not gated" % [size_id, stage.seed, index + 1, stage.sector_run.sector_count(), stage.sector_effective_seed, stage.sector_retry_index]
	new_seed.disabled = busy or not stage.nav_ready
	next_sector.disabled = busy or not stage.nav_ready or index >= stage.sector_run.sector_count() - 1


func _new_seed() -> void:
	if busy:
		return
	busy = true
	await stage.regenerate_from_debug()
	busy = false


func _next_sector() -> void:
	if busy:
		return
	busy = true
	await stage.advance_sector_from_debug()
	busy = false
