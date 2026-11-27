## 3D Blocks gameplay simulation: pure logic, no nodes. The view (main.gd)
## renders it; tests drive it headless. Based on Tilt Breaker's sim (PinGames),
## taken into a room: a corridor of energy walls with the brick walls at the far
## end and the player's hand-held paddle (or two) at the near end.
##
## Coordinates are metres in "arena space": x right, y up (0 = the corridor's
## centre line), -z away from the player. The player stands near z = +0.85.
## (The view may scale the whole arena: the room size option.)
extends RefCounted

# --- arena ------------------------------------------------------------------------
const HALF := Vector2(0.8, 0.6)       # half width, half height of the corridor
const Z_BACK := -3.6                  # far wall
const Z_DRAIN := 0.6                  # a ball that gets this far past the player is lost
const Z_SHIELD := 0.5                 # the Shield power-up's barrier
# --- paddle -----------------------------------------------------------------------
const PADDLE_HALF := Vector2(0.20, 0.13)   # half size of the energy field
const SIDEKICK_W := PADDLE_HALF.x * 2.0 / 3.0   # K: each sidekick adds this much reach per side
const PADDLE_Z := Vector2(-0.8, 0.45)      # how far the hand may push / pull it
const PADDLE_MAX_TILT := deg_to_rad(40.0)  # from facing straight at the wall
const SERVE_DIST := 0.12                   # the ball waits this far in front of it
# --- ball -------------------------------------------------------------------------
const BALL_R := 0.035
const BALL_START_SPEED := 3.0
const BALL_MAX_SPEED := 5.6
## Speed option: the plasma's start speed and cap, times these.
const SPEEDS := {"slow": [0.8, 0.85], "normal": [1.0, 1.0], "fast": [1.18, 1.15]}
const SPEED_ORDER := ["slow", "normal", "fast"]
const LEVEL_SPEED := 0.08             # start speed added per level
const SPEEDUP_PER_PADDLE_HIT := 0.08
const MIN_Z_RATIO := 0.38             # never travel flatter than this (no endless side loops)
const MAX_SUBSTEP := 0.02             # metres per collision substep (no tunnelling)
const MAX_BALLS := 6
const SERVE_LOCK := 1.2               # s before the next launch after a lost ball
# --- paddle return -----------------------------------------------------------------
## Arkanoid-style: where the ball lands on the field steers it (edge = this much
## sideways for one unit forward); the field's own tilt aims it; a little of the
## mirror bounce is kept so it still feels physical.
const OFFSET_STEER := 0.55
const MIRROR_KEEP := 0.3
const ENGLISH := 0.06                 # per m/s of sideways paddle speed
# --- bricks -----------------------------------------------------------------------
const COLS := 11
const ROWS := 10                      # most rows a level may use
const MAX_LAYERS := 3
const PITCH := Vector3(2.0 * 0.8 / 11.0, 0.085, 0.30)   # z: the walls stand apart, a ball fits between
const BRICK_SIZE := Vector3(0.135, 0.075, 0.12)
const BRICK_TOP := 0.5                # top edge of row 0
const Z_FRONT := -2.2                 # front face of layer 0
const LEVEL_COUNT := 20
const LEVEL_PATH := "res://levels/level_%02d.txt"
const COLOUR_CYCLE := "RYGB"          # layer n shows the level's colours shifted n steps
const COLOUR_POINTS := {"R": 120, "Y": 100, "G": 80, "B": 60}
const ARMOURED_MULT := 1.5
const CHARGED_POINTS := 200
const PLASMA_POINTS := 150
const RACK_BONUS := 1000
const EXTRA_LIFE_AT := [20000, 50000]
# --- energy blast (Tilt Breaker's charged shot) ---------------------------------------
## Holding the trigger charges level by level (BLAST_CHARGE_TIME each, as far as
## the power bar allows); releasing fires the level reached; the top level
## fires by itself. A level-n bolt goes through n bricks.
const BLAST_CHARGE_TIME := 0.68
const BLAST_MAX_LEVEL := 3
const BLAST_COST := 1.0 / 3.0         # per level; a full power bar = 3 levels
const BLAST_SPEED := 7.5
const BLAST_R := 0.04
const BLAST_SCALE := [0.75, 1.0, 1.3] # hitbox by level
const POWER_RECHARGE_DELAY := 1.0
const POWER_RECHARGE_RATE := 1.0 / 15.0
const BRICK_HIT_POWER := 0.02
const PADDLE_HIT_POWER := 0.05
const LOW_POWER_HOLD := 0.5           # only warn if the trigger is held this long on an empty bar
# --- power-ups: two slots, as in Tilt Breaker ------------------------------------------
## Blaster upgrades (atom capsules) replace the plasma cannon: they charge to
## level 1 only and each shot uses UPGRADE_COST of the bar. Paddle upgrades
## (pill capsules) change the paddle and use no energy. One of each can be held;
## both end with the level or a lost life.
const BLASTER_KINDS := ["T", "P", "B", "I", "W", "H"]
const PADDLE_KINDS := ["S", "L", "K"]
const INSTANT_KINDS := ["U", "N"]     # 1UP, nuclear: used on the catch
const UPGRADE_COST := {"T": 1.0 / 3.0, "P": 1.0 / 3.0, "B": 1.0, "I": 1.0, "W": 1.0, "H": 1.0}
const POWERUP_EVERY := 8              # every 8th brick destroyed...
const POWERUP_CHANCE := 0.7           # ...has a 70% chance to drop one
const DROP_PITY := 15                 # 15 bricks with no drop: the next drops one
const INSTANT_CHANCE := 0.04
const POWERUP_SPEED := 0.9            # m/s towards the player
const POWERUP_R := 0.06
const TRIPLE_ANGLE := deg_to_rad(20.0)  # T: side bolts
const ION_R := 0.1                    # I: the beam's reach around its line
## W: a wave shot that snakes to the far wall, hitting each brick in its way once.
const WAVE_SPEED := 3.5
const WAVE_AMP := 0.32
const WAVE_RATE := 6.0
const WAVE_SIZE := Vector3(0.2, 0.14, 0.12)
## H: a homing missile at the nearest brick; its blast hits a 3x3-brick patch
## of that wall three times.
const MISSILE_SPEED := 4.0
const MISSILE_TURN := 7.0             # rad/s
const MISSILE_R := 0.04
const MISSILE_HITS := 3
## L: afterimages trail the paddle by these delays (only while it moves this
## far in that time) and bounce the plasma too.
const GHOST_DELAYS := [0.09, 0.18]
const GHOST_MIN_GAP := 0.1

