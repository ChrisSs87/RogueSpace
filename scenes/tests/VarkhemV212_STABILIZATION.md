# Varkhem V2.1.2 — stabilization, 2026-10-08

Branch: feature/varkhem-patrol-infiltration-v2-1-2.
Base: 51efd77be10e0bd0da768d4331456269f4cab815 (V2.1.1).
The existing uncommitted patrol implementation is preserved. This report
supersedes the blockers in VarkhemV212_STOP.md, not its historical evidence.
Desktop functional validation only; Android experience remains MANUAL_REQUIRED.

## A — pre-existing combat reset UI defect

Clean V2.1.1 and the previous V2.1.2 both reproduced CombatUI.visible=true
after regeneration, despite empty combatants, freed enemy and unfrozen Player.
CombatManager._win_combat emits combat_ended then explicitly starts rewards.
_lose_combat retains combatants and shows defeat; reset_after_defeat cleared
them without notifying the persistent UI. CombatUI is the only combat_ended
consumer. RewardManager does not subscribe to that signal.

Minimal production correction: reset_after_defeat remembers whether combat
was active or retained combatants, clears existing state, then emits
combat_ended once if needed. No victory/reward call, no new ownership.
Stage6G's existing regeneration boundary still resets encounter ownership
and explicitly unfreezes Player before removing RuntimeContent.

Extended stage6j_playable_combat_reset_validation exercises actual Stage6J:
active reset, real public damage/end-turn defeat, defeat reset, idle reset,
lethal card victory, reward/DNA completion, exploration resume, new combat,
another reset, freed enemy and owned patrol markers. Expected totals:
4 endings / 1 reward sequence / 1 defeat. No duplicate idle/postvictory close.
The lethal card is a test fixture, not a gameplay/balance change.

## B — expanded loss-of-contact test defect

The old probe required CHASE immediately after one perception tick. Actual
_evaluate_vision accumulates interval * capability toward detection_time_sec.
The controlled real guard returns ALERT / sight_timer=0.2 after that tick,
then CHASE after sustained exposure. Even proximity override changes capability,
not the detection-time requirement. The old probe also positioned stimuli
relative to an already moving/turning guard without asserting safe support/LOS.
That setup did not establish a reproducible Enemy state-machine regression.

Corrected test fixture uses the real seed 65001 corridor guard, actual patrol
points, navigable frontal stimulus, real perception timer and unmodified light,
speed and timeout data. The existing combat_transition_enabled switch isolates
CHASE/search from APPROACH, then is restored before a real encounter test.
No perception/navigation/state-machine production correction was necessary.

Two losses are exercised: out of range, and a real capsule-clear navigable
point behind actual wall collision, 4.61 m away. The wall tick loses contact;
the player subsequently leaves range to avoid accidental reacquisition while
the guard reaches the saved location. Both preserve LAST KNOWN and traverse
CHASE -> ALERT/search -> PATROL, then resume physical movement. Normal
perception -> encounter -> CombatManager is exercised again with fresh enemies.

Invalid routes are rejected before spawn by the existing V2.1.2 route validator.
Procedural Marker3Ds are owned by Enemy, not by geometry or another scene.
Regeneration frees the old Enemy and its markers together; the focused reset
test verifies those references are no longer valid. Arbitrarily deleting one
marker from a live Enemy is not a supported procedural lifecycle operation;
no speculative shared AI recovery for that unrelated operation was added.

## Validation and reproduction

Godot 4.7.2 stable ed1daf0bf, Windows, headless, real-time physics (not
--fixed-fps). Logs: ../artifacts/varkhem_v2_1_2/stabilize*.log.
Process-local APPDATA points to that artifact directory's appdata child.
Typical invocation from this worktree:

```powershell
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/varkhem_v2_1_2_validation.tscn -- --behavior
```

All following completed with exit 0 and functional PASS:

- stage6j_playable_combat_reset_validation; repeated lifecycle controls.
- varkhem_v2_1_2_validation --behavior: 7 seeds 65001/2/3/4/5/15/20,
  21 real guards, 14 seconds motion each; ACCESS/CORRIDOR/HUB, pauses,
  both waypoint indices, no observed stalls; frontal true, rear/lateral false,
  walk noise at 3.5 m false / run noise true, sound investigation/return,
  range loss, wall LOS loss, real combat and reset.
