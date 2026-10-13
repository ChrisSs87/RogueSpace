# Core Gameplay P1-A — recompensas, reset y ADN

Fecha: 2026-10-13. **DIAGNÓSTICO, NO CORRECCIÓN DE PRODUCCIÓN.**
Rama: `audit/core-gameplay-reward-reset-p1-a`.
Worktree: `core_gameplay_p1a_worktree`.
Base/HEAD: `7c063ec4f2aceaca588dfa44185420b05e03e821` (P0).
Sin commit, push, merge o ZIP. No se investigó NATIVE_SHUTDOWN_AV.

## 1. Resultado ejecutivo y ownership

**R4 de la auditoría queda reproducido:** los resets/regeneraciones no abortan
la transacción de RewardManager. No es un fallo del cálculo de ADN ni se
diagnostica por conservar una elección ya confirmada.

```text
EnemyResource.species_id
  → CombatManager / EnemyCombatant → victoria de todos
  → CombatEncounterManager.reset
  → CombatManager.combat_ended
  → RewardManager.start_reward_sequence(especies, Player)
      ├─ pasos/pending/Player: RewardManager (autoload)
      ├─ ADN y habilidades: DNAManager (autoload)
      ├─ HP/mazo/O2/stats: RunState (autoload)
      ├─ paneles y botones: RewardUI (nodo de escena)
      └─ suspensión: ExplorationState._reward (autoload)
  → RewardManager._finish
  → reward_sequence_finished → UI oculta + suspensión liberada
  → Player.unfreeze_after_combat

Reset prototipo: DebugHUD → Stage6G.regenerate_from_debug
  → reset Encounter/Combat/ExplorationState + unfreeze Player
  → destruye/regenera RuntimeContent/geometría; conserva Player/UI
  → NO aborta RewardManager

Reset fuera de prototipo: DebugHUD / CombatUI
  → DNAManager.reset → RunState.reset_run
  → CombatManager.reset_after_defeat → Encounter.reset → reload_current_scene
  → destruye Player/UI, conserva autoloads y recompensa pendiente

Restart Well: FortressEndTrigger.restart_test
  → RunState.reset_run → reload_current_scene
  → NO reinicia ADN ni aborta recompensa
```

### Callers y señales reales

- `CombatEncounterManager._start_combat_now` congela Player antes de
  `EventBus.combat_ready`. `Player._on_combat_ready` reafirma el freeze.
- `CombatManager._remove_dead_combatants` recoge `EnemyResource.species_id`,
  cuenta derrotados y encola la liberación del Enemy real.
- `CombatManager._win_combat` limpia combate, resetea Encounter, emite
  `combat_ended` y luego inicia recompensa. **No libera Player entre ambos.**
- `RewardManager.start_reward_sequence` calcula los drops con los valores
  actuales; emite `reward_sequence_started` ANTES de asignar STEP_SUMMARY.
  El listener puede observar todavía `done`; luego llega `reward_step_changed`.
  Es orden observado, no una corrección nueva ni una causa nativa atribuida.
- `RewardManager.choose_dna_slot` consume una unidad pendiente, llama
  `DNAManager.add_dna` (emite dna_changed), después check_and_unlock y
  STEP_DNA_RESULT. El unlock ya queda registrado aunque no se equipe la carta.
- `RunState._on_dna_changed` recalcula HP sólo para suit; weapon/shield se
  consultan desde ADN al resolver sus bonos. No se duplica el bonus al resetear.
- `choose_card_to_replace` llama `RunState.replace_card`; `use_first_aid_kit`
  llama `RunState.heal`. Las acciones confirmadas son efectos reales inmediatos.
- `RewardUI` sólo lee/actúa por esas APIs; `_ready` comienza oculta, no
  reconstruye un paso pendiente del autoload. Se oculta con sequence_finished.
- `_finish` pone DONE y limpia `_player`, emite sequence_finished y DESPUÉS
  descongela al Player. El listener del evento todavía puede ver frozen=true
  durante la emisión; el estado estable posterior es false. No confundirlos.
- `_lose_combat` conserva el bloqueo hasta el reinicio explícito. El restart
  real de CombatUI pasó cuando no había recompensa activa.
