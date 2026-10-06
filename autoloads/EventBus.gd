extends Node

## EventBus.gd (autoload)
## Canal de señales compartido para que los sistemas se comuniquen sin
## conocerse directamente entre sí. El sistema de combate (cartas) se
## conectará acá más adelante sin tener que tocar este archivo.

## Se emite la primera vez que un enemigo confirma al jugador y arranca una
## persecución real (entra en CHASE) — un "me vieron", no necesariamente
## termina en combate armado (el jugador todavía podría perderlo). Distinta
## a propósito de combat_ready: hoy no dispara ningún efecto, queda
## preparada para un aviso/sonido sutil de detección más adelante, separado
## del aviso de "entrando en fase de combate".
signal enemy_detected(enemy: Node3D)

## Evento de exploración: el Player emite un ruido real mientras se desplaza.
## La posición pertenece al instante del evento; los oyentes nunca deben
## consultar después la posición actual del Player para reinterpretarlo.
signal player_noise_emitted(position: Vector3, radius_m: float, intensity: float)

## Mensaje de pickup de exploración; no es inventario ni recompensa de combate.
signal oxygen_cache_collected(amount: float)

## Se emite cuando el combate efectivamente empieza: todos los enemigos del
## encuentro ya llegaron a distancia de combate (o se agotó el tiempo de
## espera) y el jugador quedó congelado. Lo escucha el HUD para mostrar
## "ENTRANDO EN FASE DE COMBATE", y CombatManager para arrancar las cartas.
signal combat_ready(player: Node3D, enemies: Array)

## El Enemy valida que el Player lo sorprendió desde detrás antes de que
## exista contacto/CHASE. CombatManager consume el marcador al iniciar.
signal ambush_ready(enemy: Node3D, player: Node3D)
