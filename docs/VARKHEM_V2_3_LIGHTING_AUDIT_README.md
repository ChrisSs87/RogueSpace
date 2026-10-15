# RogueSpace — development lighting audit

This is a shared DEVELOPMENT snapshot, not the stable main branch or an Android
release. A4 is functionally approved by the user for development publication.
No merge into main is implied. Godot used for validation:
`4.7.2.stable.official.ed1daf0bf`.

## Reading order

1. `AGENTS.md`, `RogueSpace_CORE_Design_UPDATED.md` and
   `RogueSpace_CURRENT_State_UPDATED.md`. CORE/CURRENT include historical
   contracts; use the stage reports below for the current lighting implementation.
2. `docs/VARKHEM_V2_3_A_LIGHTING.md`: recovered A,
   commit `956fadad8837f165a39fc4c45724368f1a63e51d`.
3. `docs/VARKHEM_V2_3_A2_LIGHTING_ARCHITECTURE.md`: declarative profiles,
   sources, sockets, variants, scope and validation.
4. `docs/VARKHEM_V2_3_A3_BALANCE_AUDIT.md`: historical A2 balance audit BEFORE
   the A4 correction. Its quantized detection measurements are not final A4 values.
5. `docs/VARKHEM_V2_3_A4_EXPOSURE.md`: continuous curve sampling, actual
   before/after results, effective ambient diagnostics and remaining limitations.

The reports describe their original dirty-worktree state. The two recovery
commits now preserve A2 (with A3 evidence), then A4, without rewriting A history.

## Source map

- `autoloads/LightingManager.gd`: canonical 0–10 exposure, legacy integer
  adapter and continuous detection adapter for active biome profiles.
- `resources/run/BiomeLightingProfileResource.gd`, `LightingSourceResource.gd`,
  `LightingVariantResource.gd` and `resources/lighting/`: declarative catalog.
- `scripts/world/BiomeLightingBuilder.gd`, `LightingSocketProvider.gd`,
  `RoomLogicalLight.gd`, `RoomEnvironmentBuilder.gd`: effective source placement,
  visible sources, logical exposure and deterministic distribution.
- `scripts/enemies/Enemy.gd`: existing perception/curve sampling and confirmed
  contact; no state-machine rewrite.
- `scripts/ui/DebugHUD.gd`, `scripts/world/Stage6GProceduralPrototype.gd`:
  effective light/ambient diagnostics and sector consumers.
- `scripts/tests/a3_*`, `a4_*`, `varkhem_v23_a2_*` and matching
  `scenes/tests/`: reusable fixtures, not additional gameplay systems.

## Reproduction and evidence limits

From the repository root with Godot available, for example:

```powershell
& $Godot --headless --path . res://scenes/tests/a4_curve_validation.tscn
& $Godot --headless --path . --fixed-fps 60 res://scenes/tests/a4_exposure_audit.tscn -- --variant=OPERATIVA --case=ambient
& $Godot --headless --path . --fixed-fps 60 res://scenes/tests/a3_staged_audit.tscn -- --seed=65003 --kind=HUB --category=1 --pocket=1 --variant=REDUCIDA
```

Set `$Godot` to the local Godot console executable. Import the project first on
a fresh checkout to build the engine's generated class/import cache.
JSON markers in exposure fixtures retain the historical `A3_EXPOSURE` name;
the selected scene and commit identify which implementation is under test.

Raw logs, dumps, timing CSVs, local backup manifests, captures and runner scripts
with machine-specific paths are retained locally, not published. Reports retain
methods/results and distinguish functional results from process exit codes.
P2-C-D `--replay` additionally requires the local historical `temporal.json`
passed through `--source`; that generated audit dataset is not part of this branch.
Standalone staged/exposure/curve fixtures do not require it.

## Status and exclusions

- A2/A4 implemented; A4 approved functionally for development publication.
- A4 final battery:137 satisfactory controls/strategies,24 unsuccessful
  infiltration strategies,0 demonstrated regression FAIL;156 EXIT_0/5 NATIVE_AV.
  These counts are not equivalent to integral runtime or Android certification.
- Android lighting/balance and Cardboard performance remain pending.
- `NATIVE_SHUTDOWN_AV` and `Safe save failed` remain OPEN, not investigated here.
- Horvex/Nythari lighting profiles are PREPARATORY, not activated in production.
- No rejected NavMesh cache, P2-C-F cover-placement experiment, new missions,
  altered population or experimental Horvex topology is incorporated.
- No credentials, `.git`, `.godot`, builds, ZIPs or other worktree contents are
  added. Existing accepted core gameplay history remains in this branch's ancestry.