- `CombatManager.reset_after_defeat` emite combat_ended sólo si había combate
  o combatants; después de una victoria/recompensa pendiente no los hay.
  Esa rutina no es un reset de RewardManager.

## 2. Fixture y límites de la evidencia

Escena/script nuevos `core_p1a_reward_diagnostic`. Un proceso fresco por caso.
Un driver raíz de test queda fuera de current_scene; la escena REAL Stage6J
o MainFortress6A se asigna como current_scene. Así el driver observa su recarga
real sin ser destruido ni reemplazar autoloads.

Se usan Player, Enemy y EnemyResource Varkhen reales. La admisión física ya
está cubierta por P0: aquí se entra por la señal pública combat_ready, tras
freeze explícito equivalente al caller Encounter. CombatManager resuelve una
carta letal EXCLUSIVAMENTE de fixture y ejecuta victoria/reward normales.
La carta ocupa temporalmente un slot de mano y se restaura por replace_card
antes de elegir recompensa: el pool real conserva diez cartas. No se modifica
ningún Resource productivo ni se falsifican pasos/ADN/habilidades.

Dos victorias y elecciones reales establecen ADN de arma=2. La tercera
alcanza el unlock existente de nivel 3. Se usa semilla RNG global **5** antes
de la carta final para seleccionar un drop de kit realmente posible; chances
siguen en DNA=1.0 DEV / kit=.10. Esto condiciona el escenario, **no mide balance**.
Daño de preparación deja 20/30 HP, permitiendo observar curación 20→30.

Las acciones de recompensa invocan las mismas APIs públicas que RewardUI;
la UI real se instancia y se observa. Reset usa pressed de los botones reales.
Para Well, Player activa el área/proximidad real y se verifica EndUI visible.
No es automatización táctil Android. Enemigos y locomoción del Player se
retienen sólo en el fixture para no abrir combates ajenos; se comprueban
freeze/suspensión/timers registrados, **no movimiento físico/navegación**.

Cada checkpoint verifica el STEP real. Reemplazo confirmado exige Golpe
Pesado en el pool; curación confirmada exige HP restaurado. No se escriben
campos privados: sólo se leen para trazar ownership/pending/timers/refs.

## 3. Matriz de interrupciones (A y B NO son la misma operación)

| Momento solicitado | STEP realmente alcanzado | A: regenerar prototipo | B: Reset DebugHUD fuera de prototipo |
|---|---|---|---|
| Resumen inicial | summary | FAIL / EXIT_1 | FAIL / EXIT_1 |
| ADN pendiente | dna_choice | FAIL / EXIT_1 | FAIL / EXIT_1 |
| ADN confirmado | dna_result | FAIL / EXIT_1 | FAIL / EXIT_1 |
| Carta desbloqueada | card_unlocked | FAIL / EXIT_1 | FAIL / EXIT_1 |
| Reemplazo pendiente | card_replace_choice | FAIL / EXIT_1 | FAIL / EXIT_1 |
| Reemplazo confirmado | kit_offer, Golpe Pesado incorporado | FAIL / EXIT_1 | FAIL / EXIT_1 |
| Botiquín pendiente | kit_offer, sin reemplazo elegido | FAIL / EXIT_1 | FAIL / EXIT_1 |
| Curación confirmada | kit_result | FAIL / EXIT_1 | FAIL / EXIT_1 |
| Finalización normal | done | PASS / EXIT_0 | PASS / EXIT_0 |

No existe un STEP “replacement_result”: confirmar reemplazo avanza al kit o
DONE. El kit seleccionado hace observable el efecto confirmado antes del
final. No se inventó ese estado ni se detuvo un callback a mitad.

### A — fallo concreto: suspensión y reward dejan de coincidir

Los ocho puntos activos conservan el mismo STEP, pending, UI y Player válidos,
pero Stage6G deja **suspended=false, frozen=false, RewardUI=true**. No hay
reward_sequence_finished por la regeneración. CombatUI=false y combatants=0.
Las elecciones ya aplicadas permanecen sin duplicarse en el snapshot; NO son
el criterio de FAIL. El fallo es mantener una recompensa activa y liberar su
ownership de exploración/Player. Player/UI no se destruyen en esta operación.