- varkhem_v2_1_2_validation --contact: isolated repeatable contact/lifecycle.
  Two final repetitions plus the complete --behavior execution exit0 with
  both wall/range cases passing. No simulated-time acceleration.
- varkhem_v2_1_2_validation --inspection: real Player/Enemy doorway passages
  (8), TOP/PLAYER/LOGICAL/ZOOM/FIT, NEW SEED, NEXT SECTOR, combat/reset/UI.
- varkhem_v2_1_2_validation --logical: 100 runs / 160 sectors, 129 topologies.
- varkhem_v2_1_2_validation --from=65001 --to=65050: 50/50, 80 sectors,
  734 unused openings sealed/audited; no overlaps accepted, seams, capsule,
  floor, containment, navigation or transition failures. 80 attempt0,
  0 backtracks; existing limit2 unchanged. Determinism 65001/3/5/15/20.
  222 enemies (same baseline count), 127 circulation / 95 rooms; 4 hub pairs.
  No patrol rejection. Physical assembly metric 21–122 ms, mean63.075 ms
  on this machine; this is not Android performance or total generation time.
- stage6i_runtime_content_encounter_validation (20 seeds / 33 sectors).
- stage6i_content_placement_validation.
- stage6c_combat_integration, stage6e_stats_dna_validation,
  stage6j_canonical_species_dna_validation, stage6a2_oxygen_validation.
- stage6a1b_multisensory_validation, stage5e_encounter_validation,
  stage5e_navigation_validation, stage5f_behavior_validation,
  stage5g_escape_integration, stage5g_double_integration,
  stage5g_drop_integration, stage5h_runtime_patrol.
- stage6h_template_grammar_validation.
- stage6k4a_ship_circuits_logical_validation; Ship physical 67001–67003.
- Horvex scale logical 200 runs / 504 sectors; containment66001–66003,
  8 sectors, 359 openings, all attempt0, no failures.

Editor import exit0: no parse/missing script/resource errors; sandbox-related
editor preferences Safe save error is recorded, not hidden or treated as a
game runtime failure. Normal direct V212 scene load is checked separately.
Direct VarkhemV212ExperienceTest --quit-after120 completed exit0, without
script/resource/runtime errors.

## Separate native-close incident — unresolved

Previous logs behavior_loss_final.log and the initial physical smoke ended
with -1073741819 / 0xC0000005, sometimes after a functional result was printed.
Those executions are failures, never retroactively PASS. A functional assert
cannot explain a native access violation. No faulting engine stack/module has
been established; no engine, navigation or disposal workaround was applied.

This stabilization uses the same Godot binary and headless conditions on clean
V2.1.1 and current V2.1.2: three stage6j_playable_combat_reset_validation
processes each, all exit0. Logs stabilize_native_base_1..3 and
stabilize_native_current_1..3. Current behavior, contact and physical gates
also have their exit codes checked independently. This finite sample does NOT
prove the intermittent native issue resolved or identify its cause.
To investigate separately, repeat the named scene in independent processes,
record the OS exit code and whether failure occurs before/after its final
result; obtain a crash dump if it reappears. Do not hide it with forced exits.

## Scope and manual test

No new gameplay features in stabilization. No solver, geometry, topology,
enemy population, perception tuning, oxygen, DNA, combat/reward rules or
physical limits changed. The existing patrol branch changes are included in
the eventual local V2.1.2 commit, not discarded. V2.1.1 and dirty Horvex
worktrees remain untouched. No publication/merge.

ZIP: RogueSpace_Varkhem_V2_1_2_TEST_MOBILE.zip in the synchronized project root.
Entry (override only inside ZIP): res://scenes/tests/VarkhemV212ExperienceTest.tscn.
Seed65001 shows corridor/access patrols;65003 shows a hub pair.
Use NEW SEED / NEXT SECTOR, TOP VIEW / PLAYER VIEW / LOGICAL MAP / ZOOM / FIT;
INFILTRATION DEBUG toggles actual state/FOV/routes/light/noise diagnostics.
Test detection, loss behind walls, reward completion, reset during combat,
reset after defeat, then another encounter. Avoiding all encounters, fair
stealth windows, Android performance and experience remain MANUAL_REQUIRED.
Existing hearing wall attenuation remains0 and visual lighting is not fully
synchronized with logical light. No elite/mission/extraction V2.2.
