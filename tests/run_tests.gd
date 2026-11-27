## Headless tests of the game logic. Run: scripts\test.ps1
extends SceneTree

const Sim = preload("res://game/sim.gd")
const Synth = preload("res://game/synth.gd")
const Sounds = preload("res://game/sounds.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_levels()
	test_sphere_aabb()
	test_serve_and_paddle()
	test_tilted_paddle_aims()
	test_fast_hand()
	test_miss_loses_ball()
	test_walls_keep_ball_in()
	test_brick_breaks()
	test_blast()
	test_blaster_upgrades()
	test_powerups()
	test_two_paddles_and_options()
	test_clear_and_game_over()
	test_long_run()
	test_scripts_and_sounds()
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _hold(sim: Sim, at: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	sim.set_paddle(0, Transform3D(basis, at))
	sim.step(1.0 / 72.0)   # twice: the paddle is at rest there
	sim.set_paddle(0, Transform3D(basis, at))


## A quick pull of the trigger.
func _pull(sim: Sim, hand: int = 0) -> void:
	sim.press(hand)
	sim.release(hand)


## Holds the trigger for `seconds`, lets go, and returns the names of every
## event along the way.
func _charge(sim: Sim, seconds: float, hand: int = 0) -> Dictionary:
	var seen := {}
	sim.press(hand)
	for e in sim.events:
		seen[e[0]] = true
	for i in int(ceil(seconds * 72.0)):
		sim.step(1.0 / 72.0)
		for e in sim.events:
			seen[e[0]] = true
	sim.release(hand)
	for e in sim.events:
		seen[e[0]] = true
	return seen


## Steps for `seconds`; returns the names of the events seen.
func _run(sim: Sim, seconds: float) -> Dictionary:
	var seen := {}
	for i in int(ceil(seconds * 72.0)):
		sim.step(1.0 / 72.0)
		for e in sim.events:
			seen[e[0]] = true
	return seen


## A level in play with a slow ball out of the way and a shield under it.
func _playing(text: String, layer_count: int, at: Vector3) -> Sim:
	var sim := Sim.new()
	sim.load_level_text(text, layer_count)
	_hold(sim, at)
	sim.state = Sim.State.PLAY
	sim.shield_active = true
	sim.balls.append({"id": 900, "pos": Vector3(0.6, -0.5, -1), "vel": Vector3(0, 0, -0.05), "speed": 0.05})
	return sim


func _has(sim: Sim, event: String) -> bool:
	return sim.events.any(func(e: Array) -> bool: return e[0] == event)


func test_levels() -> void:
	for n in range(1, Sim.LEVEL_COUNT + 1):
		check(FileAccess.file_exists(Sim.LEVEL_PATH % n), "level file %d exists" % n)
		var sim := Sim.new()
		sim.start_game(n)
		check(sim.remaining > 0, "level %d has breakable bricks" % n)
		check(sim.layers == (2 if n <= 2 else 3), "level %d wall count" % n)
		for b in sim.bricks:
			var box: AABB = b.aabb
			if absf(box.get_center().x) > Sim.HALF.x or box.position.y < -Sim.HALF.y or box.end.y > Sim.HALF.y \
					or box.position.z < Sim.Z_BACK or box.end.z > Sim.Z_FRONT + 0.001:
				check(false, "level %d brick inside the corridor" % n)
				break
	var sim := Sim.new()
	sim.load_level_text("R.b\n#x\nXCP", 3)
	check(sim.bricks.size() == 15, "5 bricks x 3 walls")
	check(sim.remaining == 12, "metal doesn't count")
	check(sim.bricks[0].colour == "R" and sim.bricks[1].colour == "Y" and sim.bricks[2].colour == "G", "colours shift per wall")
	check(sim.bricks[3].armoured and sim.bricks[3].hp == 2, "lowercase is armoured")


func test_sphere_aabb() -> void:
	var box := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	check(Sim.sphere_aabb(Vector3(0, 0, 2), 0.5, box).is_empty(), "apart")
	var hit := Sim.sphere_aabb(Vector3(0, 0, 1.3), 0.5, box)
	check(not hit.is_empty() and hit.normal.is_equal_approx(Vector3.BACK) and is_equal_approx(hit.depth, 0.2), "face hit")
	hit = Sim.sphere_aabb(Vector3(0.9, 0, 0), 0.1, box)
	check(hit.normal.is_equal_approx(Vector3.RIGHT), "inside: out by the nearest face")


func test_serve_and_paddle() -> void:
	var sim := Sim.new()
	sim.load_level_text("...........\n.....X.....", 1)   # nothing to clear, far away
	sim.remaining = 99
	_hold(sim, Vector3(0, -0.5, 0.2))
	check(sim.state == Sim.State.SERVE, "starts serving")
	_pull(sim)
	check(sim.state == Sim.State.PLAY and sim.balls.size() == 1, "trigger launches")
	check(sim.balls[0].vel.z < 0.0, "towards the wall")
	# Fly out, bounce off the back wall, come back to the waiting paddle.
	var returned := false
	var speed0: float = sim.balls[0].speed
	for i in 72 * 8:
		sim.set_paddle(0, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0.2)))
		sim.step(1.0 / 72.0)
		if _has(sim, "paddle"):
			returned = true
			break
	check(returned, "ball returns to the paddle and bounces")
	check(sim.state == Sim.State.PLAY and sim.balls[0].vel.z < 0.0, "sent back to the wall")
	check(sim.balls[0].speed > speed0, "speeds up on a paddle hit")


