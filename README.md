# PITCH — Competitive Soccer

PITCH is a Roblox soccer game built with Luau and Rojo. Development follows the milestone brief: stabilize the foundation and test it before implementing ball physics, player actions, full match rules, matchmaking, AI, and ranked progression.

## Current milestone: 1 — Foundation

- Modular Rojo layout with shared configuration, centralized remotes, utility modules, server services, and a client HUD.
- Configuration-driven pitch: 150 studs wide x 240 studs long, alternating turf bands, halfway line, centre circle, penalty areas, goal areas, penalty spots, corner arcs, goals/nets, grandstands, floodlight towers, and invisible boundary walls.
- Server-generated position markers: `TeamASpawn`, `TeamBSpawn`, `KickoffSpot`, and `BallSpawn`, each with attributes for downstream services.
- Balanced Red and Blue teams; respawning players are placed at their team's marker.
- DataService template includes Coins, XP, Level, Wins, Losses, Goals, Assists, Saves, MatchesPlayed, EquippedKit, EquippedBallTrail, EquippedGoalEffect, and Owned.
- Legacy-data safety: keeps DataStore name `IceYetiSurvival_v1` and keys `player_<UserId>`. Loads previous lowercase aliases and writes a merged profile with `UpdateAsync`, preserving unrelated legacy fields such as historical `wins`, `bestDay`, `wood`, `stone`, `trophies`, and `discoveries`.
- Studio-only `/stats` and `/pitch` development commands.
- Runtime code does not try to write the Studio-only `Lighting.Technology` property. Set Lighting > Technology to Future manually in Studio if available.

## Rojo project structure

- `src/shared/Remotes.lua` — creates RemoteEvents on the server and exposes a client retrieval method.
- `src/shared/Config/` — `PitchConfig.lua`, `BallConfig.lua`, `PlayerConfig.lua`, `MatchConfig.lua`, `RewardsConfig.lua`.
- `src/shared/Util/` — `Maid.lua` and `Signal.lua`.
- `src/server/Bootstrap.server.lua` — initializes services in a fixed order.
- `src/server/Services/DataService.lua` — profiles, reconciliation, saves, migration-safe merges.
- `src/server/Services/PitchService.lua` — stadium generation and position markers.
- `src/server/Services/TeamService.lua` — team assignment and spawn placement.
- `src/server/Services/MatchService.lua` — initial server-owned Lobby state and state snapshots.
- `src/server/DevCommands.server.lua` — Studio-only commands.
- `src/client/UI/PITCHHUD.client.lua` — foundation status and profile HUD.
- `default.project.json` — maps only the new foundation into Roblox Studio. Legacy source folders are not mapped.

## Pull and run

1. Open this repository folder in VS Code.
2. Stop the old Rojo process with `Ctrl+C` in its terminal.
3. Run `git pull --ff-only origin main`.
4. Run `rojo serve default.project.json` and leave the terminal open.
5. Connect the Roblox Studio Rojo plugin to the host/port printed by Rojo (often `127.0.0.1:34872`).
6. Press Stop if a Studio playtest is active, reconnect Rojo, wait for sync, then press Play.
7. In Studio Explorer, verify `ReplicatedStorage.Shared`, `ServerScriptService.Services`, and `StarterPlayer.StarterPlayerScripts.UI` exist. Remove stale `IceYetiServer`, `IceYetiClient`, or previous `SoccerServer` script instances if they remain after sync; do not delete the new `Bootstrap`, `Services`, or `PITCHHUD` instances.
8. In Output, confirm a line like `[PITCH] Pitch generated: 150 x 240 studs; goals, markings, spawns and stands are ready.`
9. In the Studio chat, try `/stats` to print the loaded profile and `/pitch` to regenerate the pitch.

## Milestone 1 acceptance tests

- [ ] Play starts with no runtime errors; Output shows `[Bootstrap] Initialized ...` for all four services.
- [ ] A green pitch appears with turf bands, field markings, goals/nets, stands, floodlights, and safety walls.
- [ ] The player spawns inside the pitch. Join with two Studio test clients and verify they are assigned Red/Blue and spawn on opposite sides.
- [ ] `Workspace` has `PitchReady = true`; `Workspace.SoccerStadium` has `PitchReady = true` and pitch dimension attributes.
- [ ] `/stats` prints the profile; rejoin in a published test experience with API access enabled to verify persistence.
- [ ] Inspect an existing test player record before and after saving; confirm legacy fields remain. Do not test against production data.

## Known limits and next milestone

- This is only Milestone 1. The pitch and team foundation are implemented; the ball is not yet simulated, and kicking/goals/match rules are not considered complete. Milestone 2 will add the server-owned ball, validated kick inputs, speed caps, ball recovery, and math-based goal/boundary detection. Do not move to that milestone until the foundation acceptance tests pass.
- Studio execution and DataStore persistence could not be run from this environment; validate the acceptance checklist locally.
- To get higher-fidelity shadows, set Lighting > Technology to Future in Studio if the option is available; scripts deliberately do not set that restricted property.