extends CanvasLayer

## RewardUI.gd
## Pantalla de recompensa post-combate. Solo LEE el estado de RewardManager
## y llama a sus métodos de acción — ninguna regla de recompensa vive acá
## (mismo patrón que CombatUI con CombatManager).
##
## Como CombatUI, los contenedores/fondo son transparentes al input
## (mouse_filter = IGNORE) para que la cámara pueda seguir mirándose
## libremente aunque el jugador esté inmóvil durante esta pantalla.

const MAX_REPLACE_SLOTS: int = 10

@onready var root: Control = $Root

@onready var summary_panel: Control = $Root/SummaryPanel
@onready var summary_label: Label = $Root/SummaryPanel/SummaryLabel
@onready var summary_continue_button: Button = $Root/SummaryPanel/ContinueButton

@onready var dna_choice_panel: Control = $Root/DNAChoicePanel
@onready var species_label: Label = $Root/DNAChoicePanel/SpeciesLabel
@onready var weapon_button: Button = $Root/DNAChoicePanel/WeaponButton
@onready var shield_button: Button = $Root/DNAChoicePanel/ShieldButton
@onready var suit_button: Button = $Root/DNAChoicePanel/SuitButton

@onready var message_panel: Control = $Root/MessagePanel
@onready var message_label: Label = $Root/MessagePanel/MessageLabel
@onready var continue_button: Button = $Root/MessagePanel/ContinueButton

@onready var card_unlocked_panel: Control = $Root/CardUnlockedPanel
@onready var card_unlocked_label: Label = $Root/CardUnlockedPanel/CardUnlockedLabel
@onready var incorporate_button: Button = $Root/CardUnlockedPanel/IncorporateButton
@onready var leave_out_button: Button = $Root/CardUnlockedPanel/LeaveOutButton

@onready var card_replace_panel: Control = $Root/CardReplacePanel
@onready var card_replace_title: Label = $Root/CardReplacePanel/TitleLabel
@onready var replace_slots_container: VBoxContainer = $Root/CardReplacePanel/ReplaceSlotsContainer

@onready var kit_offer_panel: Control = $Root/KitOfferPanel
@onready var use_kit_button: Button = $Root/KitOfferPanel/UseKitButton
@onready var decline_kit_button: Button = $Root/KitOfferPanel/DeclineKitButton

var _replace_slot_buttons: Array = []


func _ready() -> void:
	visible = false
	_hide_all_panels()

	summary_continue_button.pressed.connect(func(): RewardManager.acknowledge_summary())
	weapon_button.pressed.connect(func(): RewardManager.choose_dna_slot("weapon"))
	shield_button.pressed.connect(func(): RewardManager.choose_dna_slot("shield"))
	suit_button.pressed.connect(func(): RewardManager.choose_dna_slot("suit"))
	continue_button.pressed.connect(func(): RewardManager.acknowledge_message())
	incorporate_button.pressed.connect(func(): RewardManager.incorporate_unlocked_card())
	leave_out_button.pressed.connect(func(): RewardManager.leave_unlocked_card_out())
	use_kit_button.pressed.connect(func(): RewardManager.use_first_aid_kit())
	decline_kit_button.pressed.connect(func(): RewardManager.decline_first_aid_kit())

	for i in MAX_REPLACE_SLOTS:
		var slot_button: Button = replace_slots_container.get_child(i)
		slot_button.pressed.connect(_on_replace_slot_pressed.bind(i))
		_replace_slot_buttons.append(slot_button)

	RewardManager.reward_sequence_started.connect(_on_sequence_started)
	RewardManager.reward_step_changed.connect(_on_step_changed)
	RewardManager.reward_sequence_finished.connect(_on_sequence_finished)


func _hide_all_panels() -> void:
	summary_panel.visible = false
	dna_choice_panel.visible = false
	message_panel.visible = false
	card_unlocked_panel.visible = false
	card_replace_panel.visible = false
	kit_offer_panel.visible = false


func _on_sequence_started() -> void:
	visible = true


func _on_sequence_finished() -> void:
	visible = false


func _on_step_changed() -> void:
	var step: String = RewardManager.get_step()
	_hide_all_panels()

	match step:
		RewardManager.STEP_SUMMARY:
			summary_panel.visible = true
			summary_label.text = "\n".join(RewardManager.get_summary_lines())

		RewardManager.STEP_DNA_CHOICE:
			dna_choice_panel.visible = true
			species_label.text = "%s obtenido\n¿Dónde lo aplicás?" % RewardManager.get_current_species_label()

		RewardManager.STEP_DNA_RESULT, RewardManager.STEP_KIT_RESULT:
			message_panel.visible = true
			message_label.text = RewardManager.get_last_message()

		RewardManager.STEP_CARD_UNLOCKED:
			card_unlocked_panel.visible = true
			card_unlocked_label.text = RewardManager.get_unlocked_card_description()

		RewardManager.STEP_CARD_REPLACE_CHOICE:
			card_replace_panel.visible = true
			card_replace_title.text = "Elegí una carta de %s para reemplazar:" % RewardManager.get_unlocked_card_category_label()
			_refresh_replace_slots()

		RewardManager.STEP_KIT_OFFER:
			kit_offer_panel.visible = true


func _refresh_replace_slots() -> void:
	var replaceable: Array = RewardManager.get_replaceable_cards()
	for i in _replace_slot_buttons.size():
		var slot_button: Button = _replace_slot_buttons[i]
		if i < replaceable.size():
			slot_button.visible = true
			slot_button.text = replaceable[i].card_name
		else:
			slot_button.visible = false


func _on_replace_slot_pressed(index: int) -> void:
	var replaceable: Array = RewardManager.get_replaceable_cards()
	if index < 0 or index >= replaceable.size():
		return
	RewardManager.choose_card_to_replace(replaceable[index])
