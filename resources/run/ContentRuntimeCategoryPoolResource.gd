extends Resource
class_name ContentRuntimeCategoryPoolResource

## Asociacion declarativa entre una categoria de Content Placement y sus
## candidatos runtime. El consumidor concreto decide que tipos de payload
## comprende; este Resource no conoce enemigos ni archetypes.
@export var category: StringName
@export var pool: WeightedPoolResource
