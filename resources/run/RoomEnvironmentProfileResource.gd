extends Resource
class_name RoomEnvironmentProfileResource

## Opt-in physical dressing, not a topology/content-population rule.
@export var stable_id: StringName
@export_range(0, 5) var room_light_addition := 2
@export var cover_family_by_semantic: Dictionary = {}
## Empty keeps the B box presentation/selection unchanged.
@export var cover_variants: Array[RoomCoverVariantResource] = []
@export var excluded_semantic_ids: Array[StringName] = []
@export var max_covers_per_room := 2
## Keep a full cross clear: door half-width 1.2 + baked agent radius 0.55.
@export var protected_axis_half_width_m := 1.8
@export var wall_margin_m := 0.35
@export var cover_size_high := Vector3(1.6, 2.0, 1.2)
@export var cover_size_medium := Vector3(1.8, 1.1, 0.9)
@export var corner_fraction := 0.32

## Opt-in replacement positions, not additional furniture. Dictionaries use
## semantic/id/position_fraction (local XZ divided by the real footprint).
## Empty preserves legacy positions. Existing room budget/category RNG survives.
## Optional category/index select an existing furniture slot, not extra props.
@export var room_cover_candidates: Array[Dictionary] = []

## Opt-in distribution props. Each dictionary declares id, semantic, role and
## position_fraction (local XZ / actual footprint). Empty is legacy-inert.
## These candidates reuse MEDIUM variants and all existing physical reserves.
@export var distribution_cover_candidates: Array[Dictionary] = []
@export_range(0, 1) var distribution_cover_probability := 0.0
@export_range(0, 2) var max_covers_per_distribution := 0
