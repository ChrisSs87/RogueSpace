# Core Gameplay P2-B — resolución explícita de perfiles sectoriales

Fecha: 2026-10-13. Rama `feature/core-gameplay-sector-profiles-p2-b`.
Worktree `core_gameplay_p2b_worktree`.
Base P1-C: `e68ca00401d9bd38a05f0857cb0726f62a870db5`.
Sin commit, push, merge ni ZIP. Android pendiente. NATIVE_SHUTDOWN_AV abierta,
no investigada. Auditoría de entrada leída íntegramente desde P2-A, que conserva
su informe original sin modificaciones.

## Resultado de alcance

Resolución/aplicación de referencias sectoriales implementada, utilizando los
Resources existentes. **Conexión density→cantidad BLOQUEADA POR CONTRATO DE
BALANCE**, limitada explícitamente a observabilidad conforme al fallback
autorizado por el usuario. No se presenta como una conexión ya implementada.
Ningún .tres productivo fue migrado ni retocado.

## 1. Contrato y precedencia

DungeonSectorDefinitionResource agrega dos referencias opcionales:

```gdscript
@export var room_environment_profile: RoomEnvironmentProfileResource
@export var content_placement_profile: ContentPlacementProfileResource
```

`DungeonArchetypeDirector.resolve_sector_profiles(archetype, sector, template,
fallback)` es un método estático puro: no consume RNG, no muta Resources,
no duplica números de configuración y no cambia la luz global.

| Canal | Precedencia | Consumidor |
|---|---|---|
| Ambiente/luz local | sector.room_environment_profile → archetype.room_environment_profile → ninguno legacy | RoomEnvironmentBuilder → RoomLogicalLight → LightingManager |
| Población/contenido | sector.content_placement_profile → template.content_placement_profile → fallback de test existente | ContentPlacementDirector → plan → RuntimeConsumer |

No se agrega una segunda configuración de población por arquetipo: antes ya
estaba en el template y se conserva esa autoridad como fallback. Un override
de ambiente es el Resource completo; no se mezclan campos ambiguamente. Puede
reutilizarse el mismo .tres existente, sin copiar sus valores.

Null significa heredar, no desactivar. No se añade un modo de desactivación.
Referencia explícita con stable_id vacío o aporte de luz fuera de 0..5 se
rechaza, no se sustituye silenciosamente por otro perfil. Las validaciones
existentes de size ranges, slots, cobertura y navegación permanecen intactas.

Los strings históricos light_profile_id/population_profile_id **NO son claves
de un registro inexistente**. No se inventan conversiones LOW→0, NORMAL_HIGH→3
ni HIGH_RISK→más enemigos. El reporte conserva sus valores solicitados y los
marca `LEGACY_PROFILE_IDS_ARE_LABELS_NOT_RESOLVER_KEYS`, separándolos de los
IDs reales de los Resources resueltos. No se afirma que esos labels se apliquen.

## 2. Iluminación aplicada

Stage6G resuelve después del assembly y antes de construir el ambiente/bake.
El perfil efectivo llega al mismo RoomEnvironmentBuilder que Varkhem ya usaba:
aportes locales dentro de los footprints, exclusiones, muebles y navegación
siguen ese contrato. No se sustituyen luces locales por un valor global.
Sin override, Varkhem conserva VarkhemRoomEnvironment (+2), ambient observado
1 en proceso fresco, y regiones semánticas usualmente a nivel 3. Horvex/Ship
sin perfil ambiental siguen sin aporte local nuevo.

No cambios de materiales, estética, LogicalCover, percepción, LightingManager,
geometría ni bake. El valor global observado se registra, no se pisa ni se
pretende arreglar aquí el ownership global de ambient descrito en P2-A.
Los nodos locales se liberan mediante el cleanup existente; se limpia su
telemetría antes de regenerar para no mostrar datos viejos como aplicados.

## 3. Presupuesto y bloqueo de density

El perfil efectivo de contenido llega a build(plan, profile, seed, size_id) y
al consumer runtime. Se conservan pools/pesos, reglas de template, grupos
atómicos, cobertura, navegación, START y RNG existentes.

ContentPlacementPlan ahora registra sin decisiones adicionales:

- budget_range: mínimo/máximo efectivos por tamaño (o defaults legacy).
- requested_slot_count: sorteo original, con idéntica llamada RNG.
- effective_slot_budget: después del cap de capacidad preexistente si existe.
- selected_slots: lo realmente seleccionado, no asumido igual al presupuesto.

**Por qué density no se convierte todavía:** el código no define unidad,
curva de conversión ni densidad de referencia por perfil. El sorteo actual
es uniforme dentro de 4/4, 4/6, 6/8 y debe atender hub_pair/ruta/sala. Multiplicar
por density puede violar mínimos/cuotas; interpolar min→max modifica el sorteo
y balance; normalizar contra .55 inventaría una referencia que no existe.
Cambiar pesos según density también alteraría distribución de aparición.
En Horvex ni siquiera hay pool procedural conectado que permita inferir un
denominador seguro. No se implementa ninguna de esas políticas.

