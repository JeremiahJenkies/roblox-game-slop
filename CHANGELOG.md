# Changelog

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