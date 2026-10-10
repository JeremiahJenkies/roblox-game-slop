# Changelog

All dates use ISO format (YYYY-MM-DD). Newest entries first.

## 2026-10-10 — Milestone 1: modular soccer foundation

- Added a fixed-order server bootstrap, service modules, centralized RemoteEvent creation, Maid and Signal utilities, and a foundation HUD.
- Added centralized pitch, ball, player, match and reward configuration modules.
- Added a generated 150 x 240 stud football pitch with field markings, goals/nets, Red/Blue spawn markers, stands, floodlights, ambient lighting effects, and invisible outer boundaries.
- Added balanced team assignment and team-side respawn placement.
- Added profile template for Coins, XP, Level, Wins, Losses, Goals, Assists, Saves, MatchesPlayed, equipped cosmetics, and Owned.
- Kept DataStore `IceYetiSurvival_v1` and `player_<UserId>` keys; data loading reconciles old lowercase fields and saves merge into existing records, retaining legacy survival fields.
- Added Studio-only `/stats` and `/pitch` commands.
- Removed the superseded monolithic soccer scripts from the repository source tree; Rojo now maps the modular `src/shared`, `src/server/Services`, and `src/client/UI` implementation.
- Validation so far is repository-level only. Milestone 1 acceptance tests must be run in Studio before implementing Milestone 2 ball physics.