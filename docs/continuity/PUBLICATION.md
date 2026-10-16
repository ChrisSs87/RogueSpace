# Publicación local controlada — diagnóstico y respaldo

## Evidencia 2026-10-16

Windows real, no Linux remoto: proceso pwsh7.6.5 del runtime Codex; Windows
PowerShell5.1 también se puede ejecutar. La prueba anterior con el mismo Git
en powershell.exe falló igual: lanzar un hijo no abandona las restricciones
heredadas del agente ni equivale a una sesión interactiva fuera de él.

Git2.53.0.windows.3, libcurl8.18.0, backend schannel, helper manager y GCM2.7.3
disponibles. Origin exacto autorizado HTTPS. No proxy HTTP(S)/ALL_PROXY en
variables inspeccionadas; no configuración proxy/url rewrite detectada por
claves revisadas. No hay Git alternativo en C:/Program Files/Git/cmd/git.exe.
No se leyeron tokens/passwords ni ejecutó credential fill.

Una consulta Git de lectura desde este worktree terminó128 con
`getaddrinfo() thread failed to start`. DNS Windows/.NET, con deadline5s,
devolvió SocketException «Host desconocido»; TCP443 también falló en ese contexto.
No se identifica causa raíz: resolución/red restringida o recursos del resolver
son hipótesis, NO está demostrado agotamiento de RAM ni DNS público caído.
El helper instalado no prueba credenciales válidas; el fallo precede auth.
El usuario reporta publicación exitosa desde PowerShell interactivo externo.
También hubo consultas exitosas desde Codex en sesiones previas: intermitente.
No usarlo como garantía actual de escritura o servicio fiable.

Sin cambios de DNS/proxy/firewall, sin instalación, sin nuevo intento de push.
En aquel diagnóstico se detuvo la consulta sin obtener estado remoto.
Posteriormente, la auditoría de solo lectura verificó por conector GitHub
B+C1 en 2e6e6691441fced41b3664b65ece729f9392c21f y main en
8bc3e890d5983700db9465fa41c3607cb3b831a9. No es evidencia de push operativo.

## Recuperación documental y próxima publicación

Los diez archivos de continuidad se recuperan en docs/multi-ai-continuity,
desde B+C1. Destino remoto propuesto: chore/multi-ai-continuity, ausente en
la consulta por conector del 2026-10-16. Requiere confirmación humana antes
del push y nueva comprobación del destino; no sobrescribir ramas existentes.
Obtener el SHA exacto con git rev-parse HEAD después de recuperar el commit.
Usar ese SHA, no el de B+C1, para publicar la documentación.

La copia previa en Drive es un respaldo documental, no sustituye Git.
No se sincroniza ni se elimina contenido remoto en esta recuperación.
Todo paquete futuro debe excluir .git (archivo puntero o directorio), .godot,
cachés, credenciales, builds y worktrees externos mediante lista explícita.
La auditoría detectó un archivo .git de 112 bytes en la copia Drive: no fue
incorporado a estos diez archivos y debe omitirse en nuevas entregas.
No crear paquetes ni borrar el puntero del worktree como parte de esta tarea.

## Herramienta propuesta, no publicador automático

`tools/prepare-publication.ps1` es exclusivamente READ-ONLY. Verifica repo
compartido exacto, origin, SHA aprobado, rama origen no estable, árbol limpio,
nombre de rama destino y paths sospechosos. Sin -Offline consulta UNA VEZ si
el destino existe y se detiene ante fallo o existencia. No hace push, commit,
merge, staging, cambio de credenciales/configuración ni reintentos.

Ejemplo desde PowerShell local (sustituir SHA por el aprobado):

```powershell
& .\tools\prepare-publication.ps1 -Worktree 'C:\Users\chris\OneDrive\Documentos\RogueSpace\varkhem_v2_3_gameplay_worktree' -ExpectedCommit '2e6e6691441fced41b3664b65ece729f9392c21f' -TargetBranch 'develop/varkhem-v2-3-gameplay-2e6e6691441f'
```

Si devuelve ABSENT_AT_CHECK, muestra un único ManualCommand de PowerShell:
push ordinario del SHA exacto a rama nueva. Ejecutarlo sólo tras autorización
explícita y revisión de secretos. Preferir nombre de destino con sufijo de SHA
para reducir colisiones. No copiar un ejemplo con SHA antiguo para otra entrega.

En entorno sin red, -Offline prepara sólo datos/comando, marca
NOT_CHECKED_OFFLINE. NO es comprobación de destino libre ni permiso de publicar.
Ejecutar la preparación sin -Offline en la sesión Windows que sí tenga acceso,
o posponer. No encadenar automáticamente ManualCommand con Invoke-Expression.

Tras un push autorizado, verificar con:

```powershell
git ls-remote --heads origin refs/heads/<rama-nueva>
```

Registrar SHA remoto, URL, ramas protegidas sin cambios y aprobación Android
separada. Si conexión/auth falla: STOP, conservar commits; no pedir credenciales
ni autorización interactiva en ejecución desatendida.

## Límites de seguridad explícitos

- Helper editable por quien tenga escritura local: NO frontera de seguridad,
  NO autorización persistente del sandbox. No activar el publicador experimental
  previamente rechazado ni ampliar reglas globales de Git.
- Revisión de nombres de archivo NO detecta secretos embebidos. Revisar diff,
  .gitignore y contenido antes de aprobar publicación; no imprimir secretos.
- El comando mostrado es un push normal, sin force/lease/delete/tags. No crea
  PR ni integra main; no toca develop/varkhem-v2-3-lighting.
- La consulta previa NO reserva atómicamente el nombre. Si otro escritor crea
  el destino antes del push, una actualización fast-forward podría aceptarse.
  Usar nombre único y dueño único; ante incertidumbre detenerse. Este helper
  no debe venderse como garantía criptográfica de creación exclusiva.
- No se probaron credenciales de escritura ni una publicación real aquí.
  La recuperación de red requiere administración externa si persiste; cambiar
  de intérprete dentro del mismo entorno no ha demostrado resolverla.
- El método minimiza pasos manuales, no garantiza publicación sin presencia
  humana mientras el canal Git del agente siga fallando.

Alternativa sin red: conservar commits/diff y ficha local. Un git bundle de
commits revisados puede prepararse posteriormente con autorización y entrega
explícita; no incluye cambios sin commit ni se genera en esta tarea. No instalar
servicios/agentes permanentes o jobs de publicación por iniciativa propia.
