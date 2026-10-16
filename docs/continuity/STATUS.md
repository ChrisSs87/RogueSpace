# Estado verificable y decisiones — 2026-10-16

Base de estas páginas: `2e6e6691441fced41b3664b65ece729f9392c21f`.
Rama documental: docs/multi-ai-continuity, worktree multi_ai_continuity_worktree.
Recuperación documental local autorizada el 2026-10-16; el SHA se obtiene
del commit que contiene estas páginas. Publicación pendiente de confirmación.
No cambia producción ni incorpora C2.

## Disponibilidad y verificación remota

- GitHub, verificado por conector de lectura el 2026-10-16: rama
  develop/varkhem-v2-3-gameplay en `2e6e6691441fced41b3664b65ece729f9392c21f`;
  main en `8bc3e890d5983700db9465fa41c3607cb3b831a9`.
- docs/multi-ai-continuity no estaba publicada. chore/multi-ai-workflow en
  `d849158ea3c3af4c36b36c82f6e37254680081c3` es una rama anterior de AGENTS,
  no la recuperación de estos diez archivos. Destino documental propuesto:
  chore/multi-ai-continuity, ausente en la consulta previa a esta recuperación.
  Revalidar ausencia inmediatamente antes de un push autorizado.
- [Drive: copia documental previa](https://drive.google.com/drive/folders/10ddFaAEXnPReW59_bfM5N86dmnQPA0qa)
  está disponible. STATUS/TASKS/PUBLICATION/VALIDATION coincidían con los
  originales locales antes de esta actualización. No se actualiza Drive en
  esta tarea: esa copia no incluye necesariamente la recuperación posterior.
- Git CLI falló con getaddrinfo() thread failed to start en la auditoría
  precedente. La lectura por conector no prueba capacidad de push ni resuelve
  el fallo del canal Git. No se cambiaron red, credenciales ni configuración.

## Niveles de evidencia

- V: inspeccionado en código/Git local en esta tarea.
- R: resultado de informe o log anterior, NO reejecutado ahora.
- U: aprobación/observación declarada por el usuario; no medida aquí.
- P: propuesta o pendiente, no implementado/certificado.

No confundir PASS funcional con EXIT_0; registrar NATIVE_AV y FAIL por
separado. Android/Cardboard sólo se certifican con dispositivo real.

## Puntos de recuperación

| Etapa | SHA/base local | Estado y evidencia |
|---|---|---|
| main |8bc3e890d5983700db9465fa41c3607cb3b831a9|V: ref estable, sin integrar desarrollo reciente |
| P0 |7c063ec4f2aceaca588dfa44185420b05e03e821|V/R: admisión/READY |
| P1-B |41105202db28e8a7f7f917ffd14eea6cda608e5c|V/R: lifecycle y abort recompensas |
| P1-C |e68ca00401d9bd38a05f0857cb0726f62a870db5|V/R: OMITIR, bloqueo hasta resolver |
| P2-B |804dfcaf639e4f6ebc9407be7ba0eb9866fb83c3|V/R: perfiles efectivos; density no se convierte libremente en enemigos |
| P0-R2 |af78fef28d0ea928d22a165136f806867540fcee|V/R: inicio seguro cercano/pared, lifecycle candidatos |
| P2-C-C |8949f44567c44e03d162650798128ac3f44bcb65|V/R: coberturas habitaciones y hubs previos |
| P3-B1.1 |9fb0e12b8bab3ef6ef238c1ee725a9fd7d75e321|V/R: lifecycle debug y registros débiles |
| V2.3-A |956fadad8837f165a39fc4c45724368f1a63e51d|V/R: luz visual/lógica |
| A2/A3 |fe131bc204b19ae71bf508e94f5041b601af46b2|V/R: perfiles/variantes y auditoría anterior a A4 |
| A4 |7f487b6ce857e69dcdc53e1109f9c2ec2f4c9d69|V/R: exposición continua |
| B |5afaab2be8f38174dce2d584960db08d9159af5c|V/R/U: identidad visual; aprobación funcional, Android pendiente |
| C1 |a3d31d055408bd8c3ac29e69450961a246735d15|V/R/U: control durante APPROACH; Android pendiente |
| B+C1 |2e6e6691441fced41b3664b65ece729f9392c21f|V: develop/varkhem-v2-3-gameplay contiene ambos padres y A4 |

No son todas ramas secuenciales simples: B y C1 parten de A4 y se unen por
un commit de integración. Confirmar `git merge-base --is-ancestor` para la
base elegida. C1 aislada conserva copia pendiente de los15 archivos B; la
rama integrada contiene ambos trabajos recuperados. No limpiar esa copia.

## Trabajo que NO está incluido en B+C1

| Rama/worktree local | Estado | Qué preservar |
|---|---|---|
|audit/varkhem-pursuit-memory-v2-3-c2 / varkhem_v2_3_c2_worktree|V/R, sin commit|fixture e informe C2 |
|audit/varkhem-search-radius-v2-3-c2-a / varkhem_v2_3_c2a_worktree|V/R, sin commit|comparación1.5/2/2.5, resultados y wrappers |
|feature/varkhem-search-radius-v2-3-c2 / varkhem_v2_3_c2_apply_worktree|V/R/U, sin commit|una línea en orco_melee.tres: radio2.0;5 controles EXIT_0 reportados |
|feature/horvex-exploration-decisions-v1b3 / official_repo|V: dirty protegido|experimento Horvex, no fuente de integración |
|audit/core-gameplay-consolidation-phase1 / core_gameplay_audit_worktree|V: informe original sin commit|auditoría histórica y diseño audiovisual no implementado |

Radio C2: provisional, Carnotauro exclusivamente; Raptor/default1.5m.
Validación limitada a una geometría; otros módulos y Android pendientes.
No afirmar que se puede obtener C2 haciendo checkout de una rama cuyo HEAD
sigue siendo B+C1: los cambios pendientes no viajan por GitHub ni por SHA.

P2-C-F fue rechazado; P3-B3 caché NavMesh rechazado; P3-B2 sólo auditoría.
No incorporarlos. La complejidad Horvex experimental no está aprobada.

## Informes recuperados de esta base

- [P0](../CORE_GAMEPLAY_P0_CONTRACT.md), [P0-R2](../CORE_GAMEPLAY_P0_R2_ADMISSION.md).
- [P1-B](../CORE_GAMEPLAY_P1B_REWARD_LIFECYCLE.md), [P1-C](../CORE_GAMEPLAY_P1C_REWARD_RESOLUTION.md).
- [P2-B](../CORE_GAMEPLAY_P2B_SECTOR_PROFILES.md), [hubs](../CORE_GAMEPLAY_P2CB_HUB_COVERS.md), [habitaciones](../CORE_GAMEPLAY_P2CC_ROOM_COVERS.md).
- [P3 debug](../CORE_GAMEPLAY_P3B1_DEBUG_LIFECYCLE.md), [registro](../CORE_GAMEPLAY_P3B11_ACTOR_REGISTRY.md).
- [A/A2/A3/A4](../VARKHEM_V2_3_LIGHTING_AUDIT_README.md), [B](../VARKHEM_V2_3_B_VISUAL_IDENTITY.md), [C1](../VARKHEM_V2_3_C1_PLAYER_CONTROL.md).

Los informes describen el estado durante sus pruebas: frases como «sin commit»
pueden ser históricas. Esta tabla registra la recuperación posterior sin
reescribirlos. Raw logs/dumps/capturas suelen estar en artifacts locales,
no en GitHub. Replays pueden requerir datasets locales que no están versionados.

## Discrepancias documentales importantes

CORE/CURRENT conservan historia, ejemplos y planes; no son un balance único actual.

- Luz legacy0–5: ahora canónica0–10 en biomas, adaptador continuo para detección
  por A4. No restaurar cuantización ni fórmula duplicada por leer un párrafo viejo.
- P0-R2 describía suspensión durante APPROACH: C1 la retira y congela sólo en
  transición válida inmediata a COMBAT. El timeout nunca autoriza atravesar pared.
- Sonido aproximado/puertas atenuantes son intención de diseño; el runtime
  conserva posición del evento y la atenuación de puertas es un stub.
- Oxígeno se contabiliza por desplazamiento físico/combates, no por tiempo;
  los números y estados «futuro» antiguos requieren consultar RunState actual.
- No asumir SaveManager, misiones Command/élite/extracción, narrativa completa
  o rig Cardboard productivo por estar descritos como objetivos.

No resolver discrepancias cambiando gameplay sin autorización: plantear una
tarea específica de documentación o contrato, con código/commit como evidencia.

## Abiertos

- NATIVE_SHUTDOWN_AV reproducido; causa raíz indeterminada. No investigado aquí.
- Safe save failed; abierto, no cambiar seguridad del editor para ocultarlo.
- B+C1/C2 requieren prueba Android; rendimiento/Cardboard no garantizado.
- Radio2.5 de C2-A mostró progreso incorrecto hacia segundo punto; rechazado
  para adopción. No presentar «NAV OK» como éxito de recorrido físico.
- GitHub intermitente por Git CLI; lectura remota verificada por conector,
  escritura no probada. La documentación aún requiere aprobación de push.
- C2 sigue sin commit/publicación; la copia documental previa en Drive no
  convierte sus fixtures y configuración pendientes en una base recuperada.