### B — fallo concreto: autoload pendiente con UI/Player destruidos

Los ocho puntos activos conservan STEP/pending, **suspended=true**, pero el
nuevo Player no está congelado, nueva RewardUI=false y `_player` de recompensa
es `<Freed Object>`. La escena se recargó, sus UIs se reconectaron, sin señal
de finalización/abort. No es doble signal connection: los conteos de conexiones
vivas se mantienen. El autoload de suspensión sigue con `_reward=true`.

El texto genérico de issue “exploration released” en los logs significa que
falta al menos una condición de ownership: en B NO afirma suspended=false;
los snapshots muestran claramente true + frozen=false + UI oculta.

DNAManager y RunState sí se reinician por el caller B. El FAIL no penaliza
borrar progresión confirmada al reiniciar; se debe a la recompensa vieja
todavía pendiente/referenciando al Player anterior.

### Otros caminos y ADN

| Control | Funcional | Proceso | Evidencia |
|---|---|---|---|
| Well restart durante summary | FAIL | EXIT_1 | misma recompensa huérfana, ADN previo conservado |
| Well restart después de done | PASS | EXIT_0 | sin recompensa pendiente; conserva ADN/habilidades |
| Derrota real → botón CombatUI restart | PASS | EXIT_0 | limpia ADN, HP30, UI/suspensión/freeze liberados |
| ADN arma/traje y carta → DebugHUD Reset | PASS | EXIT_0 | ADN0, habilidades vacías, bonus0, HPmax30, mazo inicial |
| ADN arma/traje y carta → Well restart | PASS de coherencia actual | EXIT_0 | ADN/bonos/habilidades permanecen; mazo se reconstruye |
| RunState.reset_run ×3 aislado | PASS de semántica actual | EXIT_0 | no duplicación; no es prueba de “run nueva” |
| Cambio de sector tras recompensas reales | PASS funcional | NATIVE_AV | ADN/carta/HP/bonos conservados, resumen completo antes del cierre |
| Arranque de proceso fresco | PASS | EXIT_0 | autoloads inicializan ADN0 y HPmax30 |
| C: iniciar run completamente nueva desde entrada de producto | INCOMPLETE | NOT_RUN | no existe caller productivo definido para ese contrato |

**Consolidado ejecutado: 26 escenarios, 17 FAIL / EXIT_1, 8 PASS / EXIT_0,
1 PASS funcional / NATIVE_AV (-1073741819 / 0xC0000005).** No hay escenario
ejecutado con setup incompleto. C es una limitación adicional NO ejecutada,
no se suma al denominador ni se sustituye por un reset sintético.
El runner continúa casos diagnósticos independientes, nunca repara producción.

## 4. ADN: qué se demostró y qué NO

Con cuatro victorias/recompensas normales: arma Varkhen=3, traje=1,
weapon:varkhen:3=true y Golpe Pesado equipado; bonus daño=6, HPmax=35.

- `RunState.reset_run` tres veces deja ADN/abilities/bonus iguales y HPmax35,
  sin pasar a 40/45/50. Recompone el mazo básico (desaparece la carta equipada),
  mientras el registro de habilidad sigue true. Es lo que hace esa API, no una
  prueba de corrupción por rollback. Su significado de producto necesita decisión.
- El caller DebugHUD completo hace DNAManager.reset ANTES de reset_run:
  se observó HPmax30, bonus0, ADN0, habilidades vacías, sin bonos arrastrados.
- El caller Well sólo hace reset_run: conserva ADN arma3/traje1, bonus6 y HPmax35;
  recompone mazo básico. Hay **semánticas de reinicio distintas**, no incremento
  espontáneo de ADN. No etiquetar automáticamente Well como inicio de run nueva.
- Sector 65003: conserva exactamente ADN, habilidades, Golpe Pesado, HP35/35 y
  bonus6. Evidencia funcional completa; proceso AV impide aprobación integral.