enum State { SERVE, PLAY, LEVEL_CLEAR, OVER }

var state := State.SERVE
var score := 0
var balls_left := 3
var level := 1
var layers := 2
var extra_lives_given := 0
var power := 1.0
var powerup := ""          # the blaster slot
var padup := ""            # the paddle slot
var shield_active := false
var serve_lock := 0.0
var remaining := 0         # breakable bricks still standing
var blast_charge := 0.0    # levels, fractional while charging
var charge_hand := -1      # the paddle whose trigger is held (-1 none)
var serve_hand := 0        # the paddle that holds the ball before a serve

# Options (set before start_game).
var paddle_count := 1
var start_lives := 3
var speed := "normal"

## The paddles: centre and facing of each energy field (its -z looks at the wall).
var paddles: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3)),
	Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3))]
var paddle_vels: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _prevs: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3)),
	Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3))]
var _hist: Array = [[], []]   # per paddle: [time, Transform3D], newest last
var _ghosts: Array[Transform3D] = []

## Balls in flight: {id, pos, vel, speed}.
var balls: Array = []
## Each brick: {aabb, hp, alive, row, col, layer, colour, points, metal, armoured, charged, plasma}.
var bricks: Array = []
var blasts: Array = []     # {id, pos, vel, level, hits_left}
var waves: Array = []      # {id, x0, pos, t, hit: {brick index: true}}
var missiles: Array = []   # {id, pos, vel, target: brick index or -1}
var capsules: Array = []   # {id, pos, kind}
## Events of the last step(): [name, data].
##   serve pos | paddle [pos, Vector2 offset -1..1, paddle index] | ghost pos
##   wall [side, pos] (side l r t b k) | brick [index, pos] | armour [index, pos]
##   metal [index, pos] | ball_free pos | rack_clear level | lost pos | over
##   charge_start level | charged level | blast_fail
##   blast [id, pos, level] | blast_end [id, pos, brick index or -1, level]
##   ion_beam [from, to] | wave_fire pos | missile_fire pos | missile_blast pos
##   bounce_ball pos | pu_drop [id, pos, kind] | pu_get [kind, pos] | pu_lost id
##   pu_end kind | shield_save pos | extra_life | nuke
var events: Array = []

var _grid := PackedInt32Array()
var _next_id := 1
var _broken := 0
var _since_drop := 0
var _since_blast := 99.0
var _nuking := false
var _ball_speed := BALL_START_SPEED
var _ball_max := BALL_MAX_SPEED
var _time := 0.0
var _last_drop_group := "" if randf() < 0.5 else "blaster"
var _await_release := false
var _charging := false
var _hold_t := 0.0
var _fail_reported := false
var _lost_pos := Vector3.ZERO


func _init() -> void:
	start_game()


func start_game(first_level: int = 1) -> void:
	score = 0
	balls_left = start_lives
	extra_lives_given = 0
	_broken = 0
	_since_drop = 0
	level = first_level
	_begin_level()


func next_level() -> void:
	level += 1
	_begin_level()