func test_tilted_paddle_aims() -> void:
	var sim := Sim.new()
	sim.load_level_text(".", 1)
	sim.remaining = 99
	# Facing 30 degrees to the right (-z turned towards +x).
	_hold(sim, Vector3(0, 0, 0.2), Basis(Vector3.UP, deg_to_rad(-30.0)))
	_pull(sim)
	check(sim.balls[0].vel.x > 0.5, "a tilted field launches where it faces")
	_hold(sim, Vector3(0, 0, 0.2), Basis(Vector3.UP, deg_to_rad(-120.0)))
	check(sim.paddle_normal().angle_to(Vector3.FORWARD) <= Sim.PADDLE_MAX_TILT + 0.001, "tilt is limited")
	sim.set_paddle(0, Transform3D(Basis.IDENTITY, Vector3(9, 9, 9)))
	check(sim.paddles[0].origin.x <= Sim.HALF.x and sim.paddles[0].origin.z <= Sim.PADDLE_Z.y, "paddle stays in the corridor")


## A paddle swept quickly through the ball's path still hits it.
func test_fast_hand() -> void:
	var sim := Sim.new()
	sim.load_level_text(".", 1)
	sim.remaining = 99
	_hold(sim, Vector3(0, 0, 0.3))
	sim.state = Sim.State.PLAY
	sim.balls.append({"id": 1, "pos": Vector3(0, 0, -0.3), "vel": Vector3(0, 0, 3.0), "speed": 3.0})
	# One frame: the hand jumps 0.6 m forward, past where the ball is.
	sim.set_paddle(0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.3)))
	sim.step(1.0 / 72.0)
	check(_has(sim, "paddle"), "fast forward swing hits the ball")
	check(sim.balls[0].vel.z < 0.0, "and returns it")


func test_miss_loses_ball() -> void:
	var sim := Sim.new()
	sim.load_level_text(".", 1)
	sim.remaining = 99
	_hold(sim, Vector3(0.6, 0.4, 0.2))
	sim.state = Sim.State.PLAY
	sim.balls.append({"id": 1, "pos": Vector3(-0.5, -0.3, 0.0), "vel": Vector3(0, 0, 3.0), "speed": 3.0})
	for i in 40:
		sim.step(1.0 / 72.0)
	check(sim.balls_left == 2 and sim.state == Sim.State.SERVE, "a missed ball costs a life")
	_pull(sim)
	check(sim.state == Sim.State.SERVE, "serve is locked for a moment")
	# The Shield saves one.
	sim.state = Sim.State.PLAY
	sim.shield_active = true
	sim.balls.append({"id": 2, "pos": Vector3(-0.5, -0.3, 0.3), "vel": Vector3(0, 0, 3.0), "speed": 3.0})
	for i in 10:
		sim.step(1.0 / 72.0)
	check(sim.balls.size() == 1 and sim.balls[0].vel.z < 0.0 and not sim.shield_active, "shield saves one ball")


