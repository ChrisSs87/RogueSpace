# Core Gameplay P1-C — resolución opcional de recompensas

Fecha: 2026-10-13. **Implementación para revisión, SIN commit P1-C.**
Rama: `feature/core-gameplay-reward-resolution-p1-c`.
Worktree: `core_gameplay_p1c_worktree`.
Base recuperada P1-B: `41105202db28e8a7f7f917ffd14eea6cda608e5c`.
P1-B — PASS FUNCIONAL. NATIVE_AV — ABIERTO. ANDROID — PENDIENTE.

## Recuperación y aislamiento

P1-B se revisó contra P0 7c063ec4 antes de recuperar. Se incluyeron sólo seis
archivos de lifecycle productivo, fixtures P1-A/P1-B/UIDs y sus dos informes.
No se cambió su implementación. Se añadió una nota histórica que registra
la autorización posterior de recuperación pese a los tres cierres nativos.
El worktree P1-B quedó limpio; P1-C nace del commit, no de cambios pendientes.
Main, P0 y los worktrees Varkhem/Horvex no reciben cambios de P1-C.

## Pasos y reglas

| Paso | Confirmar | OMITIR | Resultado de omitir |
|---|---|---|---|
| Resumen | Continuar | No | Sólo presentación, no decisión de efecto |
| ADN pendiente | Espada/Escudo/Traje | Sí | descarta UNA unidad, no aplica ADN |
| Resultado ADN | Continuar | No | ADN ya confirmado, no se revierte |
| Carta desbloqueada | Incorporar | Sí | conserva unlock, no equipa carta |
| Elegir reemplazo | Elegir carta existente | Sí | conserva mazo y unlock |
| Botiquín | Usar | Sí | no cura |
| Resultado botiquín | Continuar | No | curación ya confirmada |

OMITIR avanza al siguiente paso con `_advance`, no llama abort y no equivale
a OMITIR TODO. El cierre final es `kind=completed` sólo cuando no quedan pasos.
Los efectos confirmados no se repiten ni revierten por una omisión posterior.
Probabilidades, valor del kit, thresholds y reglas de ADN/cartas permanecen
intactos. Se reutilizan los botones existentes Dejar fuera/Descartar, ahora
rotulados OMITIR, y se agregan botones sólo a ADN y elección de reemplazo.

## API y protección de acciones repetidas

```gdscript
get_decision_id() -> int
can_skip_optional_reward() -> bool
skip_optional_reward(expected_sequence_id: int, expected_decision_id: int) -> bool
```

El caller captura ID de secuencia y decisión presentada. Skip valida ambos,
secuencia activa y paso opcional; devuelve false sin efectos ante replay,
decisión antigua, resumen/resultados o secuencia terminada/cancelada.
La decisión se invalida ANTES de callbacks. Cada notificación de paso renueva
el token, incluso si el siguiente ADN tiene idéntico STEP/species. IDs son
monotónicos de proceso, no se guardan ni redefinen balances.

RewardUI impide una segunda acción OMITIR síncrona hasta el siguiente frame
de presentación. No usa temporizadores ni una espera en segundos. Esto evita
consumir el nuevo panel que se crea durante la primera pulsación. Una nueva
acción voluntaria sobre el siguiente panel puede resolver el siguiente paso.
No se modifica el comportamiento de confirmación anterior de los botones.

## Exploración e input

Se conservan el freeze del Player y ownership `_reward` de ExplorationState
hasta el terminal normal/técnico. Omitir un paso intermedio no emite finished
ni libera exploración. No se agregan pausas globales ni resets indiscriminados.

- ESC/ui_cancel se consume en RewardUI mientras una secuencia está activa;
  no cierra UI, no avanza y no cancela. Evita caer al toggle de mouse del Player.
- Mientras está activa, RewardUI guarda/desactiva `SceneTree.quit_on_go_back`.
  BACK Android no dispara el cierre automático del proceso. No se remapea BACK
  a OMITIR ni a una selección implícita.
