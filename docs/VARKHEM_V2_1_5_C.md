# Varkhem V2.1.5-C — controlled cover expansion / continuity checkpoint

Branch: `feature/varkhem-environmental-stealth-v2-1-5`.
B recovery: `1abe9d97d8ad469f91635a09c63ce89af87d9422` (23 files).
C local experimental recovery authorized for the shared-core phase-1 audit.
No push/merge. Other worktrees and main are not modified.

**V2.1.5-B — PENDIENTE DE VALIDACIÓN ANDROID.**
Its existing mobile ZIP is preserved byte-for-byte, SHA256
`91D9FDD0476B22E3ACCC4085C2066A9A2C95EB0A3816A816B260839BED1DBC8F`.
Historical B result: 35 functional PASS, 33 EXIT_0 / 2 NATIVE_AV after PASS
summaries. Neither the recovery commit nor C promotes B to approved/CLOSED.

## Implemented C

`RoomCoverVariantResource` declares stable ID, family, LogicalCover category,
compatible existing semantic IDs, physical envelope and two colors.
`RoomEnvironmentProfileResource.cover_variants` is empty by default; the B
box behavior remains available. Only Varkhem configures the five variants.

| Existing room | Compatible equipment |
|---|---|
| BARRACKS | MEDIUM service/communications console or supply container; HIGH equipment container |
| ARMORY | MEDIUM inventory/service console or supply container; HIGH service machine or equipment container |
| FOOD_STORAGE | HIGH refrigeration machine; MEDIUM supply container |

No new room types, Command control room, technical-room semantic, population
rules, topological edits or mandatory props. PRISON/private rooms lack a
configured compatible equipment set and receive no new props. In particular,
the private 6 x 6 room cannot fit these B perimeter placements outside the
1.8 m protected cross (center X=1.92 minus half-width .8/.9 is below 1.8).
No prison-specific equipment was invented. START, EXIT,
COMMAND_ROOM and circulation nodes remain excluded from covers.

At most two props per eligible terminal room. A separate per-seed/profile/
node/index RNG selects compatible presentation variants without consuming
the existing placement/category RNG. The B stable placement ID is retained
intentionally. HIGH is 1.6 x 2 x 1.2 m; MEDIUM 1.8 x 1.1 x .9 m, unchanged.
All connector-axis, wall, declared spawn and full patrol reservations remain.
Rejected props report their reason, never change enemy population.

No new LogicalCover rules. One BoxShape3D body and one non-colliding CSG bake
source retain the conservative solid box. Details use 2 BoxMeshes for console
and container, 4 for machinery, with one shared accent material per prop.
Details stay inside the reserved physical box, create no additional colliders,
bake proxies, runtime lights or shaders. This is deliberately coarse box
collision, not detailed collision around individual controls or vents.
LOW remains available/validated, but is not procedurally populated.
No mobile FPS/draw-call guarantee is asserted.

## Automatic validation

New `varkhem_v215_c_environment_validation` extends B's real physical gate:
assembly, required semantics, floor/capsule, containment, seams, overlaps,
connectors, patrol/navigation/population and transitions. Adds catalogue
eligibility/category/size, one physical/bake envelope, visual bounds and
standing/crouched/interposition checks for all five configured variants.
Full normal Enemy perception remains covered by the existing cover harness.

Executed C physical sample: 65001-65006, six runs / nine sectors, SMALL/MEDIUM/
LARGE, GROUND/BASEMENT/UPPER; PASS/EXIT_0, zero failures/rejections/overlaps,
zero retries/backtracks, 24 covers / 52 enemies. Seven consoles, one machine,
16 containers. Seed 65002 contains all three families. Comparing all nine
sectors with B: zero cover position/size/category differences.
Determinism reassembles all sectors of 65001/65003/65005/65015/65020 twice,
comparing cover/light report, navigation geometry, topology and content: PASS.

Final runtime battery: 13 regressions PASS/EXIT_0, plus the new C physical
gate PASS/EXIT_0 (14 harness executions total). Includes all cover/posture
cases, B suspicion/darkness/search, near-cover APPROACH, escape/pursuit, DROP,
cancelled-APPROACH reentry, combat suspension, real Stage6J composition/reset,
V213 phase A, combat integration and cross-archetype smoke. Horvex physical
66001-66003: three runs / eight sectors, zero retries/backtracks/failures;
Ship physical: SMALL 64005, MEDIUM 64002, LARGE 64001, all PASS/EXIT_0.
No NATIVE_AV appeared in this selected C battery; that does not close the issue.
Results are logged outside the project at
`artifacts/varkhem_v2_1_5/c/ledger.csv` (C physical: `environment.log`).
Native AV is never normalized to EXIT_0. Import currently
completes EXIT_0 with preexisting `Safe save failed`; no configuration fix.

## Android / continuity

C is PENDING ANDROID; recovery is not manual approval. Mobile entry is
`scenes/tests/VarkhemV213ExperienceTest.tscn` (seed 65001), with existing
NEW SEED / NEXT SECTOR, PLAYER/TOP VIEW, LOGICAL MAP, zoom/FIT and infiltration
debug. Test seed 65002 for all families, 65003/65005 for further distributions.
Standalone Cover/Chase/Approach test scenes from A/A.1/A.2 remain available.
Test MEDIUM standing vs STEALTH, HIGH, lateral exposure, investigation,
pursuit/APPROACH, combat/reset and sector regeneration. No Python on Android.

Needs Android: visual recognition from both approach directions, usefulness
of perimeter cover, avoidance comfort, density, physical box readability,
Cardboard/posture comfort and actual mobile performance. B suspicion/light
balance and the moving APPROACH report from A.2 remain subject to feedback.
`NATIVE_SHUTDOWN_AV` remains OPEN, root cause unknown; not investigated here.

Can resume independently of B Android feedback: isolated catalogue geometry/
resource tests and documentation, reproducibility checks, authored fixture
coverage. Gameplay balance, broader furniture density, new semantic rooms and
procedural circulation covers require a separately authorized task/review.
Do not promote this experimental checkpoint to official CURRENT/main state.