func test_walls_keep_ball_in() -> void:
	var sim := Sim.new()
	sim.load_level_text(".", 1)
	sim.remaining = 99
	sim.state = Sim.State.PLAY
	sim.shield_active = true
	sim.balls.append({"id": 1, "pos": Vector3(0, 0, -2), "vel": Vector3(2.0, 1.7, -1.5).normalized() * 5.0, "speed": 5.0})
	var sides := {}
	var inside := true
	for i in 72 * 6:
		sim.shield_active = true
		sim.step(1.0 / 72.0)
		for e in sim.events:
			if e[0] == "wall":
				sides[e[1][0]] = true
		var p: Vector3 = sim.balls[0].pos
		if absf(p.x) > Sim.HALF.x or absf(p.y) > Sim.HALF.y or p.z < Sim.Z_BACK:
			inside = false
	check(inside, "ball stays inside the corridor")
	check(sides.size() == 5, "all five walls rebound it (%s)" % str(sides.keys()))
	check(absf(sim.balls[0].vel.z) >= Sim.MIN_Z_RATIO * 5.0 - 0.01, "never too flat")


func test_brick_breaks() -> void:
	var sim := Sim.new()
	sim.load_level_text(".....r.....\n.....R.....", 2)
	sim.state = Sim.State.PLAY
	sim.shield_active = true
	var target: AABB = sim.bricks[0].aabb   # armoured, front wall
	sim.balls.append({"id": 1, "pos": target.get_center() + Vector3(0, 0, 1.0), "vel": Vector3(0, 0, -3), "speed": 3.0})
	for i in 40:
		sim.step(1.0 / 72.0)
		if _has(sim, "armour"):
			break
	check(sim.bricks[0].hp == 1 and sim.bricks[0].alive, "armoured brick takes the first hit")
	check(sim.balls[0].vel.z > 0.0, "ball bounces back off the wall")
	check(sim.score == 0, "no points yet")
	sim.balls[0].vel = Vector3(0, 0, -3)
	for i in 40:
		sim.step(1.0 / 72.0)
		if _has(sim, "brick"):
			break
	check(not sim.bricks[0].alive and sim.score == 180, "second hit breaks it: 120 x 1.5")
	check(sim.bricks[1].alive and sim.bricks[1].colour == "Y", "the wall behind still stands")


