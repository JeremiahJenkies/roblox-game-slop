# PITCH — Competitive Soccer ⚽

A multiplayer Roblox soccer prototype built with Luau and Rojo. It generates a stadium at runtime, uses server-validated kicks and server-owned ball physics, tracks goals and match results, and saves player progression.

## Current gameplay
- A generated full-size green pitch with mowing stripes, touchlines, halfway line, penalty areas, goals, netting, and grandstands.
- Balanced Red and Blue team assignment.
- Match intermission, 3-minute live match, scoreboard, and full-time rewards.
- Kick with **E** on keyboard or the on-screen **KICK** button on touch devices. On PC, aim using the mouse.
- The server validates kick distance, direction, cooldown, match phase, and goal scoring.
- Persistent player wins, goals, assists, matches, clean sheets, and credits are displayed/saved where implemented.
- Future-friendly Rojo layout with shared configuration, server gameplay, and client HUD.

## Project structure
- `src/soccer/shared/GameConfig.lua` — pitch, match, kick, and persistence configuration.
- `src/soccer/server/GameServer.server.lua` — stadium generation, teams, ball physics, scoring, match loop, and saves.
- `src/soccer/client/Client.client.lua` — scoreboard, team card, notifications, and kick controls.
- `default.project.json` — Rojo mapping.

## Run locally
1. Open this existing repository in VS Code.
2. Run `git pull --ff-only origin main` (or use **Terminal → Run Task → PITCH: Sync latest GitHub changes**).
3. If a Rojo server is already running for this folder, keep using it; otherwise run **Terminal → Run Task → PITCH: Start Rojo**.
4. In Roblox Studio, open the place you want to use and connect the Rojo plugin to `127.0.0.1:34872` if that is the port shown by the running server.
5. Wait for sync, then press **Play**. Use **Test → Start** with 2 or more players to test teams and goals.
6. Publish a separate test experience and enable **Game Settings → Security → Enable Studio Access to API Services** before testing persistence. Do not test against production data.

## Save-data compatibility
- The game intentionally keeps the existing DataStore name `IceYetiSurvival_v1` and key format `player_<UserId>`.
- Existing fields (`coins`, `bestDay`, `wins`, `wood`, `stone`, `xp`, `trophies`, `discoveries`, `dataVersion`) are retained when loaded and written back; new soccer stats are added.
- Writes merge the soccer payload into the previous record with `UpdateAsync`, so unrecognised fields are not discarded.
- Legacy `wins`, `bestDay`, resource counts, XP, trophies, and discoveries remain intact. Soccer match wins use a separate `soccerWins` field, so old survival wins are not reinterpreted as soccer wins.
- Test with a separate test experience first. Roblox DataStores are scoped to an experience, and this code cannot transfer records between different experiences automatically.

## Known prototype limitations
- This is the first playable soccer foundation, not a finished competitive release. Test ball collisions, goal detection, player team balancing, mobile controls, and DataStore behavior in Studio.
- Assists and clean sheets are saved/displayed as stats fields but are not yet awarded by gameplay logic.
- Character animations, goalkeeper logic, fouls, ranked matchmaking, latency compensation, and custom player rigs are not included yet.
- No live Roblox Studio test has been run from this environment.