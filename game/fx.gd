## 3D Blocks visual effects, taken from Tilt Breaker's fx.gd (PinGames): plasma
## ball + trail, the planet, power-up capsules. Pure presentation.
extends RefCounted

const PLASMA_SHADER = preload("res://shaders/plasma.gdshader")
const SOLID_SHADER = preload("res://shaders/solid.gdshader")
const TRAIL_SHADER = preload("res://shaders/trail.gdshader")
const PLANET_SHADER = preload("res://shaders/planet.gdshader")
const ATMOSPHERE_SHADER = preload("res://shaders/atmosphere.gdshader")
const FONT = preload("res://assets/fonts/pinpixel.ttf")
## Eye training groups (shaders/eye.gdshaderinc).
const EYE_NONE := 0
const EYE_BALL := 1
const EYE_WORLD := 2


## Plasma ball: hot core sphere + billboard halo. Returns the root Node3D.
static func make_plasma_ball(radius: float, eye_group: int = EYE_NONE) -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.8
	sphere.height = radius * 1.6
	sphere.radial_segments = 16
	sphere.rings = 8
	core.mesh = sphere
	var core_mat := ShaderMaterial.new()
	core_mat.shader = SOLID_SHADER
	core_mat.set_shader_parameter("eye_group", eye_group)
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 6.0, radius * 6.0)
	halo.mesh = quad
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = PLASMA_SHADER
	halo_mat.set_shader_parameter("eye_group", eye_group)
	halo.material_override = halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	return root