func _begin_level() -> void:
	layers = 2 if level <= 2 else MAX_LAYERS
	var path := LEVEL_PATH % (((level - 1) % LEVEL_COUNT) + 1)
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "RRRRRRRRRRR\nYYYYYYYYYYY"
	load_level_text(text, layers)
	_clear_field()
	_end_powerups()
	power = 1.0   # the bar is full at the start of every level
	serve_lock = 0.0
	charge_hand = -1
	var m: Array = SPEEDS.get(speed, SPEEDS["normal"])
	_ball_max = BALL_MAX_SPEED * float(m[1])
	_ball_speed = minf(BALL_START_SPEED * float(m[0]) + LEVEL_SPEED * (level - 1), _ball_max - 1.0)
	state = State.SERVE


func _clear_field() -> void:
	balls.clear()
	blasts.clear()
	waves.clear()
	missiles.clear()
	capsules.clear()
	blast_charge = 0.0


## One line per brick row (top first), one letter per column. R Y G B = colour,
## lowercase = armoured (2 hits), X = indestructible metal, C = charged (2 hits),
## P = holds a captured plasma ball, . = empty; # starts a comment line.
func load_level_text(text: String, layer_count: int) -> void:
	layers = clampi(layer_count, 1, MAX_LAYERS)
	bricks.clear()
	_grid.resize(COLS * ROWS * MAX_LAYERS)
	_grid.fill(-1)
	remaining = 0
	var row := 0
	for line in text.split("\n"):
		line = line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if row >= ROWS:
			break
		for col in mini(line.length(), COLS):
			var raw := line[col]
			if raw == "." or raw == " ":
				continue
			for layer in layers:
				_add_brick(raw, row, col, layer)
		row += 1


func _add_brick(raw: String, row: int, col: int, layer: int) -> void:
	var centre := Vector3(-HALF.x + (col + 0.5) * PITCH.x, BRICK_TOP - (row + 0.5) * PITCH.y,
		Z_FRONT - (layer + 0.5) * PITCH.z)
	var b := {"aabb": AABB(centre - BRICK_SIZE * 0.5, BRICK_SIZE), "hp": 1, "alive": true,
		"row": row, "col": col, "layer": layer, "colour": "B", "points": 0,
		"metal": false, "armoured": false, "charged": false, "plasma": false}
	if raw == "X":
		b.metal = true
	elif raw == "C":
		b.charged = true
		b.hp = 2
		b.colour = "R"
		b.points = CHARGED_POINTS
	elif raw == "P":
		b.plasma = true
		b.points = PLASMA_POINTS
	else:
		var upper := raw.to_upper()
		var at := COLOUR_CYCLE.find(upper)
		if at < 0:
			return
		b.colour = COLOUR_CYCLE[(at + layer) % 4]
		b.armoured = raw != upper
		b.hp = 2 if b.armoured else 1
		b.points = int(COLOUR_POINTS[b.colour] * (ARMOURED_MULT if b.armoured else 1.0))
	if not b.metal:
		remaining += 1
	_grid[(layer * ROWS + row) * COLS + col] = bricks.size()
	bricks.append(b)


# --- paddles -----------------------------------------------------------------------
func paddle_half() -> Vector2:
	return PADDLE_HALF + (Vector2(SIDEKICK_W, 0.0) if padup == "K" else Vector2.ZERO)


## Call once per frame for each paddle, before step(): where the hand holds it.
## It is kept inside the corridor and facing (within PADDLE_MAX_TILT) the wall.
func set_paddle(i: int, xf: Transform3D) -> void:
	var basis := xf.basis.orthonormalized()
	var fwd := -basis.z
	var ang := fwd.angle_to(Vector3.FORWARD)
	if ang > PADDLE_MAX_TILT:
		var axis := fwd.cross(Vector3.FORWARD)
		if axis.length_squared() < 1e-8:
			axis = Vector3.UP
		basis = Basis(axis.normalized(), ang - PADDLE_MAX_TILT) * basis
	var p := xf.origin
	p.x = clampf(p.x, -HALF.x, HALF.x)
	p.y = clampf(p.y, -HALF.y, HALF.y)
	p.z = clampf(p.z, PADDLE_Z.x, PADDLE_Z.y)
	paddles[i] = Transform3D(basis, p)


func paddle_normal(i: int = 0) -> Vector3:
	return -paddles[i].basis.z


func serve_pos() -> Vector3:
	return paddles[mini(serve_hand, paddle_count - 1)] * Vector3(0, 0, -SERVE_DIST)


## The Lightspeed afterimages, as of the last step().
func ghosts() -> Array[Transform3D]:
	return _ghosts


func _update_ghosts() -> void:
	_ghosts.clear()
	for i in paddle_count:
		var h: Array = _hist[i]
		h.append([_time, paddles[i]])
		while h.size() > 2 and float(h[1][0]) < _time - 0.3:
			h.pop_front()
		if padup != "L":
			continue
		for d in GHOST_DELAYS:
			var want: float = _time - float(d)
			var best: Transform3D = h[0][1]
			for e in h:
				if float(e[0]) <= want:
					best = e[1]
			if best.origin.distance_to(paddles[i].origin) >= GHOST_MIN_GAP:
				_ghosts.append(best)