func test_blast() -> void:
	var probe := Sim.new()
	probe.load_level_text(".....R.....\n...........\nBBBBBBBBBBB", 1)
	var row_y: float = probe.bricks[0].aabb.get_center().y
	var sim := _playing(".....R.....\n...........\nBBBBBBBBBBB", 1, Vector3(0, row_y, 0.2))
	var seen := _charge(sim, 0.3)
	check(seen.has("charge_start") and sim.blasts.is_empty() and is_equal_approx(sim.power, 1.0), "a short pull charges but fires nothing")
	seen = _charge(sim, Sim.BLAST_CHARGE_TIME * 1.3)
	check(seen.has("charged") and seen.has("blast"), "held to level 1 and released: a blast")
	check(sim.blasts.size() == 1 and sim.blasts[0].level == 1 and is_equal_approx(sim.power, 2.0 / 3.0), "level 1 costs a third of the bar")
	check(sim.charge_hand == -1 and sim.blast_charge == 0.0, "the charge is spent")
	_run(sim, 1.0)
	check(not sim.bricks[0].alive and sim.blasts.is_empty(), "the blast breaks the brick it meets")
	# Held all the way: level 3 fires by itself and empties the bar.
	sim.power = 1.0
	sim.press(0)
	var top := 0
	for i in int(72 * Sim.BLAST_CHARGE_TIME * 3.4):
		sim.step(1.0 / 72.0)
		for e in sim.events:
			if e[0] == "blast":
				top = e[1][2]
	check(top == 3 and sim.power < 0.01, "a full charge fires at level 3 by itself (got %d)" % top)
	_run(sim, 0.3)
	check(sim.blast_charge == 0.0, "and doesn't charge again until the trigger is let go")
	sim.release(0)
	check(sim.blasts.size() <= 1, "letting go after that fires nothing more")
	seen = _charge(sim, 0.7)
	check(seen.has("blast_fail") and not seen.has("blast"), "empty bar: a warning, no shot")
	# Two cells: the charge stops at level 2.
	sim.power = 0.7
	sim.blasts.clear()
	_charge(sim, Sim.BLAST_CHARGE_TIME * 3.5)
	check(sim.blasts.size() == 1 and sim.blasts[0].level == 2, "the charge stops at what the bar can pay")
	var p := sim.power
	_run(sim, 3.0)
	check(sim.power > p, "the bar recharges")
	# No charging while serving: the pull is the launch.
	sim = Sim.new()
	sim.load_level_text("R", 1)
	_hold(sim, Vector3(0, 0, 0.2))
	seen = _charge(sim, 1.0)
	check(sim.balls.size() == 1 and sim.blasts.is_empty() and not seen.has("charged"), "the launching pull doesn't charge")


func test_blaster_upgrades() -> void:
	var text := ".....r.....\n...........\n...........\nB.........."
	var probe := Sim.new()
	probe.load_level_text(text, 3)
	var row_y: float = probe.bricks[0].aabb.get_center().y
	var at := Vector3(0, row_y, 0.2)
	var hold := Sim.BLAST_CHARGE_TIME * 1.2
	# T: three bolts for one cell.
	var sim := _playing(text, 3, at)
	sim.apply_powerup("T")
	check(sim.max_level() == 1, "an upgrade fires at level 1")
	sim.press(0)
	_run(sim, hold)
	check(sim.blasts.size() == 3 and is_equal_approx(sim.power, 2.0 / 3.0), "triple laser: three bolts, one cell")
	sim.release(0)
	# P: a level-3 bolt for one cell.
	sim = _playing(text, 3, at)
	sim.apply_powerup("P")
	_charge(sim, hold)
	check(sim.blasts.size() == 1 and sim.blasts[0].level == 3 and is_equal_approx(sim.power, 2.0 / 3.0), "power laser: level 3 for one cell")
	# B: one more plasma ball, for the whole bar.
	sim = _playing(text, 3, at)
	sim.apply_powerup("B")
	var seen := _charge(sim, hold)
	check(sim.balls.size() == 2 and seen.has("bounce_ball") and sim.power < 0.01, "bounce plasma: another ball, whole bar")
	seen = _charge(sim, hold)
	check(sim.balls.size() == 2 and seen.has("blast_fail"), "no bar, no second ball")
	# I: the beam fries everything on its line, armour and all.
	sim = _playing(text, 3, at)
	sim.apply_powerup("I")
	seen = _charge(sim, hold)
	check(seen.has("ion_beam"), "ion cannon fires a beam")
	check(not sim.bricks[0].alive and not sim.bricks[1].alive and not sim.bricks[2].alive, "the beam goes through all three walls")
	check(sim.bricks[3].alive, "and leaves the rest")
	# W: the wave weaves across the wall.
	sim = _playing("RRRRRRRRRRR\n...........\n...........\n..........B", 1, at)
	sim.apply_powerup("W")
	seen = _charge(sim, hold)
	check(seen.has("wave_fire") and sim.waves.size() == 1, "wave beam fires")
	_run(sim, 1.5)
	var dead := sim.bricks.filter(func(b: Dictionary) -> bool: return not b.alive).size()
	check(dead >= 2 and sim.waves.is_empty(), "the wave breaks several bricks (%d) and leaves" % dead)
	# H: the missile finds a brick that is not straight ahead.
	sim = _playing("R..........\n...........\n...........\n..........B", 1, Vector3(0, -0.3, 0.2))
	sim.apply_powerup("H")
	seen = _charge(sim, hold)
	check(seen.has("missile_fire") and sim.missiles.size() == 1, "homing missile fires")
	seen = _run(sim, 3.0)
	check(seen.has("missile_blast") and sim.missiles.is_empty(), "the missile explodes")
	check(sim.remaining == 1, "on a brick it steered to (%d left)" % sim.remaining)


