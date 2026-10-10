# PITCH — Competitive Soccer

Current build: playable practice foundation with a generated pitch, a server-owned ball, basic kicking and practice scoring. Full matches, halves, fouls, goalkeeper logic, matchmaking and ranked mode are future milestones.

## Features in this build
- Configurable 150 x 240 stud football pitch with mowing stripes, field markings, penalty/goal boxes, goals and nets, stepped grandstands, supports, floodlights, and atmosphere/color grading.
- Server-owned football with black panel detailing, validated Pass/Shoot/Lob/Clearance actions, range/cooldown checks, speed cap, anti-tunnelling check, stuck/out-of-bounds recovery, moving-player dribble nudges and mathematical goal-plane detection.
- Practice scoreboard and profile HUD; keyboard controls Q=Pass, E=Shoot, F=Lob plus touch-screen buttons.
- Red/Blue teams, balanced assignment, side-based respawns and simple team-coloured player appearance.
- DataService profile template and merged UpdateAsync writes; existing DataStore name `IceYetiSurvival_v1` and `player_<UserId>` keys are preserved. Legacy fields are not intentionally dropped.
- Stale `IceYetiServer`/`SoccerServer` folders, old player LocalScripts and legacy HUDs are removed during startup.
- Scripts do not write the restricted `Lighting.Technology` property. Set Lighting > Technology to Future manually in Studio, if available.

## Source structure
- `src/shared/Remotes.lua`, `src/shared/Config/`, `src/shared/Util/` — remotes, settings and utilities.
- `src/server/Bootstrap.server.lua` — ordered services and stale-server cleanup.
- `src/server/Services/DataService.lua` — profile loading, migration aliases and merged saves.
- `src/server/Services/PitchService.lua` — generated pitch, markings, goals, stepped stands and lighting.
- `src/server/Services/TeamService.lua` — teams, player appearance and spawn placement.
- `src/server/Services/MatchService.lua` — practice score state and goal rewards.
- `src/server/Services/BallService.lua` — ball physics, kicks, ball recovery and goal detection.
- `src/server/DevCommands.server.lua` — Studio-only `/stats` and `/pitch`.
- `src/client/UI/PITCHHUD.client.lua` — score/profile/status HUD.
- `src/client/Controllers/InputController.client.lua` — input controls and local ball shadow.

## Sync to Roblox Studio
1. Stop Play mode.
2. From this repository directory, run `git pull --ff-only origin main`.
3. Stop the old Rojo process with Ctrl+C; run `rojo serve default.project.json`.
4. Connect Studio's Rojo plugin to the host/port printed by that command.
5. Press Play. Output should contain `[PITCH] Pitch generated`, `[BallService] Server-owned football created at kickoff`, and `[PITCH] Foundation bootstrap complete.`
6. In Explorer, verify `Workspace > SoccerStadium > MatchBall`, `ServerScriptService > Services > BallService`, and `StarterPlayer > StarterPlayerScripts > Controllers > InputController`.
7. Move within 13 studs of the ball. Press Q to pass, E to shoot or F to lob; use the on-screen buttons on touch devices. Shoot into a goal to test the practice score.

## Persistence notes
- Store name `IceYetiSurvival_v1` and key `player_<UserId>` intentionally remain unchanged.
- Writes merge new soccer fields into existing records. Old survival `wins`, `bestDay`, `wood`, `stone`, `trophies` and `discoveries` remain separate legacy values.
- Use a separate published test experience with Studio API access enabled for persistence tests; different experiences do not automatically share DataStores.

## Test status
- Repository and Rojo mapping checks passed.
- Not run inside Roblox Studio from this environment. Check ball physics, goal detection, touch controls, visual performance and DataStore persistence locally before public release.