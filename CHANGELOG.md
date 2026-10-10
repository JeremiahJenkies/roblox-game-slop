# Changelog

All dates use ISO format (YYYY-MM-DD). Newest entries first.

## 2026-10-10 — 99-night progression foundation

- **Game identity and night target:** renamed the configured game to "Survive 99 Nights in the Forest" and set the target to 99 nights.
- **ProgressionService:** added server-only XP calculations, trophy milestone rules, and a configurable trophy-based XP multiplier.
- **Survival rewards:** surviving a night awards XP based on night number; every 10th night grants a trophy, and Night 99 grants a completion trophy bundle.
- **Profile compatibility:** added optional `xp`, `trophies`, and `dataVersion` fields while preserving the existing `IceYetiSurvival_v1` DataStore and `player_<UserId>` keys. Existing profiles are reconciled with defaults when loaded.
- **HUD:** displays XP, trophies, current XP multiplier, and existing exploration discovery progress.
- **Connected systems:** GameConfig → GameServer → ProgressionService → saved player profile → HUD.
- **Verification:** repository changes were inspected for expected integration points. A live Roblox Studio playtest and DataStore test are still required.

## 2026-10-10 — Forest exploration

- Added Abandoned Cabin, Frostwatch Tower, and Frost Cave landmarks.
- Added one-time, persistent exploration rewards and a 0/3–3/3 discovery HUD.
- Preserved existing profile fields and DataStore keys.