func test_powerups() -> void:
	var sim := Sim.new()
	sim.load_level_text("RRRRRRRRRRR", 2)
	sim.state = Sim.State.PLAY
	sim.shield_active = true
	sim.balls.append({"id": 1, "pos": Vector3(0, -0.5, -2), "vel": Vector3(0, 0, -0.1), "speed": 3.0})
	_hold(sim, Vector3(0.3, 0.1, 0.2))
	sim.spawn_capsule(Vector3(0.3, 0.1, -0.5), "K")
	var seen := _run(sim, 2.0)
	check(seen.has("pu_get") and sim.padup == "K", "a capsule drifts to the paddle and is caught")
	check(is_equal_approx(sim.paddle_half().x, Sim.PADDLE_HALF.x + Sim.SIDEKICK_W), "sidekicks widen the field")
	sim.spawn_capsule(Vector3(-0.7, -0.5, 0.0), "S")
	_run(sim, 2.0)
	check(sim.capsules.is_empty() and sim.padup == "K", "a missed capsule is gone")
	# Two slots: a blaster upgrade doesn't push out a paddle upgrade.
	sim.apply_powerup("T")
	check(sim.powerup == "T" and sim.padup == "K", "blaster and paddle slots are separate")
	sim.apply_powerup("I")
	check(sim.powerup == "I" and sim.padup == "K", "a new blaster replaces the old one")
	sim.apply_powerup("S")
	check(sim.padup == "S" and sim.shield_active and sim.powerup == "I", "a new paddle upgrade replaces the old one")
	check(is_equal_approx(sim.paddle_half().x, Sim.PADDLE_HALF.x), "no sidekicks any more")
	# The shield saves one ball and is used up.
	sim.balls.append({"id": 2, "pos": Vector3(-0.5, -0.3, 0.3), "vel": Vector3(0, 0, 3.0), "speed": 3.0})
	seen = _run(sim, 0.15)
	check(seen.has("shield_save") and sim.padup == "" and not sim.shield_active, "the shield saves a ball and is spent")
	# Lightspeed: afterimages trail a moving paddle and stop the ball too.
	sim.apply_powerup("L")
	check(sim.ghosts().is_empty(), "no afterimages at rest")
	for i in 20:
		sim.set_paddle(0, Transform3D(Basis.IDENTITY, Vector3(0.3 - i * 0.04, 0.1, 0.2)))
		sim.step(1.0 / 72.0)
	check(sim.ghosts().size() >= 1, "a moving paddle leaves afterimages")
	if not sim.ghosts().is_empty():
		var g: Transform3D = sim.ghosts()[0]
		sim.balls.clear()
		sim.balls.append({"id": 3, "pos": g.origin + Vector3(0, 0, -0.1), "vel": Vector3(0, 0, 3.0), "speed": 3.0})
		var bounced := false
		for i in 4:
			sim.set_paddle(0, Transform3D(Basis.IDENTITY, Vector3(0.3 - (20 + i) * 0.04, 0.1, 0.2)))
			sim.step(1.0 / 72.0)
			bounced = bounced or _has(sim, "ghost")
		check(bounced and sim.balls.size() == 1 and sim.balls[0].vel.z < 0.0, "an afterimage returns the ball")
	# Instants.
	var lives := sim.balls_left
	sim._use_instant("U")
	check(sim.balls_left == lives + 1, "1UP")
	# Losing the ball ends both upgrades.
	sim.apply_powerup("T")
	sim.balls.clear()
	sim.step(1.0 / 72.0)
	check(sim.powerup == "" and sim.padup == "" and sim.state == Sim.State.SERVE, "a lost ball ends the upgrades")
	sim.state = Sim.State.PLAY
	sim._use_instant("N")
	check(sim.remaining == 0 and sim.state == Sim.State.LEVEL_CLEAR, "nuclear clears the walls")
	# Drops: the pity rule guarantees one within DROP_PITY + 1 bricks, and the
	# two kinds of upgrade take turns.
	sim = Sim.new()
	sim.state = Sim.State.PLAY
	for i in 40:
		sim._maybe_drop(Vector3.ZERO)
	check(sim.capsules.size() >= 2, "bricks drop capsules (%d in 40)" % sim.capsules.size())
	seed(3)
	var last := ""
	var alternates := true
	var kinds := {}
	for i in 400:
		var k := sim.random_kind()
		kinds[k] = true
		if k in Sim.INSTANT_KINDS:
			continue
		var group := "paddle" if k in Sim.PADDLE_KINDS else "blaster"
		if group == last:
			alternates = false
		last = group
	check(alternates, "blaster and paddle drops alternate")
	check(kinds.size() == 11, "every kind can drop (%d)" % kinds.size())


