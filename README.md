# PITCH — Competitive Soccer

Roblox soccer prototype built with Luau and Rojo. The active project is now a playable practice-mode foundation; match timer/halves and ranked features remain upcoming.

## Current build
- Configurable generated football pitch (150 x 240 studs), mowing stripes, touchlines, halfway, centre circle, penalty/goal boxes, corner arcs, goals/nets, stepped stands, supports, floodlight towers, atmosphere and color grading.
- Server-created football with dark panel detailing, server-owned physics, validated Pass/Shoot/Lob/Clearance requests, speed cap, anti-tunnelling checks, stuck/out-of-bounds recovery, low-frequency dribble nudges, and mathematical goal-plane scoring.
- Practice score and player profile HUD; pass `Q`, shoot `E`, lob `F`, plus on-screen touch buttons.
- Red/Blue teams and side-based spawn locations.
- Server-controlled profile updates and persistent Coins/XP/Level/Wins/Losses/Goals/Assists/Saves/MatchesPlayed/cosmetic ownership template.
- Cleanup of stale `IceYetiServer`, `SoccerServer`, old `IceYetiClient` and HUD instances when the new startup runs.
- Runtime scripts don't set the restricted `Lighting.Technology` property. For higher quality shadows, choose `Future` in Studio's Lighting properties.

## Structure
- `src/shared/Remotes.lua` — centralized RemoteEvents.
- `src/shared/Config/` — pitch, ball, player, match, rewards configuration.
- `src/shared/Util/` — Maid and Signal helpers.
- `src/server/Bootstrap.server.lua` — fixed service order and legacy server cleanup.
- `src/server/Services/DataService.lua` — profile loading, migration, merged saves.
- `src/server/Services/PitchService.lua` — pitch, markings, goals, stands and lighting.
- `src/server/Services/TeamService.lua` — balanced teams, spawning, simple team-coloured player appearance.
- `src/server/Services/MatchService.lua` — practice score state and goal reward registration.
- `src/server/Services/BallService.lua` — ball physics, kick validation, dribbling and goal crossing.
- `src/server/DevCommands.server.lua` — Studio-only `/stats` and `/pitch`.
- `src/client/UI/PITCHHUD.client.lua` — scoreboard, profile and readiness status.
- `src/client/Controllers/InputController.client.lua` — PC/mobile input buttons and local ball shadow.

## Sync to Studio
1. Stop Play mode.
2. In the project folder, run `git pull --ff-only origin main`.
3. Stop the old Rojo terminal with Ctrl+C and run `rojo serve default.project.json`.
4. Reconnect the Rojo Studio plugin to the host/port printed by Rojo.
5. Press Play. Verify Output contains `[PITCH] Pitch generated`, `[BallService] Server-owned football created`, and `[PITCH] Foundation bootstrap complete.`
6. In Explorer, check `Workspace.SoccerStadium.MatchBall`, `ServerScriptService.Services.BallService`, and `StarterPlayer.StarterPlayerScripts.Controllers.InputController`.
7. Move within 13 studs of the ball and try Q (Pass), E (Shoot), F (Lob), or the on-screen buttons. Score a goal to verify the practice scoreboard changes.

## Persistence compatibility
- Deliberately retains `IceYetiSurvival_v1` and `player_<UserId>`.
- Existing legacy keys such as lowercase `coins`, historical `wins`, `bestDay`, `wood`, `stone`, `xp`, `trophies`, and `discoveries` are preserved on merged saves. Old survival wins are not converted to soccer wins.
- DataStore testing should use a separate published test experience with API access enabled. Records do not automatically transfer to a separate experience.

## Known limits
- This is practice mode, not yet a finished competitive release. Formal halves, kick-off/restarts, fouls, goalkeeper controls, matchmaking, latency compensation and ranked ladders are still planned.
- Repository source has been checked for intended Rojo mappings and the previous restricted `Lighting.Technology` assignment. It has not been executed inside Roblox Studio here; physics, mobile inputs and DataStore behavior still require a local test.