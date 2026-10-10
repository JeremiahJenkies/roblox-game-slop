# Changelog

## 2026-10-10 — Advanced dribbling and first-touch control
- Added server-validated Feint and Step Over skill moves, with a cooldown and checks for match phase, player life state, ball distance, and opposing possession.
- Added Z (Feint) and X (Step Over) keyboard controls plus mobile buttons.
- Ball carrier's close-control target shifts side-to-side briefly during skills rather than teleporting the ball.
- First-touch acquisition cushions the ball's horizontal speed and spin while retaining part of its momentum.
- Preserved the existing remote system, DataStore configuration, player profile keys, kicking, tackling, and restart flow.
- Roblox Studio runtime/multiplayer testing has not been performed in this environment.

## 2026-10-10 — Close-control dribbling and tackles
- Replaced loose velocity nudges with server-controlled AlignPosition possession, keeping the ball unanchored but following the ball carrier's feet.
- Automatically gives possession to the nearest living player who reaches the ball; the ball follows in front of their facing direction while they move or pause.
- Kicks and restarts release possession so the ball returns to normal physics.
- Added server-validated tackle steals against a nearby opposing carrier, with distance, facing, team and cooldown checks.
- Added C on keyboard and a TACKLE button on touch controls.
- Roblox Studio multiplayer physics testing is still required; this change has not been run in Studio here.

## 2026-10-10 — Invisible boundary barriers and out-of-bounds restarts
- Moved invisible side and end barriers closer to the playable field, while leaving room for server out-of-bounds detection to trigger first.
- Preserved throw-ins on the sidelines and corner/goal-kick decisions beyond the goal lines, based on the last-touching team.
- Kept the goals and goal nets open for valid scoring before the end-line safety barriers.
- Roblox Studio physics and match-flow testing is still required.

## 2026-10-10 — Bobble heads, close control and shot power
- Enlarged every player's head to 135% and added a client-side bobble animation that varies with movement.
- Added server-controlled soft possession: when a moving player is close to the ball, the server nudges the ball into a controllable position ahead of their feet. It is not welded or anchored, so kicks and physics remain responsive.
- Added a draggable 20–100% kick-power slider shared by passes, shots and lobs; the server still validates the requested power.
- Fixed goal attribution after half-time side switching: goal scoring teams now depend on which half is active.
- Fixed the goal lock edge case when a goal-plane crossing is rejected during a stoppage.
- Cleared possession on kick-offs and restarts and avoided overwriting assist history with repeated dribble touches.
- Roblox Studio multiplayer QA is still required before release; code has not been executed in Studio by this environment.


## 2026-10-10 — Match systems, stamina and cosmetics
- Added fixed 60 Hz custom-force stepping for air drag, ground rolling resistance, sliding friction, spin decay, angular-speed caps and grounded sleep handling.
- Added Studio-only ball test commands: `/ballreset`, `/ballshoot`, `/ballout` and `/ballinfo`.
- Reworked match lifecycle around intermission, kick-off, timed halves, half-time, full-time and automatic rematches.
- Added duplicate-goal protection, goal/restart countdown alignment, match participation/win/draw/loss rewards, and half-time team-side switching.
- Added server-authoritative sprint requests, stamina drain/regeneration and a client stamina meter; client no longer sets its own WalkSpeed.
- Added configurable match options and supported team-size presets, plus visual-quality preset configuration.
- Added an earnable cosmetic catalog and server-validated locker for kits, ball trails and goal effects. Cosmetics do not grant gameplay advantages.
- Kept the existing DataStore name and player key scheme unchanged.
- Studio multiplayer, mobile, physics and DataStore tests are still required; these changes have not been run in Roblox Studio from this environment.


All dates use ISO format (YYYY-MM-DD). Newest entries first.

## 2026-10-10 — Playable soccer practice build
- Added timed two-half match flow, kick-off countdowns, goal restarts, half-time, full-time and automatic next-match setup.
- Added out-of-bounds restart decisions for throw-ins, corners and goal kicks; the scoreboard subtitle now identifies live match mode.
- Added a sprint toggle using Shift on keyboard and a large SPRINT button on touch devices; uses configured walk/sprint speeds.
- Reworked pass, shoot and lob controls into larger high-contrast mobile buttons while retaining Q/E/F keyboard shortcuts; standard Roblox movement controls remain enabled.
- Made the goal side and rear nets collidable so the ball is contained instead of passing through the netting.
- Added server-owned football, panel visuals, validated Pass/Shoot/Lob/Clearance requests, kick range/cooldown checks, speed cap, anti-tunnelling, stuck-ball recovery, moving-player dribble nudges and goal-plane scoring.
- Added practice score registration and server-side goal/assist XP awards.
- Mapped the client input controller with Q/E/F actions, on-screen touch buttons and local ball shadow.
- Cleaned stale previous HUDs and added ball/stadium readiness display.
- Added cleanup for stale Yeti/monolithic soccer server folders; simplified avatar appearance for team readability.
- Updated documentation to describe the current playable practice mode.
- Repository-level checks passed; a Roblox Studio playtest is still required.

## 2026-10-10 — Modular foundation
- Added modular service bootstrap, shared configuration, centralized remotes, Maid and Signal utilities.
- Added configurable pitch, lines, goals/nets, stepped stands, floodlights, spawn markers and Red/Blue team placement.
- Preserved the existing DataStore name/key format and merged profile writes with UpdateAsync.
- Removed the restricted runtime assignment to Lighting.Technology.