# --- the trigger ---------------------------------------------------------------------
## Trigger down on paddle `i`: launches the ball when serving; in play, starts
## charging the blaster (release() fires it).
func press(i: int) -> void:
	i = clampi(i, 0, paddle_count - 1)
	if state == State.SERVE:
		serve_hand = i
		launch()
		charge_hand = i
		_await_release = true   # this pull was the launch, not a charge
	elif state == State.PLAY and charge_hand < 0:
		charge_hand = i


func release(i: int) -> void:
	i = clampi(i, 0, paddle_count - 1)
	if charge_hand != i:
		return
	var lvl := int(floor(blast_charge + 0.0001))
	if state == State.PLAY and lvl >= 1 and not _await_release:
		_fire(lvl)
	blast_charge = 0.0
	charge_hand = -1
	_await_release = false
	_charging = false
	_hold_t = 0.0
	_fail_reported = false


func launch() -> void:
	if state != State.SERVE or serve_lock > 0.0:
		return
	var pos := serve_pos()
	balls.append({"id": _id(), "pos": pos, "vel": _min_z(paddle_normal(serve_hand), _ball_speed, -1.0), "speed": _ball_speed})
	state = State.PLAY
	events.append(["serve", pos])


## Highest charge level the power bar allows now (an upgrade: 1 if its cost is there).
func affordable_level() -> int:
	if UPGRADE_COST.has(powerup):
		return 1 if power >= float(UPGRADE_COST[powerup]) - 0.0001 else 0
	return clampi(int(floor(power / BLAST_COST + 0.0001)), 0, BLAST_MAX_LEVEL)


func max_level() -> int:
	return 1 if UPGRADE_COST.has(powerup) else BLAST_MAX_LEVEL


func _step_charge(dt: float) -> void:
	var holding := charge_hand >= 0
	var can := state == State.PLAY
	if not holding:
		_await_release = false
		_hold_t = 0.0
		_fail_reported = false
	else:
		_hold_t += dt
	if holding and can and not _await_release:
		var cap := affordable_level()
		if cap == 0:
			if _hold_t >= LOW_POWER_HOLD and not _fail_reported:
				_fail_reported = true
				events.append(["blast_fail", null])
		elif not _charging:
			events.append(["charge_start", 1])
		_charging = cap > 0
		var before := blast_charge
		blast_charge = minf(blast_charge + dt / BLAST_CHARGE_TIME, float(cap))
		var reached := int(floor(blast_charge + 0.0001))
		if reached > int(floor(before + 0.0001)):
			events.append(["charged", reached])
			if reached >= max_level():
				_fire(reached)   # the top level fires by itself
				blast_charge = 0.0
				_await_release = true
				_charging = false
			elif reached < cap:
				events.append(["charge_start", reached + 1])
	else:
		_charging = false
	if not can:
		blast_charge = 0.0


## Fires the charged shot at level `lvl`, shaped by the blaster upgrade.
func _fire(lvl: int) -> void:
	_since_blast = 0.0
	var hand := clampi(charge_hand, 0, paddle_count - 1)
	var xf := paddles[hand]
	var n := -xf.basis.z
	var start := xf * Vector3(0, 0, -0.1)
	if UPGRADE_COST.has(powerup):
		power = maxf(0.0, power - float(UPGRADE_COST[powerup]))
	match powerup:
		"I":   # Ion cannon: an instant beam that fries the bricks along its line
			_ion_beam(start, n)
		"W":
			waves.append({"id": _id(), "x0": start.x, "pos": start, "t": 0.0, "hit": {}})
			events.append(["wave_fire", start])
		"H":
			missiles.append({"id": _id(), "pos": start, "vel": n * MISSILE_SPEED, "target": _missile_target(start)})
			events.append(["missile_fire", start])
		"P":   # Power laser: a level-3 bolt for one cell
			_add_blast(start, n, 3)
		"B":   # Bounce plasma: an extra plasma ball
			if balls.size() < MAX_BALLS:
				var dir := n.rotated(xf.basis.y, deg_to_rad(randf_range(-12.0, 12.0)))
				balls.append({"id": _id(), "pos": xf * Vector3(0, 0, -SERVE_DIST),
					"vel": _min_z(dir, _ball_speed, -1.0), "speed": _ball_speed})
			events.append(["bounce_ball", start])
		_:
			if not UPGRADE_COST.has(powerup):
				power = maxf(0.0, power - BLAST_COST * lvl)
			_add_blast(start, n, lvl)
			if powerup == "T":   # Triple laser: two more bolts, fanned out
				_add_blast(start, n.rotated(xf.basis.y, TRIPLE_ANGLE), lvl)
				_add_blast(start, n.rotated(xf.basis.y, -TRIPLE_ANGLE), lvl)


func _add_blast(pos: Vector3, dir: Vector3, lvl: int) -> void:
	var b := {"id": _id(), "pos": pos, "vel": dir.normalized() * BLAST_SPEED, "level": lvl, "hits_left": lvl}
	blasts.append(b)
	events.append(["blast", [b.id, pos, lvl]])


