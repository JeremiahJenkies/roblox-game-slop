# Changelog

All dates use ISO format (YYYY-MM-DD). Newest entries first.

## 2026-10-10 — Playable practice mode
- Added a server-owned football with black panel details, validated Pass/Shoot/Lob/Clearance actions, cooldown and distance checks, speed limiting, anti-tunnelling, stuck/out-of-bounds recovery, moving-player dribble nudges, and goal-plane scoring.
- Added a score registration method for practice mode and server-side player Goal/Assist XP awards.
- Mapped the new client input controller; included Q/E/F controls, mobile buttons and local ball shadow.
- Updated the HUD to clear old interface instances and display the practice score plus stadium/ball readiness.
- Added server-bootstrap cleanup for stale legacy Yeti/monolithic soccer server folders and cleaned old HUD/local script instances.
- Improved player presentation by removing large legacy accessories/tools from the foundation character and applying Red/Blue torso colours.
- Repository-level checks only; Studio playtest still required.

## 2026-10-10 — Milestone 1 foundation
- Added modular services, config modules, centralized RemoteEvents, Maid and Signal utilities.
- Added generated soccer pitch, goals/nets, stepped grandstands, supports, floodlights, spawn markers and team-side placement.
- Preserved existing DataStore name/key layout and merged player profile writes with UpdateAsync.
- Removed the restricted runtime attempt to set Lighting.Technology; set it manually in Studio if desired.