# Client controllers

Milestone 1 intentionally includes only the foundation HUD under `src/client/UI`.

Future client-side gameplay inputs belong here, in small LocalScripts or ModuleScripts:
- `InputController` — PC, mobile, and gamepad intent only; gameplay actions are validated on the server.
- `BallController` — cosmetic interpolation and ball visuals only; never owns or decides authoritative ball physics.
- `AnimationController` — client presentation, with server validation for action permissions.
- `CameraController` — later milestone camera polish.

Do not create client-side scoring, goal detection, match-clock authority, or rewards. Those remain server-owned.