func _ion_beam(from: Vector3, dir: Vector3) -> void:
	var to := from + dir * ((Z_BACK - from.z) / minf(dir.z, -0.1))
	events.append(["ion_beam", [from, to]])
	for j in bricks.size():
		var b: Dictionary = bricks[j]
		if b.alive and not b.metal and (b.aabb as AABB).grow(ION_R).intersects_segment(from, to) != null:
			b.hp = 1
			_damage(j, (b.aabb as AABB).get_center())
			if state == State.LEVEL_CLEAR:
				return


func step(delta: float) -> void:
	events.clear()
	_time += delta
	for i in paddle_count:
		paddle_vels[i] = (paddles[i].origin - _prevs[i].origin) / maxf(delta, 1e-4)
	_update_ghosts()
	_since_blast += delta
	if _since_blast >= POWER_RECHARGE_DELAY:
		power = minf(1.0, power + POWER_RECHARGE_RATE * delta)
	serve_lock = maxf(0.0, serve_lock - delta)
	_step_charge(delta)
	if state == State.PLAY:
		_step_balls(delta)
	if state == State.PLAY or state == State.SERVE:
		_step_blasts(delta)
	if state == State.PLAY or state == State.SERVE:
		_step_shots(delta)
	if state == State.PLAY or state == State.SERVE:
		_step_capsules(delta)
	if state == State.PLAY and balls.is_empty():
		_lose_ball()
	for i in paddle_count:
		_prevs[i] = paddles[i]


# --- balls -------------------------------------------------------------------------
func _step_balls(delta: float) -> void:
	var lost_at := Vector3.ZERO
	var i := 0
	while i < balls.size():
		var b: Dictionary = balls[i]
		var n := maxi(1, ceili(b.speed * delta / MAX_SUBSTEP))
		var dt := delta / n
		var gone := false
		for k in n:
			if _substep(b, dt, float(k) / n, float(k + 1) / n):
				gone = true
				break
			if state != State.PLAY:
				return   # the level was cleared mid-step
		if gone:
			lost_at = b.pos
			balls.remove_at(i)
		else:
			i += 1
	if balls.is_empty():
		_lost_pos = lost_at


## Moves one ball one substep (f0..f1 of the frame). Returns true once it is lost.
func _substep(b: Dictionary, dt: float, f0: float, f1: float) -> bool:
	var p0: Vector3 = b.pos
	var pos: Vector3 = p0 + b.vel * dt
	var vel: Vector3 = b.vel
	var bounced := false
	# Corridor walls.
	if pos.x < -HALF.x + BALL_R and vel.x < 0.0:
		pos.x = -HALF.x + BALL_R
		vel.x = -vel.x
		events.append(["wall", ["l", pos]])
		bounced = true
	elif pos.x > HALF.x - BALL_R and vel.x > 0.0:
		pos.x = HALF.x - BALL_R
		vel.x = -vel.x
		events.append(["wall", ["r", pos]])
		bounced = true
	if pos.y < -HALF.y + BALL_R and vel.y < 0.0:
		pos.y = -HALF.y + BALL_R
		vel.y = -vel.y
		events.append(["wall", ["b", pos]])
		bounced = true
	elif pos.y > HALF.y - BALL_R and vel.y > 0.0:
		pos.y = HALF.y - BALL_R
		vel.y = -vel.y
		events.append(["wall", ["t", pos]])
		bounced = true
	if pos.z < Z_BACK + BALL_R and vel.z < 0.0:
		pos.z = Z_BACK + BALL_R
		vel.z = -vel.z
		events.append(["wall", ["k", pos]])
		bounced = true
	b.pos = pos
	b.vel = vel
	# Bricks.
	var hit := _brick_hit(pos, BALL_R)
	if not hit.is_empty():
		b.pos = pos + hit.normal * hit.depth
		var into: float = b.vel.dot(hit.normal)
		if into < 0.0:
			b.vel = b.vel - 2.0 * into * hit.normal
		bounced = true
		_damage(hit.index, b.pos)
	if bounced:
		b.vel = _min_z(b.vel, b.speed, 0.0)
	# The paddles, then the Lightspeed afterimages.
	var saved := false
	for i in paddle_count:
		var t0 := Transform3D(paddles[i].basis, _prevs[i].origin.lerp(paddles[i].origin, f0))
		var t1 := Transform3D(paddles[i].basis, _prevs[i].origin.lerp(paddles[i].origin, f1))
		if _paddle_hit(b, p0, t0, t1, paddle_vels[i], i):
			saved = true
			break
	if not saved:
		for g in _ghosts:
			if _paddle_hit(b, p0, g, g, Vector3.ZERO, -1):
				break
	# The Shield barrier, then the drain.
	if shield_active and b.pos.z > Z_SHIELD - BALL_R and b.vel.z > 0.0:
		b.pos.z = Z_SHIELD - BALL_R
		b.vel.z = -b.vel.z
		shield_active = false
		if padup == "S":
			padup = ""
			events.append(["pu_end", "S"])
		events.append(["shield_save", b.pos])
	return b.pos.z > Z_DRAIN