- Al terminar/abortar/salir la UI se restaura el valor anterior, no un valor
  global fijo. Fuera de reward, ESC/BACK mantienen comportamiento anterior.
- Botones Godot normales, focus de teclado/mouse y touch; rig Cardboard intacto.
- Una salida técnica de escena sigue abortando por el contrato P1-B. No se
  pretende bloquear al sistema operativo cuando destruye la aplicación.

El test simula ui_cancel/notification y verifica la política SceneTree; no es
una pulsación física BACK en Android ni certificación táctil/Cardboard.

## Archivos P1-C

Producción:
1. autoloads/RewardManager.gd: skip por decisión/token y notificación versionada.
2. scripts/ui/RewardUI.gd: handlers OMITIR, protección de replays UI, ESC/BACK.
3. scenes/ui/RewardUI.tscn: dos botones nuevos y dos textos OMITIR.

Pruebas/documentación:
- scenes/tests/core_p1c_reward_resolution_validation.tscn.
- scripts/tests/core_p1c_reward_resolution_validation.gd y UID.
- este informe.

No modificaciones de combate, Enemy, Player, ADN, RunState, estadísticas,
ExplorationState, Resources, geometría ni generación.

## Cobertura nueva

Catorce procesos independientes: accept, skip, skip_accept, accept_skip,
skip_all, card_skip, replace_skip, repeat, repeat_ui, back_escape, abort_choice,
abort_pending_after_skip, abort_after_skip y new_reward.

Reutilizan fixture P1-A: Player/Enemy reales, victoria CombatManager real,
RewardUI y acciones públicas, RNG 5 para un kit naturalmente posible (chance
.10 intacta), carta letal exclusivamente de test restaurada en el pool. Dos
victorias/ADN reales preparan nivel 3 para unlock/reemplazo. No especies
sintéticas ni escritura directa de pendientes/step/ADN.

El subcontrol de replay con dos unidades del mismo ADN entra explícitamente
por la API pública RewardManager con species_id del Resource real Varkhen.
Es una prueba del token en el boundary del manager, no de victoria múltiple.
Las demás entradas pasan por victoria real. Se verifican estados, freeze,
UI, HP, DNA/unlock, tamaño del mazo, señales terminales y política BACK.

Antes/después de abort técnico, siguen ejecutándose los diez controles P1-B,
incluyendo destrucción real de Player/UI, cambio de escena, callbacks de
secuencia antigua, efectos confirmados y suspensión de combate ajena.

Comando de reproducción desde P1-C (Godot 4.7.2 exacto de P0/P1-B):

```powershell
$env:APPDATA='C:/Users/chris/OneDrive/Documentos/RogueSpace/artifacts/varkhem_v2_1_5/b/appdata'
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/core_p1c_reward_resolution_validation.tscn -- --operation=repeat
```

Runners y logs separados en `../artifacts/core_gameplay_p1c`; no se sobrescribe
evidencia P1-A/P1-B/P0. Se repiten sus 77 controles completos, con deadlines
internos, sin límites externos de frames que corten el harness.

## Resultados

| Batería ejecutada sobre P1-C | PASS funcional | EXIT_0 | NATIVE_AV |
|---|---|---|---|
| Resolución P1-C | 14 | 13 | 1 |
| Matriz P1-A/P1-B | 26 | 26 | 0 |
| Abort/ownership P1-B | 10 | 8 | 2 |
| P0 dirigido (7 casos × 2 especies) | 14 | 14 | 0 |
| Regresiones compartidas P0 | 24 | 23 | 1 |
| Físicos Varkhem/Ship/Horvex | 3 | 2 | 1 |
| **Total** | **91** | **86** | **5** |

No FAIL funcional ni fixture incompleto. Los 17 casos originalmente fallidos
de P1-A pasan con EXIT_0 en esta repetición. Los asserts P1-B/P0 permanecen
intactos; sólo se añade la nueva prueba P1-C.

