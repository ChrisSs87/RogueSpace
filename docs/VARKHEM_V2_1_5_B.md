# Varkhem V2.1.5-B — experimental mobile handoff

Branch: `feature/varkhem-environmental-stealth-v2-1-5`.
Recovery commit A/A.1/A.2: `ccf6001bf771b793011241c553be52f3c5549f46`.
Parent: `c79260642ec672beab241489da9262c1e104f4ac`.
V2.1.5-B — PENDIENTE DE VALIDACIÓN ANDROID.
Local recovery checkpoint authorized before C; no push/merge or experiential
CLOSED/PASS. The B mobile ZIP is retained unchanged.

## Visual suspicion (opt-in, existing ALERT)

Only the two canonical Varkhen EnemyResources enable `visual_suspicion_enabled`.
Other Resources default false and retain legacy admission/perception. The
existing range 10 m, FOV 105 degrees, hearing, exposure threshold 1 s and light
curve `[0,.15,.5,.8,.9,1]` are unchanged.

- Baseline still requires range, FOV, world LOS and LogicalCover interposition.
- Minimum capability for suspicion: 0.1, from the same existing light curve.
- Below it: NONE, exposure reset, no visual suspicion/contact. The existing
  proximity override (1.5 m, valid FOV/LOS) remains an explicit exception.
- Incomplete exposure: VISION_ALERT, existing ALERT investigates the observed
  location. This is uncertainty from exposure, not a new silhouette sampler.
- Confirmed exposure: VISION_CHASE and existing encounters. For opted-in
  enemies, visual suspicion alone does not register a combat candidate; lock
  also checks confirmed exposure/current light. SOUND keeps its own admission.
- Similar observations within 0.75 m refresh memory but do not reset state,
  local search points or route. A genuinely new observed location replaces the
  target. Hidden Player never updates that location.
- At the observed location, a currently valid uncertain sighting retains the
  orientation instead of turning toward speculative search probes. Once sight
  is lost the existing bounded search (up to two points) and timeout apply.
  Continuous uncertain evidence holds ALERT rather than oscillating to PATROL.

One real regression was caught and fixed during B: `stage5g_escape_integration`
failed because the guard turned into local search before completing exposure
(`FOV:NO`, `sight=0`, `ALERT`). The fix retains the active observation; no FOV,
range, exposure time, collision or test expectation was weakened. That test
only gained failure-context instrumentation. Historical failure evidence is
retained in `artifacts/varkhem_v2_1_5/b/escape_context.log` outside the project.

## Local functional lighting

`RoomLogicalLight` registers with the existing LightingManager and unregisters
on removal/regeneration. It contributes +2 only inside its assembled room's
local footprint/height. Ambient remains 1 globally. Normal semantic Varkhem
rooms, including Hub and Command, therefore report logical light 3: capability
80%, about 1.25 s of continuous exposure to confirm. Corridors without a room
source retain ambient 1 (15%, about 6.67 s); extreme darkness remains a supported
fixture/authoring condition, not a new random procedural lighting roll.

Ceiling strips are simple unshaded meshes, no runtime lights, shadows or large
transparent indicators. This identifies powered rooms but is NOT photometric
synchronization of the existing global renderer with logical light. No mobile
FPS claim or performance diagnosis is made.

## Safe first cover subset

The archetype references `VarkhemRoomEnvironment.tres` via the optional
`DungeonArchetypeResource.room_environment_profile`. Null is inert for legacy
archetypes. Stage6G invokes RoomEnvironmentBuilder after real assembly/semantic
presentation and BEFORE the existing global collider-derived bake. Neither
solver nor navigation implementation is changed.

Implemented family: STORAGE, crates/containers HIGH and MEDIUM in terminal
BARRACKS (equipment storage), ARMORY and FOOD_STORAGE. At most two per eligible
room, with deterministic category placement from effective sector seed and
profile ID. LOW remains available through LogicalCover but is not populated.

Control consoles and technical machinery are deferred: current semantics do
not expose a dedicated safe technical room; the explicit control destination
is COMMAND_ROOM, intentionally kept clear for its future encounter. No room
was relabeled, no new topology invented, no fake family assignment made.

Physical sizes HIGH 1.6 x 2.0 x 1.2 m; MEDIUM 1.8 x 1.1 x 0.9 m. Logical
interposition volume follows the footprint, extending from floor to 3 m;
category still determines stand/crouch blocking, not mesh height.

Placement reserves the central access cross with half-width 1.8 m (door
half-width 1.2 + baked agent radius .55, rounded conservatively), wall margin
.35 m, every declared spawn and complete patrol segments with .55 m clearance.
Props occupy positive-X perimeter corners, away from existing negative-X room
guard routes. The seed chooses the HIGH/MEDIUM ordering. This is deliberately
conservative, not a general furniture placer or an optimal cover generator.

