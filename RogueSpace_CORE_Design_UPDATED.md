# RogueSpace — CORE DESIGN / NON-NEGOTIABLES

Version: 0.2 — September 2026

> Nomenclatura vigente de demo: las referencias históricas a Orc/Xenomorph
> corresponden a Varkhen (Carnotauro/Raptor) y Horvex (Avispa). Los IDs
> internos heredados pueden permanecer para compatibilidad; el balance vivo
> pertenece a CURRENT STATE, no a estas reglas CORE.

## Purpose

This document is the continuity/constitution of RogueSpace. It contains design rules and architectural decisions that should not be contradicted unless the user explicitly changes them.

`CORE_Design.md` describes what RogueSpace is supposed to be. It is not a live implementation log.

## Identity

RogueSpace is a first-person retro space-fantasy/dark roguelike dungeon game for PC, Android and Google Cardboard.

- Retro low-spec visual target inspired by classic Doom-style corridors/labyrinths and inexpensive 2D/2.5D enemy presentation.
- Dark fantasy + alien/sci-fi atmosphere.
- Cardboard is a core differentiator, not a later add-on.
- Normal non-VR play is also supported.
- Scope control and low Android/Cardboard performance cost are priorities.
- The user does not code; AI is used for implementation and review.
- The assistant acts as technical/design director: preserve coherence, detect contradictions and control scope.
- Coding agents must work narrowly within the requested task and must not refactor unrelated systems without explicit approval.

## First playable demo

The first demo/tutorial dungeon is intentionally small:

1. Orc fortress.
2. Orcs guard a well leading to xenomorph caves.
3. Xenomorph cave section.
4. Final room: giant xenomorph boss; entering the room starts combat.

Enemies:

- Orc melee.
- Orc rogue.
- Xenomorph.
- Giant xenomorph boss.

Orc melee and rogue may share exploration/AI structure while differing in visuals and combat decks.

## Exploration

Movement is continuous, not grid-based. A logical 1 m/cell concept may be used for design values, but movement is not grid restricted.

Player movement/noise:

- STEALTH noise radius = 1.
- WALK noise radius = 3.
- RUN noise radius = 5.

Movement speed and noise are separate configurable concepts.

Noise radius and noise intensity should remain conceptually separate.

Oxygen is a future/provisional system:

- 0.1% per exploration tile/meter.
- Common combat = 3 oxygen.
- Elite = 5.
- Boss = 10.
- Partial recovery after boss.
- Low-oxygen emergency escape planned.
- Oxygen is not a direct combat reward.

## Enemy perception — VISION and HEARING

Perception has two distinct channels:

1. Vision.
2. Hearing/noise.

They must not be accidentally merged.

### Vision

Each enemy should expose configurable values such as:

- vision_range.
- vision_angle/FOV.
- detection_time_sec.
- light-detection capability/curve.

Current design values are documented in `CURRENT_State.md`; CORE only defines the behavior.

Vision checks:

1. Distance.
2. FOV.
3. Line of sight.
4. Lighting at the PLAYER'S position.
5. Sustained visual exposure.

Walls block vision.

Darkness is NOT a visual wall. An enemy keeps its FOV and geometric LOS through dark areas; darkness only makes the player harder to detect.

A future closed door blocks vision; an open door does not.

### Vision detection behavior

Conceptually:

- No valid perception → no detection.
- Valid but insufficient visual exposure → ALERT.
- Confirmed visual identification → CHASE.

A brief peripheral sighting shorter than the configured detection time must not automatically cause CHASE.

Detection must be deterministic rather than repeated random rolls every frame.

Lighting changes the rate/ability of visual confirmation; it must not turn the system into a frame-by-frame dice roll.

Very close, direct, clearly visible situations should strongly tend toward reliable detection, with total darkness/explicit enemy limitations remaining valid exceptions.

### Current lighting/detection model

Logical light levels are 0–5.

The current implementation direction uses the player's light level to modulate the accumulation of visual detection time:

`sight_timer += delta * light_detection_capability`

Therefore, conceptually:

- Light 0 → capability 0 → vision cannot confirm while remaining at that light level; the enemy can remain ALERT.
- Low light → slower confirmation.
- High light → faster confirmation.
- Maximum capability → approximately `detection_time_sec`.

Do not reintroduce the old binary `chase_capability_threshold` model.

A provisional example curve is:

