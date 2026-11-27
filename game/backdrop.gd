## Life outside the corridor: every now and then one of Tilt Breaker's enemies
## (tetrahedron, cube, and more rarely the icosahedron or dodecahedron bosses)
## comes out of a wormhole, flies past outside the energy walls and leaves
## through another wormhole. Pure scenery: nothing here touches the game.
## Add it as a child of the arena, so it scales with the room.
extends Node3D

const Bodies = preload("res://game/enemy_bodies.gd")
const WORMHOLE_SHADER = preload("res://shaders/wormhole.gdshader")
const HAL_SHADER = preload("res://shaders/hal_eye.gdshader")
const TEX := "res://assets/textures/breakout/circuit_%s.png"
const COLOURS := ["red", "yellow", "green", "blue"]
const GLOW := {"red": Color("ff5a32"), "yellow": Color("ffd23e"), "green": Color("4dff6a"), "blue": Color("3ec7ff")}
const INTERVAL := Vector2(5.0, 12.0)   # s between visitors
const FIRST := 3.0
const MAX_AT_ONCE := 3
const WARP := 0.9                      # s to come out of / go into a wormhole
## The corridor (arena space) and how far visitors keep from it.
const HALF := Vector2(0.8, 0.6)
const CLEAR := 0.7

## Called with (sound name, position) for the wormhole whoosh.
var sound: Callable
var _timer := FIRST
var _visitors: Array = []   # {root, body, eye, from, to, mid, t, life, spin, hole_a, hole_b, r}


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(INTERVAL.x, INTERVAL.y)
		if _visitors.size() < MAX_AT_ONCE:
			_spawn()
	for i in range(_visitors.size() - 1, -1, -1):
		var v: Dictionary = _visitors[i]
		v.t += delta
		var life: float = v.life
		var k := clampf(float(v.t) / life, 0.0, 1.0)
		var root: Node3D = v.root
		# A gentle arc from one wormhole to the other, bobbing a little.
		var p: Vector3 = (v.from as Vector3).lerp(v.mid, k).lerp((v.mid as Vector3).lerp(v.to, k), k)
		root.position = p + Vector3(0, sin(float(v.t) * 1.7) * float(v.r) * 0.3, 0)
		(v.body as Node3D).rotate(v.spin.normalized(), (v.spin as Vector3).length() * delta)
		# It grows out of the first wormhole and shrinks into the second.
		var grow := clampf(float(v.t) / WARP, 0.0, 1.0) * clampf((life - float(v.t)) / WARP, 0.0, 1.0)
		(v.body as Node3D).scale = Vector3.ONE * maxf(grow, 0.01)
		if v.eye != null:
			(v.eye as Node3D).scale = Vector3.ONE * maxf(grow, 0.01)
			(v.eye as Node3D).look_at(to_global(Vector3(0, 0, 0.8)), Vector3.UP)   # it watches the player
		_hole(v.hole_a, 1.0 - clampf((float(v.t) - WARP) / 0.5, 0.0, 1.0), clampf(float(v.t) / 0.4, 0.0, 1.0))
		_hole(v.hole_b, clampf((float(v.t) - (life - WARP - 0.6)) / 0.5, 0.0, 1.0),
			1.0 - clampf((float(v.t) - life) / 0.4 + 1.0, 0.0, 1.0) if float(v.t) > life - 0.4 else 1.0)
		if not v.left and float(v.t) > life - WARP - 0.6:
			v.left = true
			if sound.is_valid():
				sound.call("tb_wormhole", v.to)
		if float(v.t) >= life:
			root.queue_free()
			(v.hole_a as Node).queue_free()
			(v.hole_b as Node).queue_free()
			_visitors.remove_at(i)


func _hole(hole: MeshInstance3D, a: float, b: float) -> void:
	hole.set_instance_shader_parameter("open", clampf(a * b, 0.0, 1.0))