Only a LogicalCover StaticBody owns collision. A matching CSGBox with collision
disabled supplies geometry to the existing bake's CSG collector; no duplicate
physics body can silently override MEDIUM/LOW vision rules. The resulting
proxies are bake data on the existing non-gameplay layer. Doors, START, EXIT,
COMMAND_ROOM and transit modules receive no covers. No enemy count/profile,
grammar, footprints, connectors, retry/backtracking or run progression changed.

## Validation and known fixture issues

New tests:

- `varkhem_v215_b_perception_validation`: darkness, partial ALERT without an
  encounter, observed vs hidden position, normal progressive confirmation,
  prolonged uncertainty without state oscillation, then search/return. The
  prolonged case uses a cloned long detection threshold to isolate uncertainty;
  the production threshold is independently checked in the bright-light case.
- `varkhem_v215_b_environment_validation`: inherits the real V213 physical,
  containment/capsule/seam/transition/population/patrol gates; adds floor-level
  prop exclusion from nav, all module centers/connectors reachable, bounded
  cover count and functional room light. Determinism additionally compares
  cover/light reports, full nav vertices/count, content and assembly signatures.

Initial environment test failures are retained: `.tres` property-before-script
serialization ignored the new profile (corrected ordering); querying a box's
midpoint selected an isolated nav polygon on its top. Diagnostics proved that
projection; the final assertion queries the walking floor, not the midpoint.
No navigation policy was changed to hide either result.

Initial floor-level sample: seeds 65001–65006, 6 runs / 9 sectors; SMALL,
MEDIUM, LARGE, GROUND/BASEMENT/UPPER. 24 covers total, 2–4 per sector, max 2
per room, no rejected props, population 4–8 per sector unchanged. All audited
overlaps, seams, containment, capsule, floor, destination/connector navigation
and patrol/spawn checks passed. No per-seed population reduction.

Final execution results and exit codes are recorded outside the project in
`artifacts/varkhem_v2_1_5/b/ledger.csv` and `recheck_ledger.csv`. See final handoff
report for completed totals; no historical failures are deleted or normalized.
`NATIVE_SHUTDOWN_AV` remains OPEN regardless of subsequent EXIT_0 results.
Editor import can still emit preexisting `Safe save failed`; no settings/OS
changes were made. This is not Android certification.

Final B battery: 35 harness executions with functional PASS; 33 EXIT_0,
2 NATIVE_AV (`-1073741819` / `0xC0000005`), after complete PASS summaries
in Horvex physical and shared template grammar. This is FUNCTIONAL_PASS /
NATIVE_SHUTDOWN_AV_OPEN, NOT integral certification. No native cause is claimed.
The nine final targeted rechecks all completed PASS/EXIT_0, including prolonged
suspicion, covers, near-cover APPROACH, pursuit, DROP, cancelled-APPROACH reentry,
sound-stream protection and environment/navigation/content determinism.
Stats/DNA and oxygen also completed PASS/EXIT_0. Earlier battery covers reset,
combat/UI, suspension, wall LOS, patrol, SOUND/VISION recovery and dynamic START.

Final environment sample: 65001-65006, nine sectors, 24 covers / 52 enemies,
zero rejected props, zero overlaps/seam/containment/navigation failures,
zero retries/backtracks. Determinism additionally reassembles all sectors of
65001/65003/65005/65015/65020 twice and compares cover/light/navigation/content.
Ship physical: all three size representatives PASS/EXIT_0. Horvex physical:
20 runs / 50 sectors, complete functional PASS then NATIVE_AV; three rejected
initial sector attempts recovered by the existing unchanged retry policy,
zero exhausted sectors and zero containment failures. The intended smaller
Horvex argument names were not recognized, so the default 20-seed sample ran;
the actual scope is reported rather than represented as three seeds.
Other-worktree preservation manifest: 2727 files checked, zero differences.

## Manual Android

Package entry: `scenes/tests/VarkhemV213ExperienceTest.tscn`, Varkhem seed 65001.
NEW SEED / NEXT SECTOR / PLAYER VIEW / TOP VIEW / LOGICAL MAP / ZOOM / FIT and
INFILTRATION DEBUG are inherited, not duplicated. Try 65002/65003/65005 for more
storage rooms, using reproducible seeds. MODE STEALTH crouches; WALK/RUN stand
only if headroom is clear. Observe sustained exposure, cover interposition,
guard investigation, obstacle detours and combat/reset.

Also available: `VarkhemV215CoverTest.tscn`, `VarkhemV215ChaseTest.tscn`, and
`VarkhemV215ApproachDiagnostic.tscn`. COVER freezes guard movement deliberately;
use CHASE / PHYS:ON for locomotion/APPROACH tests. No Python is needed on Android.

Pending: actual usefulness/fairness of perimeter covers, normal corridor light
feel, Cardboard posture comfort, real Android performance, control/technical
families, and the unreproduced moving APPROACH case reported in A.2.
