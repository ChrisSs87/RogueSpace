extends Resource
class_name SuitResource

## SuitResource.gd
## Datos del traje equipado. Por ahora es un placeholder: el traje inicial
## no tiene stats base propios (el HP base del jugador sigue viviendo en
## RunState.base_max_player_health, un valor de diseño ya definido — no lo
## muevo acá para no reestructurar algo que ya estaba decidido y funcionando
## por un cambio que este checkpoint no pide).
##
## Lo que SÍ hace el traje en este checkpoint: el ADN aplicado en "suit" le
## suma HP máximo (ver DNAManager.get_suit_max_health_bonus(), consultado
## por RunState). Campos de crítico/veneno/resistencia del traje llegan en
## un checkpoint posterior, cuando esos sistemas existan.

@export var suit_name: String = "Traje"