Se exponen density de arquetipo y sector sin inventar herencia para el 0
ambiguo (antes no distinguía “unset” y cero explícito). Siempre
`density_applied=false`, con `DENSITY_BLOCKED_NO_APPROVED_BUDGET_CONTRACT`.
Para continuar hace falta aprobar unidad/conversión, valores de referencia,
tratamiento de mínimos/cuotas y compatibilidad de RNG. Esto es una decisión
de balance, no una corrección del solver.

## 4. Configurado / resuelto / aplicado

`get_sector_profile_metrics()` devuelve un snapshot serializable:

- Contexto: biome, seed, effective_seed, sector/sector_id, size.
- requested: labels/density de arquetipo/sector, referencias configuradas en
  sector, perfil ambiental de arquetipo, contenido de template/fallback.
- effective: IDs reales y origen (`sector_override`, `archetype`, `template`,
  `legacy_test_fallback`, `legacy_none`). Estos indican overrides aplicados.
- applied: perfil ambiental realmente construido/aporte capturado, regiones
  iluminadas, ambient observado; perfil/estado de contenido, budget/selección,
  instanciaciones reportadas y Enemy vivos no encolados para destrucción.
- errors/limitations: labels sólo nominales, density bloqueada, selección
  diferente de presupuesto, errores y rechazos de runtime/nav/payload/patrulla.

El estado de población distingue `PLAN_REJECTED`, `PLANNED_PENDING_RUNTIME`,
`RUNTIME_REJECTED` y `CONSUMED`. Un perfil rechazado no se marca aplicado.
CONSUMED con cero actores no significa población satisfecha: se muestran
budget/selected/live y los rechazos. No se oculta ni cambia el comportamiento
legacy del nido sin slots/pool, ni se fabrican enemigos para alcanzar el mínimo.
Para perfiles con LOOT/etc., el presupuesto es de slots, no cuota de enemigos.

PROFILES abre/cierra un panel scrollable separado; HUD principal no recibe
el JSON entero. Se imprime `SECTOR_PROFILES=` al finalizar un sector. El panel
consulta al abrir/actualizar debug; el getter permite consultar el estado vivo
actual, sin un muestreo permanente caro. No instrumenta FPS ni servidores.

## 5. Antes/después

| Configuración | Antes | Ahora |
|---|---|---|
| Referencia ambiental de sector | inexistente/ignorada | override explícito consumido por builder |
| Referencia de contenido de sector | inexistente/ignorada | override explícito consumido por selección/runtime |
| Varkhem sin override | ambiente arquetipo/contenido template | misma autoridad y mismos valores |
| Horvex/Ship sin override | legacy | legacy, sin migración ni sentidos nuevos |
| LOW/NORMAL_HIGH/HIGH_RISK nominales | podían parecer efectivos en HUD | solicitados y explícitamente nominales en diagnóstico |
| Density | sin consumo ni aviso | observada, no aplicada, bloqueo explícito |
| Presupuesto/instanciación | datos parciales/confundibles | rango/sorteo/cap/selección/instancias/vivos separados |

Impacto productivo esperado sin overrides: **cero cambio de cantidad, pesos o
topología**. No se cambiaron Resources. En el fixture solamente: 65001 MEDIUM
baseline6, override de perfil real duplicado con rango4..4 produce4 (dentro
del rango original4..6), aporte de luz local2→1 produce nivel3→2, retirar los
overrides restaura exactamente la firma física/content/ambiente baseline.
Esos valores de fixture NO son un nuevo balance productivo.

## 6. Archivos modificados

Producción:
1. resources/run/DungeonSectorDefinitionResource.gd: referencias opcionales.
2. scripts/world/DungeonArchetypeDirector.gd: resolver puro, origins/limitations.
3. scripts/world/ContentPlacementPlan.gd: telemetría del presupuesto.
4. scripts/world/ContentPlacementDirector.gd: captura del sorteo/cap existentes.
5. scripts/world/Stage6GProceduralPrototype.gd: consumidores resueltos, estados
   aplicados, diagnóstico PROFILES/JSON, limpieza de telemetría.

Pruebas: core_p2b_sector_profiles_validation y
core_p2b_profile_observability_validation (escenas/scripts/UIDs) y este informe.
No archivos de RewardManager, combate, Enemy, Resources Varkhem/Horvex/Ship,
generadores experimentales, geometría, solver ni implementación de navegación.

## 7. Validación

| Batería | PASS funcional | EXIT_0 | NATIVE_AV |
|---|---:|---:|---:|
| Ensayo inicial perfiles (28 asserts) | 1 | 0 | 1 |
| Boundary observabilidad (6 asserts) | 1 | 1 | 0 |
| Ensayo final perfiles (30 asserts) | 1 | 1 | 0 |
| Resolución P1-C | 14 | 13 | 1 |
| Matriz P1-A/P1-B | 26 | 26 | 0 |
| Abort/ownership P1-B | 10 | 9 | 1 |
| P0 dirigido Varkhen/Horvex | 14 | 14 | 0 |
| Regresiones compartidas | 24 | 23 | 1 |
| Físicos Varkhem/Ship/Horvex | 3 | 3 | 0 |
| **Total procesos de harness** | **94** | **90** | **4** |