## The ball meets a field when it crosses the field's front face from the
## front, measured in the paddle's own (moving) frame, so a fast hand can't
## sweep through it. A ball already behind the field is not saved.
## `index` -1 = an afterimage.
func _paddle_hit(b: Dictionary, p0: Vector3, t0: Transform3D, t1: Transform3D, pvel: Vector3, index: int) -> bool:
	var q0 := t0.inverse() * p0
	var q1 := t1.inverse() * (b.pos as Vector3)
	var d0 := -q0.z
	var d1 := -q1.z
	if d0 < 0.0 or d1 >= BALL_R:
		return false
	var k := clampf((d0 - BALL_R) / maxf(d0 - d1, 1e-6), 0.0, 1.0)
	var qc := q0.lerp(q1, k)
	var h := paddle_half()
	if absf(qc.x) > h.x + BALL_R * 0.7 or absf(qc.y) > h.y + BALL_R * 0.7:
		return false
	var n := -t1.basis.z
	var rel: Vector3 = b.vel - pvel
	var into := rel.dot(n)
	if into >= 0.0:
		return false
	var off := Vector2(clampf(qc.x / h.x, -1.0, 1.0), clampf(qc.y / h.y, -1.0, 1.0))
	var mirror := (rel - 2.0 * into * n).normalized()
	var side := pvel - pvel.dot(n) * n
	# The steering is that of the plain field, however wide the sidekicks make it.
	var dir := n + mirror * MIRROR_KEEP \
		+ (t1.basis.x * (qc.x / PADDLE_HALF.x) + t1.basis.y * off.y) * OFFSET_STEER + side * ENGLISH
	b.speed = minf(b.speed + SPEEDUP_PER_PADDLE_HIT, maxf(_ball_max, b.speed))
	b.vel = _min_z(dir, b.speed, -1.0)
	b.pos = t1 * Vector3(qc.x, qc.y, -(BALL_R + 0.004))
	power = minf(1.0, power + PADDLE_HIT_POWER)
	if index >= 0:
		events.append(["paddle", [b.pos, off, index]])
	else:
		events.append(["ghost", b.pos])
	return true


## `vel` at `speed`, never flatter than MIN_Z_RATIO along the corridor.
## force_sign -1 = must head for the wall; 0 = keep its own direction.
static func _min_z(vel: Vector3, speed: float, force_sign: float) -> Vector3:
	if vel.length_squared() < 1e-10:
		return Vector3(0, 0, -speed)
	var v := vel.normalized()
	var sz := force_sign if force_sign != 0.0 else (-1.0 if v.z <= 0.0 else 1.0)
	if v.z * sz < MIN_Z_RATIO:
		var lat := Vector2(v.x, v.y)
		lat = lat.normalized() * sqrt(1.0 - MIN_Z_RATIO * MIN_Z_RATIO) if lat.length_squared() > 1e-10 else Vector2.ZERO
		v = Vector3(lat.x, lat.y, sz * MIN_Z_RATIO).normalized()
	return v * speed


# --- bricks ------------------------------------------------------------------------
## The brick a sphere at `pos` sinks deepest into: {index, normal, depth}, or {}.
func _brick_hit(pos: Vector3, r: float) -> Dictionary:
	var l0 := maxi(0, floori((Z_FRONT - (pos.z + r)) / PITCH.z))
	var l1 := mini(layers - 1, floori((Z_FRONT - (pos.z - r)) / PITCH.z))
	if l0 > l1:
		return {}
	var r0 := maxi(0, floori((BRICK_TOP - (pos.y + r)) / PITCH.y))
	var r1 := mini(ROWS - 1, floori((BRICK_TOP - (pos.y - r)) / PITCH.y))
	var c0 := maxi(0, floori((pos.x - r + HALF.x) / PITCH.x))
	var c1 := mini(COLS - 1, floori((pos.x + r + HALF.x) / PITCH.x))
	var best := {}
	for layer in range(l0, l1 + 1):
		for row in range(r0, r1 + 1):
			for col in range(c0, c1 + 1):
				var idx := _grid[(layer * ROWS + row) * COLS + col]
				if idx < 0 or not bricks[idx].alive:
					continue
				var hit := sphere_aabb(pos, r, bricks[idx].aabb)
				if not hit.is_empty() and (best.is_empty() or hit.depth > best.depth):
					hit["index"] = idx
					best = hit
	return best


## Sphere against an axis-aligned box: {} if apart, else {normal (box to
## sphere), depth}.
static func sphere_aabb(pos: Vector3, r: float, box: AABB) -> Dictionary:
	var lo := box.position
	var hi := box.end
	var closest := pos.clamp(lo, hi)
	var d := pos - closest
	var dist2 := d.length_squared()
	if dist2 > r * r:
		return {}
	if dist2 > 1e-12:
		var dist := sqrt(dist2)
		return {"normal": d / dist, "depth": r - dist}
	# Centre inside the box: out through the nearest face.
	var best := INF
	var normal := Vector3.BACK
	for axis in 3:
		if pos[axis] - lo[axis] < best:
			best = pos[axis] - lo[axis]
			normal = Vector3.ZERO
			normal[axis] = -1.0
		if hi[axis] - pos[axis] < best:
			best = hi[axis] - pos[axis]
			normal = Vector3.ZERO
			normal[axis] = 1.0
	return {"normal": normal, "depth": best + r}