Varkhem 65001–65006: 6 runs/9 sectores, failures=[], valid=true, más
determinismo 65001/65003/65005/65015/65020. Ship tres tamaños (64005,64002,64001).
Horvex 66001–66003: 3 runs/8 sectores. Contratos físicos, seams, containment,
navegación/transiciones y semántica según los harnesses existentes.

Los cinco procesos NATIVE_AV (-1073741819 / 0xC0000005) emitieron antes sus
resúmenes funcionales completos y válidos:

1. resolution_skip_accept.log: P1C_RESULT valid=true, P1A_RESULT PASS.
2. abort_player_destroyed.log: P1B_ABORT_RESULT valid=true, P1A_RESULT PASS.
3. abort_ui_destroyed.log: P1B_ABORT_RESULT valid=true, P1A_RESULT PASS.
4. 02_stage5g_escape_integration.log: Stage5G escape integration: PASS.
5. additional_00_varkhem_v215_c_environment_validation.log:
   V21_PHYSICAL_RESULT valid=true/failures=[].

Se clasifican como **FUNCTIONAL_PASS / NATIVE_SHUTDOWN_AV_OPEN**, no aprobación
integral del proceso. No se atribuye causa ni se investigó el fallo nativo.
Estos 91 resultados son la batería actual; los 77/74/3 históricos de P1-B
permanecen en su informe/ledgers separados y no se suman ni sustituyen.

Dos importaciones de editor EXIT_0, sin Parse Error/SCRIPT ERROR; ambas
registraron Safe save failed preexistente. No se cambió configuración para
ocultarlo. No se suman al denominador de 91 harnesses.

Ledgers completos: resolution_ledger.csv, diagnostic_ledger.csv,
abort_ledger.csv, directed_ledger.csv, regression_ledger.csv y
additional_ledger.csv en artifacts/core_gameplay_p1c, con cada código y log.

Preservación verificada: cero diferencias en el manifiesto previo de 2.727
archivos de otros worktrees. P1-B y P0 limpios; main permanece en
8bc3e890d5983700db9465fa41c3607cb3b831a9. No cambios en Varkhem/Horvex
experimentales ni ramas anteriores. P1-C mantiene HEAD/base 41105202 y cambios
sin commit para revisión.

## Riesgos y pendientes

- Android, legibilidad/layout del botón adicional, teclado y touch reales
  requieren revisión manual. No se genera ZIP ni se declara cierre Android.
- Un unlock omitido sigue desbloqueado pero no equipado, igual que Leave Out
  anterior; no se introduce inventario ni reoferta de cartas.
- BACK usa una política temporal de SceneTree, restaurada por la misma UI.
  Un futuro sistema de pausa/narrativa que también cambie esa propiedad deberá
  coordinar ownership; no se implementa ese sistema en esta entrega.
- `abort_reward_sequence(reason, expected_sequence_id)` sigue disponible y
  sin cambio de firma/semántica P1-B. Narrativa debe distinguir cancelación
  técnica de resolución voluntaria: OMITIR siempre es cierre normal del paso.
- NATIVE_SHUTDOWN_AV continúa ABIERTA, causa indeterminada, no investigada.
  Se registran los cierres posteriores a PASS sin normalizar códigos ni
  repetir para sustituir evidencia. Safe save failed también sigue abierta.

P1-C queda sin commit para revisión. No ZIP, push, merge ni nuevas mecánicas.

## Recuperación autorizada para P2-A

El usuario autorizó posteriormente el commit local de recuperación de este
estado, sin cambiar la implementación. **PASS FUNCIONAL / NATIVE_AV ABIERTO /
ANDROID PENDIENTE.** Los 91/86/5 resultados históricos se conservan; no se
reinterpretan como certificación integral. P2-A parte del commit recuperado
en un worktree separado y no modifica producción.