No FAIL funcional ni escenarios incompletos. Las 91 regresiones heredadas
completaron PASS funcional / 88 EXIT_0 / 3 NATIVE_AV. La prueba inicial de
perfiles se conserva, no se reemplaza: luego se precisó la telemetría de
plan rechazado/consumo y se añadieron dos asserts para los candidatos
configurados y el estado CONSUMED. La versión final tiene 30 asserts y EXIT_0.
No se repitió para ocultar el primer AV ni se cambió el criterio de PASS.

Los cuatro AV (-1073741819 / 0xC0000005) ocurrieron tras resúmenes funcionales
válidos: directed.log, resolution_new_reward.log, abort_ui_destroyed.log y
23_stage6i_runtime_content_encounter_validation.log. Se conservan en ledgers
y logs, sin atribuir causa o investigarlos. No certificación integral de proceso.

Físicos: Varkhem 65001–65006, seis runs/nueve sectores, más determinismo
65001/65003/65005/65015/65020; Ship tres tamaños; Horvex 66001–66003, tres
runs/ocho sectores. Todos PASS/EXIT_0. Comparación adicional contra evidencia
P1-C: cero diferencias en los nueve sectores Varkhem para población, ambiente,
runtime/payloads, semánticas, template, tamaño, módulos y effective seed; cero
diferencias de trazas de assembly (excepto tiempos) en Varkhem, Ship y Horvex.
No se infiere de ello que Horvex tenga población: su default vacío se preserva.

Dos importaciones de editor EXIT_0, sin Parse Error/SCRIPT ERROR; ambas con
Safe save failed preexistente, no investigado. No se suman a los 94 harnesses.
profile_validation_ledger.csv contiene los tres controles nuevos; los seis
ledgers heredados se guardan separados, no mezclados con resultados P1-C.

Preservación: manifiesto previo de 2.727 archivos de otros worktrees, cero
diferencias. P0/P1-B/P1-C limpios; P2-A conserva sólo su informe original
sin commit. Main sigue en 8bc3e890d5983700db9465fa41c3607cb3b831a9.
P2-B mantiene HEAD e68ca004 con cinco archivos productivos modificados y
tests/documentación nuevos, sin staging/commit para revisión.

El control dirigido usa geometría, RoomLogicalLight, pool y Enemy reales; los
overrides se asignan sólo en memoria de test y se restauran antes de salir.
El test de observabilidad usa deliberadamente planes inválidos en el boundary
de reporte, no finge que haya instanciado enemigos. Ambos alcances se separan.

Comandos desde este worktree, mismo Godot 4.7.2 exacto de P0/P1:

```powershell
$env:APPDATA='C:/Users/chris/OneDrive/Documentos/RogueSpace/artifacts/varkhem_v2_1_5/b/appdata'
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/core_p2b_sector_profiles_validation.tscn
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/core_p2b_profile_observability_validation.tscn
```

Logs/runners/ledgers separados en `artifacts/core_gameplay_p2b`. Se repiten las
91 regresiones P1-C/P1-B/P0/físicas; no se sobrescribe evidencia anterior ni se
eliminan asserts. El runner orquesta controles independientes según resultados
funcionales; los códigos de cada proceso Godot, incluidos AV, quedan intactos
en los ledgers. No se confunde exit del runner con exit de cada Godot.

## 8. Limitaciones / riesgos Android

- **Entrega parcial deliberada:** density no cambia presupuesto hasta aprobar
  su contrato de balance. Los labels históricos no se resuelven por magia.
- No se crea pool Horvex ni se migra su experimento. El diagnóstico hará visible
  su presupuesto nominal sin población efectiva, no lo soluciona automáticamente.
- Un override ambiental incluye muebles: cambiarlo requiere gates físicos
  aunque sólo se quisiera variar luz. No se añade un segundo sistema de luces.
- Un contenido explícito distinto puede causar conflictos reales de cuota,
  START, rutas/payloads. Se conservan los rechazos; no se bajan enemigos para PASS.
- Profiler/FPS/AV fuera del alcance. PROFILES debe revisarse en Android para
  legibilidad/touch, y cambios futuros de luz deben probar sensación/detección.
- Ambient global previo sigue observable sin ownership nuevo; no se corrige
  contaminación hipotética modificando otras escenas.
- NATIVE_SHUTDOWN_AV y Safe save failed permanecen abiertas. Ningún PASS
  funcional seguido de NATIVE_AV equivale a aprobación integral del proceso.

ANDROID PENDIENTE. Sin commit P2-B ni ZIP; preparado para revisión, no merge.

## Recuperación autorizada posteriormente

El usuario autorizó recuperar este estado mediante commit local, sin alterar
su implementación. **PASS FUNCIONAL / NATIVE_AV ABIERTO / ANDROID PENDIENTE.**
Se conservan los 94/90/4 resultados y el bloqueo explícito de density.
La auditoría táctica P2-C-A debe partir del commit en worktree independiente.