func test_two_paddles_and_options() -> void:
	var sim := Sim.new()
	sim.paddle_count = 2
	sim.load_level_text("R", 1)
	sim.set_paddle(0, Transform3D(Basis.IDENTITY, Vector3(0.4, 0.2, 0.2)))
	sim.set_paddle(1, Transform3D(Basis.IDENTITY, Vector3(-0.4, -0.2, 0.2)))
	sim.step(1.0 / 72.0)
	_pull(sim, 1)
	check(sim.balls.size() == 1 and sim.balls[0].pos.x < -0.3 and sim.serve_hand == 1, "the pulling hand's paddle launches")
	sim.balls[0].pos = Vector3(-0.4, -0.2, 0.0)
	sim.balls[0].vel = Vector3(0, 0, 3.0)
	var hit_index := -1
	for i in 20:
		sim.step(1.0 / 72.0)
		for e in sim.events:
			if e[0] == "paddle":
				hit_index = e[1][2]
	check(hit_index == 1, "the second paddle stops the ball")
	# Charge on one hand, fire from that paddle.
	sim.power = 1.0
	sim.shield_active = true
	_charge(sim, Sim.BLAST_CHARGE_TIME * 1.2, 1)
	check(sim.blasts.size() == 1 and sim.blasts[0].pos.x < -0.3, "the blast leaves the paddle that charged it")
	sim.press(0)
	sim.press(1)
	check(sim.charge_hand == 0, "one charge at a time")
	sim.release(1)
	check(sim.charge_hand == 0, "the other trigger doesn't cancel it")
	sim.release(0)
	# With one paddle, the second is not there.
	sim = Sim.new()
	sim.load_level_text("R", 1)
	sim.set_paddle(0, Transform3D(Basis.IDENTITY, Vector3(0.4, 0.2, 0.2)))
	sim.set_paddle(1, Transform3D(Basis.IDENTITY, Vector3(-0.4, -0.2, 0.2)))
	sim.step(1.0 / 72.0)
	sim.state = Sim.State.PLAY
	sim.balls.append({"id": 1, "pos": Vector3(-0.4, -0.2, 0.0), "vel": Vector3(0, 0, 3.0), "speed": 3.0})
	_run(sim, 0.5)
	check(sim.balls_left == 2, "one-paddle mode: the other hand stops nothing")
	# Options.
	sim.start_lives = 5
	sim.start_game()
	check(sim.balls_left == 5, "lives option")
	var speeds := []
	for speed_name in Sim.SPEED_ORDER:
		sim.speed = speed_name
		sim.start_game()
		_hold(sim, Vector3(0, 0, 0.2))
		_pull(sim)
		speeds.append(sim.balls[0].speed)
	check(speeds[0] < speeds[1] and speeds[1] < speeds[2], "speed option: slow < normal < fast %s" % str(speeds))