- `DNAManager._ready` inicializa una vez al arrancar proceso; recargar escena
  no recrea autoloads. `DNAManager.reset` no emite dna_changed. Su uso aislado
  podría dejar HP derivado cacheado hasta reset_run, pero no fue un defecto
  demostrado del caller combinado correcto (ni se modificó esa API).
- `RunState.begin_world_run` sólo asigna seed/director; búsqueda estática no
  encontró caller productivo fuera de tests. No es evidencia de un flujo de
  nueva partida completo ni de guardado/perfil. C queda sin contrato/fixture real.

## 5. Riesgos confirmados, descartados y límites

Confirmados: interrupción activa sin cierre de RewardManager; desacople con
suspensión/Player; nueva UI oculta y referencia al Player liberado tras reload;
semántica dispar de reinicios y pérdida de equipamiento al recomponer el deck
sin borrar el registro de unlock (consecuencia observada, política no decidida).

No observados en estos controles: duplicación numérica de ADN/bonos por reset,
doble recompensa por regenerar, señales de finalización duplicadas, corrupción
de ADN/carta/HP entre los dos sectores ensayados, bloqueo del restart normal
tras derrota sin reward activo. No generalizar esa ausencia a todo el juego.

No se ejecutó una continuación de RewardManager con el Player ya destruido:
un error al llamar a ese objeto sería una posibilidad, no una excepción
reproducida aquí. No se atribuye ese riesgo a NATIVE_SHUTDOWN_AV.
Las weakrefs de actores muertos se registran en snapshots; no se concluye una
fuga nativa, doble destrucción ni causa del cierre a partir de ese contador.
No se auditaron todos los callbacks deferred del motor ni rendimiento.

NATIVE_SHUTDOWN_AV sigue ABIERTA: una ejecución de sector completó P1A_RESULT
funcional PASS y después terminó AV. No se repitió para “obtener exit 0”,
no se analizó un dump ni se implementó workaround de teardown.
La importación de editor terminó EXIT_0 con Safe save failed preexistente.
Ambos diagnósticos se conservan separados de los FAIL funcionales.

## 6. Propuesta mínima de abort (NO implementada)

Un contrato público localizado de RewardManager, por ejemplo
`abort_reward_sequence(reason, expected_owner)`:

1. Cancelar sólo la secuencia cuyo owner/contexto coincide; rechazar callback
   tardío de otra escena. No crear una segunda autoridad de recompensa.
2. Limpiar pending DNA/card/kit/mensaje/ref y publicar DONE ANTES de notificar.
3. Notificar la terminación/cancelación una vez para que RewardUI y la bandera
   reward de ExplorationState se sincronicen. Repetir abort debe ser no-op,
   sin nuevos efectos, rewards, señales o liberación de otro owner.
4. Acceder a Player sólo con is_instance_valid; liberar únicamente su freeze
   de recompensa cuando corresponda. No liberar un combate nuevo/narrativa.
5. Los callers de regeneración/reload lo invocan ANTES de destruir contenido
   o escena. No reutilizar reset_after_defeat como abort de recompensa.

No obliga a rediseñar CombatManager, ADN o solver. Probables archivos para una
corrección posterior autorizada: RewardManager y los callers reales Stage6G,
DebugHUD, CombatUI, FortressEndTrigger según política acordada; RewardUI sólo
si el contrato de cancelación exige una señal distinta. DNAManager no necesita
una corrección de cálculo basada en estas pruebas.

## 7. Política recomendada (decisión pendiente, NO assertions de rollback)

- A, regeneración de prueba: preservar ADN/desbloqueos/reemplazos/curaciones
  confirmados. Descartar sólo ofertas pendientes con abort explícito. Alternativa
  válida: prohibir/posponer regeneración mientras reward está activo; no mantener
  UI/pending y liberar exploración a la vez.
- Unlock ya registrado pero reemplazo no confirmado: “desbloqueado” no significa
  “equipado”. Si abort equivale a Leave Out, debe aprobarse expresamente: hoy no
  hay inventario de habilidades para reequipar y check_and_unlock no reofrece.
  No deshacer silenciosamente ADN ni simular carta confirmada.
