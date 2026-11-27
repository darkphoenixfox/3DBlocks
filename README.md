# 3D Blocks

A VR block breaker in the style of Tilt Breaker (PinGames), built with Godot 4.7 and OpenXR.

You stand at the near end of a corridor made of four energy walls, floating in orbit with the Earth below. Walls of circuit bricks stand at the far end, one behind another. Your paddle is Tilt Breaker's ship inside a rectangular energy field. It follows your controller, and the field is what stops the plasma ball.

"3D Blocks" is a working title.

## Playing

| | |
|---|---|
| Trigger | In the menus: click what you point at. In play: launches the plasma; hold to charge the blaster, release to fire. With one paddle, pulling a trigger also takes the paddle into that hand. |
| B / Y | Recentre: the corridor moves to where you stand, at chest height. |
| Menu button | Back to the menu. |

- Move your hand to move the paddle; tilt it to aim the return. Where the ball lands on the field also steers it, as in Tilt Breaker.
- A ball that gets past you is lost. Extra lives at 20,000 and 50,000 points.
- The power bar is the three cells along the bottom of the energy field. It refills over time and with each hit.
- **Charged shots:** hold the trigger and the blaster charges through three levels, as far as the bar can pay (one cell per level). Release to fire; level 3 fires by itself. A level-n bolt goes through n bricks.
- **Power-ups** drift towards you from broken bricks; catch them with the field. There are two kinds, held in two separate slots (shown under the corridor), and both are lost with the ball:
  - Blaster upgrades (spheres with orbiting electrons) change what a charged shot does: **T** triple laser, **P** power laser (a level-3 bolt for one cell), **B** bounce plasma (an extra ball, whole bar), **I** ion cannon (a beam through every wall, whole bar), **W** wave beam (whole bar), **H** homing missile (whole bar).
  - Paddle upgrades (two-tone pills): **S** shield (saves one ball behind you), **L** lightspeed (afterimages of a moving paddle also stop the ball), **K** sidekicks (a mini ship each side: a wider field).
  - Rare instants: **U** 1UP, **N** nuclear (clears the walls).
- Bricks: glowing frame = armoured (2 hits), grey = indestructible, red frame = charged (2 hits), a brick with a plasma ball inside frees it when broken.
- The 20 levels are Tilt Breaker's, each built as 2 walls (levels 1-2) or 3 walls of bricks, the colours shifting from wall to wall.
- Tilt Breaker's enemies fly past outside the corridor now and then, in and out of wormholes. They are scenery.

## Options

OPTIONS in the menu; saved in `user://settings.cfg`.

| | |
|---|---|
| Speed | Slow, normal or fast ball. |
| Lives | 1 to 5. |
| Room size | Small, normal, large or huge: the whole corridor (paddle and ball included) scaled 0.75x to 1.5x, so you reach and step more or less. |
| Paddles | One (in whichever hand pulled the trigger last) or two, one per hand. Each trigger launches and charges from its own paddle. |
| Eye training | The ball is drawn in one eye only, the paddles and bricks in the other, swapping every level. The walls, HUD and power-ups stay in both eyes. The "ready" prompt says which eye has the ball. |
| Music, SFX | Volume, 0 to 10. |

## Running

```powershell
scripts\run_vr.ps1            # VR: start SteamVR or Quest Link first
scripts\run.ps1               # desktop preview: mouse = paddle, click/space = trigger, R = recentre
scripts\run.ps1 --demo        # plays itself
scripts\test.ps1              # headless tests of the game logic
scripts\build_quest.ps1       # Quest APK -> exports\3DBlocks-quest.apk
```

Dev flags (after `--`): `--demo`, `--start`, `--level=N`, `--pu=T,K` (start with power-ups), `--menu=options`, `--screenshot=<png>`, `--screenshot-delay=<s>`, `--cam=x,y,z`.
Option overrides, not saved: `--paddles=2`, `--eye`, `--room=0..3`, `--speed=0..2`, `--lives=N`. In the preview, eye training shows the left eye's picture.
`scripts/dev_run.sh` runs the preview off-screen and silent, for screenshots.

## Layout

- `game/sim.gd`: the game logic, no nodes. All tuning values are constants at the top (corridor size, ball speeds, paddle size, brick spacing, power-ups).
- `game/main.gd`: the VR rig, the scene, input, HUD and sound. Everything is built in code; no editor work is needed.
- `game/menu.gd`, `game/settings.gd`: the menu panel and the saved options.
- `game/backdrop.gd`, `game/enemy_bodies.gd`: the enemies that fly past outside.
- `shaders/eye.gdshaderinc`: the per-eye switch for eye training (`eye_ball` / `eye_world` shader globals).
- `game/fx.gd`, `shaders/`: plasma ball, trail, planet, energy walls, paddle field, bricks, explosions.
- `game/synth.gd`, `game/sounds.gd`: Tilt Breaker's synthesized sound effects.
- `levels/`: Tilt Breaker's level files.
- `assets/`: see `CREDITS.md`.

## Not carried over from Tilt Breaker (yet)

Enemies and bosses as opponents (they only fly past), torpedoes from charged bricks, two players and high scores.