func _spawn() -> void:
	var roll := randf()
	var kind := "tetra" if roll < 0.45 else ("cube" if roll < 0.82 else ("ico" if roll < 0.92 else "dodeca"))
	var big := kind == "ico" or kind == "dodeca"
	var pick: String = COLOURS[randi() % COLOURS.size()]
	var tex: Texture2D = load(TEX % pick)
	var r := randf_range(1.0, 1.8) if big else randf_range(0.14, 0.32)
	var body: Node3D
	var eye: MeshInstance3D = null
	match kind:
		"tetra":
			body = Bodies.make_tetrahedron(r, tex, GLOW[pick])
		"cube":
			body = Bodies.make_cube(r, tex, GLOW[pick])
		"ico":
			body = Bodies.make_icosahedron(r, load(TEX % "red"), Color(1.0, 0.25, 0.3), 0.45)
		_:
			body = Bodies.make_dodecahedron(r, load(TEX % "blue"), Color(0.75, 0.3, 1.0), 0.45)
	var root := Node3D.new()
	root.add_child(body)
	if big:   # the bosses' HAL eye
		eye = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r * 0.4
		sm.height = r * 0.8
		eye.mesh = sm
		var em := ShaderMaterial.new()
		em.shader = HAL_SHADER
		if kind == "dodeca":
			em.set_shader_parameter("iris", Color(0.15, 0.4, 1.0))
		eye.material_override = em
		root.add_child(eye)
	var path := _path(big, r)
	var from: Vector3 = path[0]
	var to: Vector3 = path[1]
	var mid := (from + to) * 0.5 + _away((from + to) * 0.5) * randf_range(0.2, 1.2) * (4.0 if big else 1.0)
	root.position = from
	add_child(root)
	var speed := randf_range(1.5, 2.5) if big else randf_range(0.7, 1.6)
	var v := {"root": root, "body": body, "eye": eye, "from": from, "to": to, "mid": mid, "t": 0.0,
		"life": maxf(from.distance_to(to) / speed, WARP * 2.0 + 1.5), "r": r, "left": false,
		"spin": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0.8, 2.2),
		"hole_a": _make_hole(from, r * 4.5), "hole_b": _make_hole(to, r * 4.5)}
	_visitors.append(v)
	if sound.is_valid():
		sound.call("tb_wormhole", from)


func _make_hole(at: Vector3, size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	m.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = WORMHOLE_SHADER
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	add_child(m)
	return m


## Sideways away from the corridor's centre line at `p`.
func _away(p: Vector3) -> Vector3:
	var d := Vector3(p.x, p.y, 0.0)
	return d.normalized() if d.length_squared() > 1e-6 else Vector3.UP


## Start and end points of a pass that stays outside the corridor: along one of
## its sides (or over or under it), or across behind the far wall. The bosses
## keep their distance.
func _path(big: bool, r: float) -> Array:
	var gap := CLEAR + r
	if big:
		# Far off, crossing the view behind and beside the corridor.
		var side := -1.0 if randf() < 0.5 else 1.0
		var y := randf_range(-2.0, 7.0)
		var from := Vector3(side * randf_range(14.0, 20.0), y, randf_range(-28.0, -16.0))
		var to := Vector3(-side * randf_range(10.0, 20.0), y + randf_range(-3.0, 3.0), randf_range(-26.0, -12.0))
		return [from, to]
	var z0 := randf_range(-9.0, -5.5)
	var z1 := randf_range(-0.5, 1.5)
	if randf() < 0.5:
		var t := z0
		z0 = z1
		z1 = t
	match randi() % 4:
		0, 1:   # along the left or right wall
			var side := -1.0 if randf() < 0.5 else 1.0
			return [Vector3(side * (HALF.x + gap + randf_range(0.0, 1.6)), randf_range(-0.9, 1.3), z0),
				Vector3(side * (HALF.x + gap + randf_range(0.0, 1.6)), randf_range(-0.9, 1.3), z1)]
		2:      # over or under the corridor
			var up := 1.0 if randf() < 0.65 else -1.0
			return [Vector3(randf_range(-1.6, 1.6), up * (HALF.y + gap + randf_range(0.0, 1.0)), z0),
				Vector3(randf_range(-1.6, 1.6), up * (HALF.y + gap + randf_range(0.0, 1.0)), z1)]
		_:      # across, behind the far wall
			var side := -1.0 if randf() < 0.5 else 1.0
			var z := randf_range(-8.5, -5.2)
			return [Vector3(side * randf_range(3.0, 5.0), randf_range(-1.2, 1.6), z),
				Vector3(-side * randf_range(3.0, 5.0), randf_range(-1.2, 1.6), z + randf_range(-1.0, 1.0))]
