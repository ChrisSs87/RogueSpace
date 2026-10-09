# Varkhem V2.1.4.1 — recuperación local validada

La recuperación consolida el estado sin commit probado en Android, incluyendo
los cambios acumulados V2.1.3/V2.1.4 y la corrección de reentrada V2.1.4.1.
Base Git: `6a5174ed1c5876d41f4056e884734dfb00050a05`.
Rama: `feature/varkhem-combat-perception-v2-1-4`.
No es merge a main ni publicación remota.

## Contratos conservados

- Orientación de retorno a patrulla, población por tamaño, cobertura semántica
  de hubs existentes y protección dinámica de START ya validadas.
- Suspensión lógica de exploración durante combate/recompensas: cuerpos
  registrados, timers preservados, UI/combate activos, reset seguro.
- Origen físico del raycast y destino Player/Head; paredes bloquean visión.
- Timeout APPROACH total distinto de DROP parcial: sólo el primero permite
  reentrada al alcanzar la banda con contacto normal, desde percepción normal.
  No cola automática por DROP parcial ni modificación de FOV/alcance.
- Tests diagnósticos y fixtures SOUND/VISION separados, sin sustituir ruido
  por visión confirmada ni forzar estados para simular detección.

## Evidencia conservada

Paquete manual: `RogueSpace_Varkhem_V2_1_4_1_TEST_MOBILE.zip`.
SHA256: `5A77E34946DC20F56458FAE94358F9A661BFC37A694F5BCDB829FFA7463CBA6E`.
561 archivos fuente coinciden con el paquete antes de añadir esta documentación.
La única modificación de configuración dentro del paquete fue el entry point;
el project.godot del repositorio conserva su entrada anterior.
El usuario confirmó pruebas manuales Android satisfactorias al autorizar este cierre.

15 ejecuciones focalizadas: PASS funcional / EXIT_0, sin NATIVE_AV en esa batería:

1. `varkhem_v214_reentry_diagnostic` — timeout total, contacto sostenido,
   recuperación al alcanzar banda y único inicio.
2. Mismo escenario con `--sound-stream` — renovaciones y expiración auditiva;
   no exige FOV válido por restaurar una coordenada después de investigar.
3. `stage5f_behavior_validation`.
4. `stage5g_escape_integration`.
5. `stage5g_drop_integration` — expulsión, ownership, suspensión, cuerpo físico,
   ausencia de cola/duplicados, pérdida de contacto y recuperación auditiva.
6. `stage5e_encounter_validation`.
7. `stage6j_playable_combat_reset_validation` — victoria/derrota/reset/reanudación.
8. `varkhem_v214_combat_suspension_validation`.
9. `varkhem_v2_1_3_validation` con `--phase-a` — persecución/última posición.
10. `stage6c_combat_integration`.
11. `varkhem_v214_sound_recovery_validation`.
12. `varkhem_v214_visual_recovery_validation`.
13. `stage5e_navigation_validation`.
14. `stage5g_double_integration`.
15. `stage5h_runtime_patrol`.

Motor utilizado: Godot 4.7.2 official ed1daf0bf. Para reproducir, desde la raíz
del proyecto: Godot `--headless --path . scenes/tests/<nombre>.tscn`;
argumentos adicionales mediante `-- --phase-a` o `-- --sound-stream`.
Los fixtures dedicados permanecen en scripts/tests y scenes/tests.
Logs y ledger históricos se conservan fuera del proyecto, en
`artifacts/varkhem_v2_1_4/reentry_fix/`; no se incluyen caches/dumps en el commit.
No se repitió la batería para la operación de consolidación: no cambia código.

## Incidencias abiertas y alcance

- `NATIVE_SHUTDOWN_AV`: reproducida, causa raíz indeterminada. Independiente;
  no resuelta, no ocultada y no investigada en esta consolidación.
- Importación desktop: EXIT_0 con `Safe save failed` del editor. Arranque de
  copia extraída: EXIT_0, seed 65001 assembly/nav válidos. No se atribuye causa.
- Android: bajón transitorio de FPS al iniciar segunda seed; luego se
  estabiliza. Reportado por usuario, registrado sin investigación ni medición.
- Banda de combate existente es contrato de distancia, no reserva AABB exacta.
- Los tests automáticos no garantizan rendimiento ni justicia de infiltración
  para todos los dispositivos/seeds. La aceptación Android es funcional,
  no resolución de todas las incidencias técnicas.

V2.1.5: rama `feature/varkhem-environmental-stealth-v2-1-5` desde el commit
de recuperación. No se incorpora implementación ambiental en este cierre.
