# Changelog

All dates use ISO format (YYYY-MM-DD). Newest entries first.

## 2026-10-10 — PITCH competitive soccer conversion

- Replaced the mapped Yeti survival server and HUD with a soccer stadium, Red/Blue teams, kick controls, ball physics, goals, match timer, scoreboard, and full-time rewards.
- Fixed stadium startup: removed a runtime write to `Lighting.Technology` (a Studio-only setting) that could stop the server before the pitch and ball were created.
- Added server-side startup diagnostics plus stadium atmosphere, color grading, bloom, sun rays, clouds, floodlight towers, and longer grandstands.
- Added a clean `src/soccer` source layout and updated `default.project.json` to map only the soccer game into Studio.
- Updated VS Code task names and project README for PITCH.
- Preserved the existing `IceYetiSurvival_v1` DataStore name and `player_<UserId>` key pattern. New saves merge fields into existing records; legacy profile fields remain.
- Verification is repository-level only. Ball physics, goal detection, multiplayer balance, and DataStore persistence still require Roblox Studio playtests.