- 0 = 0%
- 1 = 15%
- 2 = 50%
- 3 = 80%
- 4 = 90%
- 5 = 100%

These are balance examples, not immutable final numbers.

### Hearing

Player noise:

- STEALTH = 1.
- WALK = 3.
- RUN = 5.

Sound:

- Does not provide exact directional information.
- Provides an approximate investigation location/area.
- Walls can block or attenuate sound.
- Future closed doors reduce sound reach by about 1.
- New noises can update the investigation target.

`noise_response_mode` must only control responses to HEARD NOISE. It must never convert a visual `ALERT` into a visual `CHASE`.

Example:

- Orc hears noise → ALERT.
- Xenomorph hears noise → can CHASE directly.

That distinction must remain intact.

## Enemy AI states

### PATROL

- Clear confirmed vision → CHASE.
- Heard noise → ALERT.

### ALERT

- Investigate the last known visual/noise location.
- New noises can update the target.
- Confirmed clear vision → CHASE.
- After about 7 seconds without useful new information → return to patrol/original behavior.

### CHASE

- Direct confirmed vision → pursue.
- Loss of vision → move toward last known position.
- New noise may update the target.
- Without vision/new information → ALERT/investigation.

Different chase speeds are intentional. Some enemies should be escapable; the Xenomorph should be difficult to escape.

Future elites/bosses/special races may have different detection behavior through configurable parameters, but no special-case system should be added unless designed.

## Xenomorph role

The Xenomorph is the aggressive hunter/ambush enemy of the demo.

Its exploration behavior should communicate:

- superior perception to ordinary Orcs;
- strong response to noise;
- difficulty escaping once it has confirmed the player;
- static/ambush behavior before detection rather than ordinary patrol.

Exact numerical perception values belong in `CURRENT_State.md`, not here.

## Lighting architecture

Lighting is both gameplay and world design.

Do not assign arbitrary random light values every meter.

Preferred logical structure:

- ambient/environmental light;
- `LightingManager`;
- `LightSource` point sources;
- resulting local logical light level 0–5.

No grid is required.

Multiple nearby light sources must be able to contribute together. Their logical contributions should accumulate and then be clamped to 0–5 rather than one source arbitrarily replacing another.

Example:

`ambient 1 + torch A 2 + torch B 2 = 5`

The procedural generator should eventually place sources according to biome/environment rules, not random noise.

Examples:

- Orc fortress: dark corridors, torches/braziers, important rooms brighter, deliberate dark areas.
- Xenomorph cave: very low ambient light, dark zones, future biological/bioluminescent sources.

Future requirement: logical light and visible light should eventually be synchronized closely enough for the player to understand the lighting visually.

The current prototype may use logical/debug light without changing `DirectionalLight`/`WorldEnvironment`.

## Single source of truth for logical light

Gameplay systems that need the player's light level should query the same `LightingManager.get_light_level_at(world_position)` source.

Do not duplicate the lighting formula in Enemy, Player, HUD, or other consumers.

The player's debug light value and the enemy's PLAYER LIGHT value should therefore agree.

## Combat

Combat is Slay-the-Spire-like card combat in the actual 3D world.

- Maximum active deck = 10.
- Draw 4 cards per turn; future upgrade may raise to 5.
- Stamina limits actions.
- No player movement during combat.
- Camera remains completely free.

### Critical VR rule

Never automatically rotate the camera, instantly or smoothly, during combat.

Enemies remain in their actual 3D positions.

There is no separate combat arena and no forced front-facing arrangement.

Targeting:

- Manual enemy panels must always remain available.
- Gaze targeting also exists.
- Manual selection temporarily overrides gaze.
- PC keyboard targeting can be expanded later.

Multiple enemies:

- Maximum current combatants = 2.
- Enemies that independently detect the player within approximately 1.5 seconds may join.
- Do not group enemies merely because they are nearby.

Approach:

- Enemies physically approach.
- Stop at combat distance.
- No teleport.
- Combat begins after approach or safety timeout.

PC card keys: 1–4 provisionally.

Android/Cardboard:

- Right-side drag controls camera.
- Card buttons remain separate.
- Movement joystick is disabled during combat.
- Voice card commands are deferred.

## Current combat prototype design

Player:

- HP 30.
- Stamina 3.
- Provisional weapon damage 10.
- Basic Hit = 1 stamina, damage based on equipped weapon.
- Basic Defense = 1 stamina, currently 6 block.

Orc melee:

- 40 HP.
- Basic attack = 8.
- Defense = 5 block.
- Special = 12.

Xenomorph:

- Zarpazo = 8.
- Postura Defensiva = 5 block.
- Current deck = 2× Zarpazo + 1× Postura.

## DNA/progression

Normal DNA comes from combat rewards.

- Normal drop chance = 20%.
- Development sandbox may temporarily use 100% for testing.
- Orc enemies drop Orc DNA.
- Xenomorphs drop Xenomorph DNA.
- No cross-species random DNA.

Current demo:

- Each DNA unit = +1 DNA level.
- DNA applies to sword, shield or suit.
- Special card unlock does not auto-equip.
- It can replace an eligible ATTACK/DEFENSE card.
- Active deck remains max 10.
- No mid-combat deck changes.

### Orc DNA

Sword:

- Each level = +2 Basic Hit damage.
- Level 3 = Heavy Strike, 25 damage, cost 3, can replace an ATTACK.
- Level 5 Weaken planned/deferred.

Shield:

- Each level = +2 Basic Defense.
- Level 3 = Heavy Shield, 25 block, cost 2, can replace a DEFENSE.
- Level 5 Counterattack planned/deferred.

Suit:

- Each level = +5 max HP.
- Level 3 = +10 additional HP.
- Level 5 Resistencia = start combat with 5 block/armor on first turn.

### Xenomorph DNA

Sword:

- Each level = +5% chance for basic attacks to inflict poison.
- Poison lasts combat.
- Poison deals 5 damage at end of enemy turn.
- Poison does not stack.
- Level 3 Acid Strike planned/deferred.
- Level 5 Acid Claw planned/deferred.

Shield:

- Each level = +2 defense.
- Level 3 Carapace = 20 block, cost 2.
- Level 5 Acid Defense planned/deferred.

Suit:

- Each level = +2 max HP.
- Each level = +1% crit chance to Basic Hit and Claw.
- Crit = +30% damage.
- Level 3 = +10 max HP.
- Level 5 Garras = remaining Basic Hit cards become Claw cards; Claw keeps Basic Hit damage and adds 20% crit chance.
- Later resolve the distinction between Garras and Acid Claw.

Deferred poison/status/counterattack/weaken systems are not to be implemented until designed.

## Rewards

Rewards happen after the full encounter, not per enemy.

Current sequence:

1. Summary.
2. DNA choice.
3. Result.
4. Unlock.
5. Incorporate/leave out.
6. Choose replacement.
7. Kit.
8. End.

Usable object roll:

- 10% once per encounter.
- First-aid kit restores 15 HP.
- Oxygen tank restores 20 oxygen once oxygen exists.
- If already at max HP, do not offer first-aid kit.

## Debug and scope control

## Navigation architecture for authored and future modular dungeons

Navigation must be derived from the physical architecture rather than drawn as
door-by-door waypoint or hand-maintained clearance data. The intended pipeline
is: assembled modules/CSG geometry → automatically derived static-collider
source proxies → one global baked NavigationMesh → NavigationRegion3D →
NavigationAgent3D. The visual/physical module geometry remains the sole source
of truth; proxies are build data only and must not participate in gameplay
physics, perception, LOS or combat. Future procedural work may assemble
modules, but does not change this requirement and is not implied by it.

`DebugConfig` controls development-only debug systems.

Debug features must remain development-only and should not become gameplay requirements.

Do not introduce unnecessary:

- procedural complexity;
- advanced acoustic simulation;
- random lighting noise;
- forced camera rotation;
- extra inventories;
- systems not explicitly designed.

Future stealth chain:

`Perception → Stealth → Positioning → Ambush → Combat`

Possible silent kill/back attack/critical mechanics are deferred until perception, lighting and noise are stable.

## Non-negotiable implementation discipline

When using Claude, Codex or another coding agent:

1. Read this document and `CURRENT_State.md` before modifying relevant systems.
2. Modify only the files necessary for the requested task.
3. Do not alter combat/camera/targeting/rewards while working on perception or lighting unless explicitly requested.
4. Do not replace an existing design decision with a new architecture simply because it is technically convenient.
5. Do not claim a test was executed if the agent could not actually execute it.
6. Clearly separate implemented behavior, planned behavior and proposed behavior.
7. If documentation and code disagree, report the discrepancy before silently changing unrelated systems.
8. Prefer small, testable changes over broad refactors.
