# Survive Ice Yetis For 100 Days 🎃❄️

A multiplayer Roblox survival horror prototype built with Luau and Rojo. The current seasonal look is Halloween in a frozen haunted forest.

## Gameplay
- Survive escalating Ice Yeti hunts across 100 in-game days.
- A short camp intermission separates hunts.
- Server-spawned Ice Yetis chase nearby living players and attack at close range.
- Earn coins for surviving a day and defeating a Yeti.
- Persistent player coins, best day, and 100-day victories via DataStore.
- Halloween atmosphere: fog, frosted dead pines, glowing pumpkins, icy shards, and a warm campfire.

## Project structure
- `src/iceyeti/shared/GameConfig.lua` — shared game tuning.
- `src/iceyeti/server/GameServer.server.lua` — world, server-authoritative rounds, AI, rewards, persistence.
- `src/iceyeti/client/Client.client.lua` — HUD and notices.
- `default.project.json` — Rojo mapping.

The previous prototype's scripts are left in the repository for reference, but the Rojo project mapping excludes them, including the old BossService-dependent game. They will not be inserted into this new place.

## Run locally
1. Open the repository folder in VS Code.
2. Run `git pull origin main`.
3. Start Rojo with `rojo serve default.project.json` and leave the terminal open.
4. In Roblox Studio, create/open a new Baseplate place and connect the Rojo plugin to the local server.
5. Wait for sync, then press **Play**.
6. Use **Test → Start** with 2 players to check multiplayer.
7. For persistence tests, publish a separate test experience and enable **Game Settings → Security → Enable Studio Access to API Services**. Avoid testing against production player data.

## Notes
- This is a playable starter prototype, not a fully balanced campaign yet.
- The world and blocky Ice Yetis are generated at runtime by the server.
- DataStore access is protected with `pcall`; without API access, the game can still start but saves will warn in Output.
- No old BossService is used by this new game.