- B, reinicio de run: especificar si reinicia progreso o sólo prueba/escena.
  Para la variante que borra progreso, abort viejo → limpiar encuentro/combate →
  DNAManager.reset → RunState.reset_run → recarga. Resetear toda la run no es
  rollback selectivo de una transacción de recompensa.
- C, nueva run: contrato de producto explícito de identidad/seed/graph y alcance
  de progreso. No asumir que reset_run/Well/reload son esa operación. Si ADN es
  temporal, limpiar antes de recalcular HP/deck; no inventar persistencia.
- Transición dentro de la misma run: conservar progreso confirmado, y decidir
  terminar/postergar o abortar reward pendiente antes de cambiar owner/escena.

## 8. Regresiones necesarias para la futura corrección

- Repetir los nueve puntos en A/B y caller Well, con expectativas aprobadas
  por operación. Mantener control normal y derrota/reset.
- Tras abort: DONE, UI cerrada, ref/pending vacíos, ownership/timers coherentes;
  doble abort sin señales/efectos duplicados; callback tardío de UI vieja inocuo.
- ADN/carta/HP confirmados no se vuelven a aplicar; ofertas pendientes no se
  aplican después de abort. Verificar especialmente unlock vs equipamiento.
- Nuevo combate y recompensa después de cancelar; otra instancia de Player;
  reset durante cada paso, no sólo reset después de finish normal.
- Reinicio completo con suit/weapon/unlock y orden ADN→HP; reset parcial sin
  duplicación; transición de sector conserva estado; nueva run por caller real
  cuando exista. Casos de índices/reemplazo obsoletos si hay UI diferida.
- Mantener P0 admisión/READY, DROP/reentrada, suspensión, victoria/derrota/reset,
  stats/ADN/O2 y regresiones de biomas. La aprobación Android es independiente.

### Narrativa

Una secuencia audiovisual futura no debe usar reset_for_regeneration para
liberar una pausa propia: borraría ownership de reward/combat. Definir primero
si se rechaza/pospone durante reward/APPROACH/COMBAT; finish/skip/cancel sólo
libera su owner. El cierre idempotente/refs válidas de recompensa es dependencia
de P1/P2, no autorización para implementar reproductor, guardado o tokens nuevos.

## 9. Reproducción, evidencia y preservación

Desde este worktree, con el Godot 4.7.2 usado en P0:

```powershell
$env:APPDATA='C:/Users/chris/OneDrive/Documentos/RogueSpace/artifacts/varkhem_v2_1_5/b/appdata'
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/core_p1a_reward_diagnostic.tscn -- --operation=regen --step=dna_result
# FAIL esperado del diagnóstico actual: EXIT_1, no una corrección aprobada.
```

Modos/steps están en el script y runners externos. `P1A_SNAPSHOT` registra ADN,
abilities, HP/deck/O2, freeze, UI, step/pending/ref, Timer.paused/time_left,
weakrefs y conexiones; `P1A_EVENTS` registra orden y frames. Es orden de
observadores conectados después de autoloads/UI, no interceptación del motor.

Evidencia en `artifacts/core_gameplay_p1a`:
- `final_diagnostic_ledger.csv`: 26 resultados consolidados sin sumar repeticiones.
- `diagnostic_ledger.csv` y logs iniciales: 24 ejecuciones; los reloads tenían
  un warning de fixture por capturar el nodo destruido en una lambda de espera.
- `verified/`: doce casos de reload repetidos comparando IDs (no nodo liberado),
  más dos controles de ADN/suit por callers reales. Sin SCRIPT ERROR/ERROR en
  esos logs. Expectativas y producción intactas; primeras evidencias conservadas.
- Nueve A y tres controles no afectados (sector, reset_run, cold start) usan
  logs iniciales; los doce reloads usan logs verified; se añaden los dos ADN
  verified. Una sonda preliminar summary y la importación no suman a 26.

Producción tracked idéntica a P0; sólo escena/script/UID diagnósticos y este
informe nuevos sin commit. P0 sigue limpio, main y todos los otros worktrees
intactos; manifiesto previo de 2.727 archivos: cero diferencias.

**STOP. Se requiere autorización y decisión de política antes de implementar.**
