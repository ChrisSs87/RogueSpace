extends CanvasLayer

## TouchControls.gd — Etapa 1.5
## Controles táctiles básicos para Android. NO reemplaza el mouse/teclado de PC:
## Player.gd los sigue leyendo igual que antes, y este nodo solo AGREGA su aporte
## si está presente en la escena y hay una pantalla táctil disponible.
##
## Esquema (estándar en shooters mobile, sin necesidad de assets):
## - Mitad izquierda de la pantalla: tocar y arrastrar = joystick virtual (moverse).
## - Mitad derecha de la pantalla: tocar y arrastrar = mirar alrededor (como el mouse).

@export var joystick_radius: float = 80.0

# Valores que Player.gd lee/consume cada frame. No se tocan desde afuera.
var move_input: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO

@onready var joystick_bg: Control = $JoystickBackground
@onready var joystick_knob: Control = $JoystickBackground/JoystickKnob
@onready var mode_button: Button = $ModeButton

var _joystick_touch_index: int = -1
var _look_touch_index: int = -1
var _combat_active: bool = false


func _ready() -> void:
	add_to_group("touch_controls")

	# DisplayServer.is_touchscreen_available() puede dar falso negativo en
	# algunos dispositivos/builds de Android (problema conocido de Godot,
	# sobre todo si se consulta muy temprano en el arranque). OS.get_name()
	# es la señal más confiable de "estamos corriendo en Android", así que
	# alcanza con que CUALQUIERA de las dos sea true para mostrar los
	# controles. En PC ninguna lo es, así que el nodo se sigue ocultando.
	var is_android: bool = OS.get_name() == "Android"
	var has_touchscreen: bool = DisplayServer.is_touchscreen_available()
	visible = is_android or has_touchscreen
	set_process_unhandled_input(visible)
	mode_button.pressed.connect(_on_mode_button_pressed)

	_reset_knob()
	set_movement_mode_label("WALK")


func _on_mode_button_pressed() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("cycle_mobile_movement_mode"):
		player.cycle_mobile_movement_mode()


func set_movement_mode_label(mode_label: String) -> void:
	mode_button.text = mode_label


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var screen_width: float = get_viewport().get_visible_rect().size.x
	var is_left_side: bool = event.position.x < screen_width / 2.0

	if event.pressed:
		if is_left_side and not _combat_active and _joystick_touch_index == -1:
			_joystick_touch_index = event.index
			_update_joystick(event.position)
		elif not is_left_side and _look_touch_index == -1:
			_look_touch_index = event.index
	else:
		if event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			move_input = Vector2.ZERO
			_reset_knob()
		elif event.index == _look_touch_index:
			_look_touch_index = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_index:
		_update_joystick(event.position)
	elif event.index == _look_touch_index:
		look_delta += event.relative


func _update_joystick(touch_position: Vector2) -> void:
	var center: Vector2 = joystick_bg.global_position + joystick_bg.size / 2.0
	var offset: Vector2 = (touch_position - center).limit_length(joystick_radius)
	joystick_knob.position = joystick_bg.size / 2.0 - joystick_knob.size / 2.0 + offset
	# Godot mide Y positivo hacia abajo en pantalla, y Player.gd espera que Y positivo
	# signifique "atrás" (igual que move_back en el teclado) — coinciden, no hay que invertir.
	move_input = offset / joystick_radius


func _reset_knob() -> void:
	joystick_knob.position = joystick_bg.size / 2.0 - joystick_knob.size / 2.0


func consume_look_delta() -> Vector2:
	# Player.gd llama a esto una vez por frame; el valor se resetea después de leerlo,
	# igual que pasa con el "relative" del mouse en PC.
	var delta: Vector2 = look_delta
	look_delta = Vector2.ZERO
	return delta


## Llamado por Player.gd al entrar/salir de combate. Bloquea ÚNICAMENTE el
## joystick de movimiento (mitad izquierda): la mirada (mitad derecha) sigue
## funcionando exactamente igual que en exploración, porque durante combate
## el jugador no puede desplazarse pero sí puede seguir mirando libremente.
func set_combat_active(active: bool) -> void:
	_combat_active = active
	if active and _joystick_touch_index != -1:
		_joystick_touch_index = -1
		move_input = Vector2.ZERO
		_reset_knob()