func _damage(idx: int, at: Vector3) -> void:
	var b: Dictionary = bricks[idx]
	if not b.alive:
		return
	if b.metal:
		events.append(["metal", [idx, at]])
		return
	b.hp -= 1
	if b.hp > 0:
		events.append(["armour", [idx, at]])
		return
	b.alive = false
	remaining -= 1
	var centre: Vector3 = (b.aabb as AABB).get_center()
	events.append(["brick", [idx, centre]])
	_add_score(b.points)
	if not _nuking:
		power = minf(1.0, power + BRICK_HIT_POWER)
		if b.plasma and balls.size() < MAX_BALLS:
			# Its captured ball goes free, towards the player.
			var dir := Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.4), 1.0)
			balls.append({"id": _id(), "pos": centre, "vel": _min_z(dir, _ball_speed, 1.0), "speed": _ball_speed})
			events.append(["ball_free", centre])
		_maybe_drop(centre)
	if remaining <= 0 and state == State.PLAY:
		_add_score(RACK_BONUS)
		state = State.LEVEL_CLEAR
		_clear_field()
		events.append(["rack_clear", level])


func _add_score(points: int) -> void:
	score += points
	while extra_lives_given < EXTRA_LIFE_AT.size() and score >= EXTRA_LIFE_AT[extra_lives_given]:
		extra_lives_given += 1
		balls_left += 1
		events.append(["extra_life", null])


func _lose_ball() -> void:
	balls_left -= 1
	_clear_field()
	_end_powerups()
	events.append(["lost", _lost_pos])
	if balls_left <= 0:
		state = State.OVER
		events.append(["over", null])
	else:
		state = State.SERVE
		serve_lock = SERVE_LOCK


# --- energy blasts ------------------------------------------------------------------
func _step_blasts(delta: float) -> void:
	var i := 0
	while i < blasts.size():
		var s: Dictionary = blasts[i]
		var r: float = BLAST_R * float(BLAST_SCALE[clampi(int(s.level), 1, 3) - 1])
		var n := maxi(1, ceili(BLAST_SPEED * delta / (MAX_SUBSTEP * 2.0)))
		var done := false
		for k in n:
			s.pos += s.vel * (delta / n)
			var p: Vector3 = s.pos
			var hit := _brick_hit(p, r)
			if not hit.is_empty():
				# Each brick touched uses one hit; the bolt goes on until spent.
				s.hits_left -= 1
				_damage(hit.index, p)
				if state == State.LEVEL_CLEAR:
					return   # the lists were cleared with the level
				if s.hits_left <= 0:
					events.append(["blast_end", [s.id, p, hit.index, s.level]])
					done = true
			elif absf(p.x) > HALF.x or absf(p.y) > HALF.y or p.z < Z_BACK or p.z > Z_DRAIN:
				events.append(["blast_end", [s.id, p, -1, s.level]])
				done = true
			if done:
				break
		if done:
			blasts.remove_at(i)
		else:
			i += 1


# --- wave beam and homing missiles ---------------------------------------------------
func _step_shots(delta: float) -> void:
	var i := 0
	while i < waves.size():
		var w: Dictionary = waves[i]
		var n := maxi(1, ceili(WAVE_SPEED * delta / (MAX_SUBSTEP * 2.0)))
		for k in n:
			w.t = float(w.t) + delta / n
			var p: Vector3 = w.pos
			p.z -= WAVE_SPEED * delta / n
			p.x = clampf(float(w.x0) + sin(float(w.t) * WAVE_RATE) * WAVE_AMP, -HALF.x + 0.1, HALF.x - 0.1)
			w.pos = p
			var box := AABB(p - WAVE_SIZE * 0.5, WAVE_SIZE)
			for j in bricks.size():
				if bricks[j].alive and not w.hit.has(j) and box.intersects(bricks[j].aabb):
					w.hit[j] = true
					_damage(j, p)
					if state == State.LEVEL_CLEAR:
						return
		if w.pos.z < Z_BACK:
			waves.remove_at(i)
		else:
			i += 1
	i = 0
	while i < missiles.size():
		var m: Dictionary = missiles[i]
		if int(m.target) < 0 or not bricks[int(m.target)].alive:
			m.target = _missile_target(m.pos)
		var vel: Vector3 = m.vel
		var has_target := int(m.target) >= 0
		var tp := Vector3.ZERO
		if has_target:
			tp = (bricks[int(m.target)].aabb as AABB).get_center()
			var want: Vector3 = (tp - (m.pos as Vector3)).normalized()
			var cur := vel.normalized()
			var ang := cur.angle_to(want)
			if ang > 1e-4:
				cur = cur.slerp(want, minf(1.0, MISSILE_TURN * delta / ang))
			vel = cur * MISSILE_SPEED
		m.vel = vel
		var p: Vector3 = m.pos + vel * delta
		m.pos = p
		var boom := absf(p.x) > HALF.x or absf(p.y) > HALF.y or p.z < Z_BACK or p.z > Z_DRAIN \
			or (has_target and p.distance_to(tp) < 0.07) or not _brick_hit(p, MISSILE_R).is_empty()
		if boom:
			missiles.remove_at(i)
			_missile_blast(p)
			if state == State.LEVEL_CLEAR:
				return
		else:
			i += 1


