extends Resource
class_name LoadoutResource

## Fuente data-driven de cartas iniciales. Armas, ADN y equipo pueden aportar
## loadouts o modificar esta lista sin que CombatManager conozca su origen.
@export var loadout_id: StringName
@export var display_name: String = "Loadout"
@export var starting_cards: Array[CardResource] = []
@export var initial_draw_count: int = 4
@export var deck_size: int = 10
@export var primary_weapon: WeaponResource
@export var secondary_weapon: WeaponResource
@export var fallback_cards: Array[CardResource] = []
@export var active_artifacts: Array[ArtifactResource] = []

func uses_modular_composition() -> bool:
	return primary_weapon != null or secondary_weapon != null or not fallback_cards.is_empty()

func compose_starting_deck() -> Array[CardResource]:
	if not uses_modular_composition():
		return starting_cards.duplicate()
	var result: Array[CardResource] = []
	if primary_weapon != null:
		result.append_array(primary_weapon.contributed_cards.slice(0, deck_size))
	if primary_weapon == null or primary_weapon.allows_secondary:
		if secondary_weapon != null and result.size() < deck_size:
			result.append_array(secondary_weapon.contributed_cards.slice(0, deck_size - result.size()))
	var index := 0
	while result.size() < deck_size and not fallback_cards.is_empty():
		result.append(fallback_cards[index % fallback_cards.size()])
		index += 1
	return result
