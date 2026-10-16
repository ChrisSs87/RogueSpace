# Verificación de esta preparación

Preparación original2026-10-16: sin Godot, push, merge, commit, bundle o ZIP.
Recuperación documental posterior autorizada: commit local de diez archivos;
push requiere confirmación. No se ejecuta Godot ni se crea bundle/ZIP.
No se instalaron servicios ni cambiaron credenciales/permisos/configuración.

## Comprobaciones realizadas

- AGENTS leído; inspección de autoloads, contratos/Resources e informes.
- B/C1/ancestros identificados por Git; C2 y calibración pendientes en sus
  worktrees identificados por status y archivos. No se asumió recuperación.
- Diagnóstico Git/DNS acotado: una consulta Git actual, fallo128; DNS/TCP
  fallidos. Segunda consulta DNS sólo para extraer la excepción subyacente,
  no bucle de reintentos ni más intentos de publicación.
- Disponibilidad GCM/helper/config revisada sin consultar o mostrar secretos.
- Helper: preparación offline válida; rechazos main, tag/refspec, nombre Git
  inválido, SHA incorrecto y worktree documental sucio. Sin ejecutar comando
  mostrado. Parser PowerShell sin errores. Tests locales reutilizables en tools/tests.
- Enlaces locales del nuevo índice/documentación y referencias verificadas.
- Diff de fuentes productivas no modificado; worktrees ajenos preservados.

## Repetición para recuperación documental

- tools/tests/prepare-publication.tests.ps1 sobre el worktree B+C1 limpio:
  seis controles PASS (preparación offline, cuatro nombres inseguros y SHA
  incorrecto); proceso EXIT_0. Sin red ni ejecución del comando de push.
- Control separado: worktree documental sucio rechazado por el motivo esperado.
- 23 enlaces internos comprobados en los diez archivos; cero destinos ausentes.
- Parser PowerShell: ambos scripts sin errores. Búsqueda acotada de patrones
  de tokens/claves privadas: cero coincidencias; no auditoría exhaustiva.
- Staging limitado a la lista explícita de diez archivos: sin .git, .godot,
  paquetes, builds ni fuentes de gameplay. No se elimina el puntero .git del
  worktree ni se modifica la copia Drive anterior.

En la preparación original no se probaron credenciales de push ni el caso
remoto libre/existente: la red falló y no se reintentó. La auditoría posterior
verificó B+C1/main y ausencia de rama docs por conector GitHub. Antes de la
recuperación documental se consultó chore/multi-ai-continuity: ausente.
Esto no comprueba credenciales de escritura. No se presenta el helper como publicador de
seguridad ni mecanismo desatendido. La revisión humana y autorización de
publicación siguen necesarias; el riesgo de carrera del nombre está documentado.

Estas páginas se recuperan localmente con autorización, sin producción ni C2.
Su publicación requiere confirmación. Un clon del SHA B+C1 NO las contiene.
Existe una copia anterior en Drive; esta actualización no modifica esa copia.
El archivo .git accidental detectado allí no pertenece al conjunto recuperado.
