# PITCH — Competitive Soccer

Current build: competitive soccer foundation with a generated stadium, server-owned ball, validated kicking, timed match lifecycle, stamina-based sprinting, match rewards, and an earnable cosmetic locker. Online matchmaking, goalkeeper/bot AI, full animation set, replays and ranked seasons remain future work.

## Features in this build
- Configurable 150 x 240 stud football pitch with mowing stripes, field markings, penalty/goal boxes, goals and nets, stepped grandstands, supports, floodlights, and atmosphere/color grading.
- Server-owned football with black panel detailing, validated Pass/Shoot/Lob/Clearance actions, range/cooldown checks, speed cap, fixed 60 Hz custom-force stepping, air drag, rolling resistance, spin decay, grounded sleep, spherecast anti-tunnelling assistance, stuck/out-of-bounds recovery, moving-player dribble nudges and mathematical goal-plane detection.
- Advanced ball control: server-validated feints and step-over moves on Z/X (or mobile buttons), short skill-move cooldowns, side-offset close control, and first-touch cushioning that reduces incoming ball speed while preserving momentum.
- Match lifecycle: intermission, kick-off, two halves, half-time, full-time, score updates, team-side switching and automatic rematches; configurable throw-in, corner and goal-kick restarts.
- Server-authoritative sprint and stamina drain/regeneration; clients send intent rather than setting their own movement speed.
- Signature 1.35x bobble heads with movement-reactive wobble on every player.
- Close-control dribbling: when a player reaches the ball, a server-controlled AlignPosition keeps the unanchored ball at their feet and ahead of their facing direction; kicking releases possession.
- Server-validated tackle steals: press C or use the TACKLE button to challenge a nearby opposing ball carrier, with range, facing, team and cooldown checks.
- A mouse/touch kick-power slider (20–100%) shared by shots, passes and lobs; power is revalidated on the server.
- Goal scoring adapts to the teams switching ends at half-time and rejects stoppage-time crossings without leaving the goal lock stuck.
- Cosmetic locker with earnable kits, ball trails and goal effects. Purchases/equipping are validated by the server and never affect competitive stats.
- Practice scoreboard and profile HUD; keyboard controls Q=Pass, E=Shoot, F=Lob, C=Tackle, Shift=toggle sprint, plus large touch-screen Pass/Shoot/Lob/Sprint buttons. Standard Roblox movement controls remain enabled.
- Red/Blue teams, balanced assignment, side-based respawns and simple team-coloured player appearance.
- DataService profile template and merged UpdateAsync writes; existing DataStore name `IceYetiSurvival_v1` and `player_<UserId>` keys are preserved. Legacy fields are not intentionally dropped.
- Stale `IceYetiServer`/`SoccerServer` folders, old player LocalScripts and legacy HUDs are removed during startup.
- Scripts do not write the restricted `Lighting.Technology` property. Set Lighting > Technology to Future manually in Studio, if available.

## Source structure
- `src/shared/Remotes.lua`, `src/shared/Config/`, `src/shared/Util/` — remotes, settings and utilities.
- `src/server/Bootstrap.server.lua` — ordered services and stale-server cleanup.
- `src/server/Services/DataService.lua` — profile loading, migration aliases and merged saves.
- `src/server/Services/PlayerService.lua` — server-side sprint and stamina.
- `src/server/Services/CosmeticService.lua` — validated cosmetic purchases and equipment.
- `src/server/Services/PitchService.lua` — generated pitch, markings, goals, stepped stands and lighting.
- `src/server/Services/TeamService.lua` — teams, player appearance and spawn placement.
- `src/server/Services/MatchService.lua` — practice score state and goal rewards.
- `src/server/Services/BallService.lua` — ball physics, kicks, ball recovery and goal detection.
- `src/server/DevCommands.server.lua` — Studio-only `/stats`, `/pitch`, `/ballreset`, `/ballshoot`, `/ballout` and `/ballinfo`.
- `src/client/UI/PITCHHUD.client.lua` — score, clock, profile and status HUD.
- `src/client/UI/CosmeticShop.client.lua` — cosmetic locker interface.
- `src/client/Controllers/InputController.client.lua` — input controls and local ball shadow.

## Sync to Roblox Studio
1. Stop Play mode.
2. From this repository directory, run `git pull --ff-only origin main`.
3. Stop the old Rojo process with Ctrl+C; run `rojo serve default.project.json`.
4. Connect Studio's Rojo plugin to the host/port printed by that command.
5. Press Play. Output should contain `[PITCH] Pitch generated`, `[BallService] Server-owned football created at kickoff`, and `[PITCH] Foundation bootstrap complete.`
6. In Explorer, verify `Workspace > SoccerStadium > MatchBall`, `ServerScriptService > Services > BallService`, and `StarterPlayer > StarterPlayerScripts > Controllers > InputController`.
7. Wait through intermission for kick-off. Move within 13 studs of the ball. Press Q to pass, E to shoot or F to lob; use the on-screen buttons on touch devices. Hold Shift or tap Sprint to request a sprint; watch the stamina meter. Open KIT SHOP to test cosmetic equipment and purchases.

## Persistence notes
- Store name `IceYetiSurvival_v1` and key `player_<UserId>` intentionally remain unchanged.
- Writes merge new soccer fields into existing records. Old survival `wins`, `bestDay`, `wood`, `stone`, `trophies` and `discoveries` remain separate legacy values.
- Use a separate published test experience with Studio API access enabled for persistence tests; different experiences do not automatically share DataStores. Cosmetic purchases use saved in-game credits only; Robux products and ProcessReceipt are not implemented.

## Test status
- Repository paths and Rojo mapping have been checked against the project configuration.
- The new service code has not been executed inside Roblox Studio from this environment. Run a 2-player Studio test for goals in both halves, repeated goals, out-of-bounds restarts, dribble possession changes, kick power at 20% and 100%, bobble-head appearance on R6/R15, full-time rewards, sprint stamina and cosmetics before publishing.
- This is not yet the complete 12-part mega-prompt: matchmaking/reserved servers, bot and goalkeeper AI, replays, full animation/audio, ranked seasons, receipt-safe Robux products and performance profiling still need implementation and Studio QA.

### Impulse dribbling controls
- Pass: Q; Shoot: E; Lob: F; Tackle: C; Sprint: Shift.
- Feint: Z; Step-over: X; Knock-on: V; Drag-back: B; Quick turn: G; Shield: H.
- Tuning: `src/shared/Config/DribbleConfig.lua`. The ball stays server-owned; dribbling applies capped impulses rather than attaching the ball to a player.
- Studio-only chat commands: `/dribbledebug`, `/dribbledebugoff`, `/dribletouch`, `/dribbleskill 0.0` through `/dribbleskill 1.0`.
- Animation IDs are placeholders (0); replace them with published animation asset IDs before adding animation playback. Touch sound IDs are blank placeholders.