## Recolours a plasma ball made by make_plasma_ball.
static func tint_plasma(ball: Node3D, color: Color) -> void:
	var cm := (ball.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	cm.set_shader_parameter("color", color.lerp(Color.WHITE, 0.6))
	var hm := (ball.get_child(1) as MeshInstance3D).material_override as ShaderMaterial
	hm.set_shader_parameter("core_color", color.lerp(Color.WHITE, 0.7))
	hm.set_shader_parameter("halo_color", color)
	hm.set_shader_parameter("arc_color", color.lerp(Color.WHITE, 0.3))


## Ribbon trail behind a moving point, turned to face the viewer. Call
## update(pos, eye) every frame (both in the trail's parent space).
class Trail:
	extends MeshInstance3D

	var max_points := 22
	var width := 0.04
	var min_step := 0.02
	var head_color := Color(0.55, 0.75, 1.0, 0.9)
	var tail_color := Color(0.5, 0.25, 1.0, 0.0)
	var _points: Array[Vector3] = []
	var _imesh := ImmediateMesh.new()

	func _init(eye_group: int = 0) -> void:
		mesh = _imesh
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = TRAIL_SHADER
		m.set_shader_parameter("eye_group", eye_group)
		material_override = m

	func update(pos: Vector3, eye: Vector3) -> void:
		if _points.is_empty() or _points[0].distance_to(pos) >= min_step:
			_points.push_front(pos)
			if _points.size() > max_points:
				_points.pop_back()
		else:
			_points[0] = pos
		_imesh.clear_surfaces()
		var n := _points.size()
		if n < 2:
			return
		_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n:
			var p := _points[i]
			var dir := _points[maxi(i - 1, 0)] - _points[mini(i + 1, n - 1)]
			var perp := dir.cross(eye - p)
			perp = perp.normalized() if perp.length_squared() > 1e-10 else Vector3.UP
			var t := float(i) / float(n - 1)
			var w := width * (1.0 - t)
			var c := head_color.lerp(tail_color, t)
			_imesh.surface_set_color(c)
			_imesh.surface_add_vertex(p + perp * w)
			_imesh.surface_set_color(c)
			_imesh.surface_add_vertex(p - perp * w)
		_imesh.surface_end()


## The earth-like planet the corridor floats above: Tilt Breaker's surface and
## haze shaders on a big sphere.
class Planet:
	extends Node3D

	func _init(radius: float) -> void:
		var body := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 128
		sphere.rings = 64
		body.mesh = sphere
		var mat := ShaderMaterial.new()
		mat.shader = PLANET_SHADER
		mat.set_shader_parameter("detail_scale", 22.0 / radius)
		mat.set_shader_parameter("softness", 0.06)
		mat.set_shader_parameter("atmosphere_glow", 2.5)
		body.material_override = mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
		var haze := MeshInstance3D.new()
		var shell := SphereMesh.new()
		shell.radius = radius * 1.012
		shell.height = radius * 2.024
		shell.radial_segments = 128
		shell.rings = 64
		haze.mesh = shell
		var haze_mat := ShaderMaterial.new()
		haze_mat.shader = ATMOSPHERE_SHADER
		haze.material_override = haze_mat
		haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(haze)
		rotation = Vector3(0.4, 1.1, 0.2)   # a coastline under the corridor

	func _process(delta: float) -> void:
		rotate_object_local(Vector3.RIGHT, delta * 0.004)   # the orbit drifts by


## A falling power-up, as in Tilt Breaker: blaster upgrades are spheres with
## two orbiting electrons, paddle upgrades are spinning two-tone pills. Its
## letter faces the player.
class Capsule:
	extends Node3D

	var _orbits: Array[Node3D] = []
	var _pill: Node3D

	func _init(letter: String, color: Color, radius: float, pill: bool) -> void:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.18
		m.metallic = 0.15
		m.rim_enabled = true
		m.rim = 0.8
		m.rim_tint = 0.3
		var core := MeshInstance3D.new()
		core.material_override = m
		if pill:
			var cm := CapsuleMesh.new()
			cm.radius = radius * 0.6
			cm.height = radius * 2.4
			core.mesh = cm
			core.rotation.z = PI * 0.5
			_pill = Node3D.new()
			add_child(_pill)
			_pill.add_child(core)
			# The pill's lighter half.
			var half := MeshInstance3D.new()
			var hm := CapsuleMesh.new()
			hm.radius = radius * 0.62
			hm.height = radius * 1.3
			half.mesh = hm
			half.rotation.z = PI * 0.5
			half.position.x = radius * 0.6
			var m2 := m.duplicate() as StandardMaterial3D
			m2.albedo_color = color.lerp(Color.WHITE, 0.65)
			m2.emission = m2.albedo_color
			half.material_override = m2
			_pill.add_child(half)
		else:
			var sphere := SphereMesh.new()
			sphere.radius = radius * 0.8
			sphere.height = radius * 1.6
			core.mesh = sphere
			add_child(core)
			for tilt in [Vector3(1.1, 0.0, 0.5), Vector3(-1.0, 0.0, -0.6)]:
				var pivot := Node3D.new()
				pivot.rotation = tilt
				var e := MeshInstance3D.new()
				var dot := SphereMesh.new()
				dot.radius = radius * 0.15
				dot.height = radius * 0.3
				e.mesh = dot
				var em := StandardMaterial3D.new()
				em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				em.albedo_color = color.lerp(Color.WHITE, 0.6) * 2.0
				e.material_override = em
				e.position.x = radius * 1.4
				pivot.add_child(e)
				add_child(pivot)
				_orbits.append(pivot)
		var l := Label3D.new()
		l.text = letter
		l.font = FONT
		l.font_size = 48
		l.pixel_size = radius * 1.3 / 48.0
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.shaded = false
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.modulate = Color.WHITE if color.get_luminance() < 0.75 else Color(0.1, 0.1, 0.15)
		l.outline_size = 12
		l.outline_modulate = Color(0, 0, 0, 0.9) if color.get_luminance() < 0.75 else Color(1, 1, 1, 0.6)
		l.render_priority = 2
		add_child(l)

	func _process(delta: float) -> void:
		if _pill != null:
			_pill.rotate_y(delta * 2.4)
		for i in _orbits.size():
			_orbits[i].rotate_object_local(Vector3.UP, delta * (5.0 if i == 0 else -6.5))