## The nearest breakable brick to `from` (-1: none).
func _missile_target(from: Vector3) -> int:
	var best := -1
	var best_d := INF
	for j in bricks.size():
		var b: Dictionary = bricks[j]
		if b.alive and not b.metal:
			var d := from.distance_squared_to((b.aabb as AABB).get_center())
			if d < best_d:
				best_d = d
				best = j
	return best


## The missile's blast: a 3x3-brick patch of the wall it hit takes MISSILE_HITS hits.
func _missile_blast(p: Vector3) -> void:
	events.append(["missile_blast", p])
	var size := Vector3(3.0 * PITCH.x, 3.0 * PITCH.y, PITCH.z) * 0.98
	var area := AABB(p - size * 0.5, size)
	for j in bricks.size():
		if bricks[j].alive and area.has_point((bricks[j].aabb as AABB).get_center()):
			for h in MISSILE_HITS:
				_damage(j, p)
			if state == State.LEVEL_CLEAR:
				return


# --- power-ups ----------------------------------------------------------------------
func _maybe_drop(at: Vector3) -> void:
	_broken += 1
	_since_drop += 1
	var drop := _since_drop > DROP_PITY
	if not drop and _broken % POWERUP_EVERY == 0:
		drop = randf() < POWERUP_CHANCE
	if drop:
		_since_drop = 0
		spawn_capsule(at, random_kind())


## Instant ones are rare; otherwise the two kinds of upgrade take turns.
func random_kind() -> String:
	if randf() < INSTANT_CHANCE:
		return INSTANT_KINDS[randi() % INSTANT_KINDS.size()]
	_last_drop_group = "paddle" if _last_drop_group == "blaster" else "blaster"
	var pool: Array = (PADDLE_KINDS if _last_drop_group == "paddle" else BLASTER_KINDS).filter(
		func(k: String) -> bool: return k != powerup and k != padup)
	return pool[randi() % pool.size()]


func spawn_capsule(at: Vector3, kind: String) -> void:
	var c := {"id": _id(), "pos": at, "kind": kind}
	capsules.append(c)
	events.append(["pu_drop", [c.id, at, kind]])


func _step_capsules(delta: float) -> void:
	var h := paddle_half()
	var i := 0
	while i < capsules.size():
		var c: Dictionary = capsules[i]
		c.pos.z += POWERUP_SPEED * delta
		var caught := false
		for k in paddle_count:
			var q := paddles[k].inverse() * (c.pos as Vector3)
			var reach := 0.1 + absf(paddle_vels[k].z) * delta
			if absf(q.z) < reach and absf(q.x) < h.x + POWERUP_R and absf(q.y) < h.y + POWERUP_R:
				caught = true
				break
		if caught:
			capsules.remove_at(i)
			events.append(["pu_get", [c.kind, c.pos]])
			if c.kind in INSTANT_KINDS:
				_use_instant(c.kind)
			else:
				apply_powerup(c.kind)
			if state == State.LEVEL_CLEAR:
				return
			continue
		if c.pos.z > Z_DRAIN + 0.2:
			capsules.remove_at(i)
			events.append(["pu_lost", c.id])
			continue
		i += 1


## A blaster upgrade replaces the blaster slot's, a paddle upgrade the paddle
## slot's; the other slot is kept.
func apply_powerup(kind: String) -> void:
	if kind in PADDLE_KINDS:
		_end_padup()
		padup = kind
		shield_active = kind == "S"
	else:
		_end_blaster()
		powerup = kind
		blast_charge = 0.0


func _use_instant(kind: String) -> void:
	if kind == "U":
		balls_left += 1
		events.append(["extra_life", null])
	elif kind == "N":
		events.append(["nuke", null])
		_nuking = true
		for i in bricks.size():
			if bricks[i].alive and not bricks[i].metal:
				bricks[i].hp = 1
				_damage(i, (bricks[i].aabb as AABB).get_center())
		_nuking = false


func _end_powerups() -> void:
	_end_blaster()
	_end_padup()


func _end_blaster() -> void:
	if powerup != "":
		events.append(["pu_end", powerup])
		powerup = ""


func _end_padup() -> void:
	if padup != "":
		events.append(["pu_end", padup])
		padup = ""
	shield_active = false


func _id() -> int:
	_next_id += 1
	return _next_id - 1