func test_clear_and_game_over() -> void:
	var sim := Sim.new()
	sim.load_level_text("R", 1)
	sim.state = Sim.State.PLAY
	sim.balls.append({"id": 1, "pos": sim.bricks[0].aabb.get_center() + Vector3(0, 0, 0.3), "vel": Vector3(0, 0, -3), "speed": 3.0})
	for i in 30:
		sim.step(1.0 / 72.0)
	check(sim.state == Sim.State.LEVEL_CLEAR and sim.score == 120 + Sim.RACK_BONUS, "last brick clears the level, with a bonus")
	sim.next_level()
	check(sim.level == 2 and sim.state == Sim.State.SERVE and sim.remaining > 0, "next level loads")
	sim._add_score(Sim.EXTRA_LIFE_AT[0])
	check(sim.balls_left == 4, "extra life at the score mark")
	sim.balls_left = 1
	sim.state = Sim.State.PLAY
	sim.step(1.0 / 72.0)
	check(sim.state == Sim.State.OVER and _has(sim, "over"), "last ball lost: game over")
	sim.start_game()
	check(sim.score == 0 and sim.balls_left == 3 and sim.level == 1, "a new game resets")


## A paddle that always meets the ball: minutes of play, every level's bricks,
## nothing may leave the corridor or get stuck.
func test_long_run() -> void:
	seed(7)
	for lvl in [1, 7, 13, 20]:
		var sim := Sim.new()
		sim.start_game(lvl)
		var start := sim.remaining
		var ok := true
		for i in 72 * 150:
			var at := Vector3(sin(i * 0.01) * 0.3, cos(i * 0.013) * 0.2, 0.25)
			for b in sim.balls:
				if b.vel.z > 0.0:
					at = Vector3(b.pos.x + sin(i * 0.02) * 0.1, b.pos.y + cos(i * 0.017) * 0.06, 0.25)
			sim.set_paddle(0, Transform3D(Basis.IDENTITY, at))
			if sim.state == Sim.State.SERVE:
				_pull(sim)
			elif sim.charge_hand < 0 and sim.power >= 1.0:
				sim.press(0)      # charge to the top: it fires by itself
			elif sim.charge_hand >= 0 and sim._await_release:
				sim.release(0)
			sim.step(1.0 / 72.0)
			for b in sim.balls:
				var p: Vector3 = b.pos
				if absf(p.x) > Sim.HALF.x or absf(p.y) > Sim.HALF.y or p.z < Sim.Z_BACK or is_nan(p.x):
					ok = false
			if sim.state == Sim.State.LEVEL_CLEAR or sim.state == Sim.State.OVER:
				break
		check(ok, "level %d: balls stay in the corridor" % lvl)
		check(sim.remaining < start - 10, "level %d: bricks get broken (%d of %d left, state %d)" % [lvl, sim.remaining, start, sim.state])


func test_scripts_and_sounds() -> void:
	for path in ["res://game/main.gd", "res://game/fx.gd", "res://game/menu.gd", "res://game/settings.gd",
			"res://game/backdrop.gd", "res://game/enemy_bodies.gd"]:
		var s := load(path) as GDScript
		check(s != null and s.can_instantiate(), "%s compiles" % path)
	var main_src := FileAccess.get_file_as_string("res://game/main.gd")
	var rx := RegEx.new()
	rx.compile("\"(tb_[a-z0-9_]+)\"")
	for m in rx.search_all(main_src):
		check(Sounds.SOUNDS.has(m.get_string(1)), "sound %s exists" % m.get_string(1))
	var wav := Synth.make(Sounds.SOUNDS["tb_brick"])
	check(wav.data.size() > 1000, "synth makes a sound")
