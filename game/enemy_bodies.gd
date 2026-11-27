## The Tilt Breaker enemy bodies (tetrahedron, cube, icosahedron, dodecahedron),
## copied from its fx.gd (PinGames). Here they only fly past outside the corridor.
extends RefCounted


## a random texel-snapped crop of ONE circuit texture (a single colour per enemy),
## chunky nearest-filtered pixels with glowing LEDs, plus glowing edges.
static func make_tetrahedron(radius: float, texture: Texture2D, edge_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Tetrahedron"
	var k := radius / sqrt(3.0)
	var v := [Vector3(1, 1, 1) * k, Vector3(1, -1, -1) * k, Vector3(-1, 1, -1) * k, Vector3(-1, -1, 1) * k]
	var faces := [[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]]
	var crop := 72.0 / 512.0
	for f in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		var n := ((a + b + c) / 3.0).normalized()  # outward for a centred tetrahedron
		var off := Vector2(randi() % 440, randi() % 440) / 512.0
		var uvs := [off + Vector2(0.0, 1.0) * crop, off + Vector2(0.5, 0.0) * crop, off + Vector2(1.0, 1.0) * crop]
		var pts := [a, b, c]
		for i in 3:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(pts[i])
		var mesh := st.commit()
		var tex: Texture2D = texture
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 1.4
		m.roughness = 0.45
		m.metallic = 0.35
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		root.add_child(mi)
	# Glowing edges
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]:
		lines.surface_add_vertex(v[e[0]] * 1.01)
		lines.surface_add_vertex(v[e[1]] * 1.01)
	lines.surface_end()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	root.add_child(li)
	return root


## D-323: the cube enemy: same look as the tetrahedron (one circuit texture,
## a random texel-snapped crop per face, glowing edges); circumradius `radius`.
static func make_cube(radius: float, texture: Texture2D, edge_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Cube"
	var h := radius / sqrt(3.0)
	var crop := 72.0 / 512.0
	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for n in normals:
		var u: Vector3 = Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		var w: Vector3 = n.cross(u)
		var c: Vector3 = n * h
		var corners := [c - u * h - w * h, c - u * h + w * h, c + u * h + w * h, c + u * h - w * h]
		var off := Vector2(randi() % 440, randi() % 440) / 512.0
		var uvs := [off + Vector2(0, 1) * crop, off + Vector2(1, 1) * crop, off + Vector2(1, 0) * crop, off]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.emission_enabled = true
		m.emission_texture = texture
		m.emission_energy_multiplier = 1.4
		m.roughness = 0.45
		m.metallic = 0.35
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		root.add_child(mi)
	# Glowing edges: the 12 between corners differing in one axis.
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var p := Vector3(x, y, z) * h * 1.01
				for d in [Vector3(x, 0, 0), Vector3(0, y, 0), Vector3(0, 0, z)]:
					if d.x + d.y + d.z > 0.0:   # each edge once
						lines.surface_add_vertex(p)
						lines.surface_add_vertex(p - d * 2.0 * h * 1.01)
	lines.surface_end()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	root.add_child(li)
	return root


## D-335: the boss body: an icosahedron (circumradius `radius`) of see-through
## circuit panels (one random crop per face) with glowing edges, so the eye
## inside shows.
static func make_icosahedron(radius: float, texture: Texture2D, edge_color: Color, alpha: float = 0.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Icosahedron"
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var raw := []
	for a in [-1.0, 1.0]:
		for b in [-phi, phi]:
			raw.append(Vector3(0, a, b))
			raw.append(Vector3(a, b, 0))
			raw.append(Vector3(b, 0, a))
	var v := []
	for p in raw:
		v.append((p as Vector3).normalized() * radius)
	var edge := INF
	for i in v.size():
		for j in range(i + 1, v.size()):
			edge = minf(edge, (v[i] as Vector3).distance_to(v[j]))
	var near := func(a: Vector3, b: Vector3) -> bool: return absf(a.distance_to(b) - edge) < edge * 0.01
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = Color(1, 1, 1, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.emission_enabled = true
	m.emission_texture = texture
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.4
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var crop := 96.0 / 512.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in v.size():
		for j in range(i + 1, v.size()):
			if not near.call(v[i], v[j]):
				continue
			for k in range(j + 1, v.size()):
				if not (near.call(v[i], v[k]) and near.call(v[j], v[k])):
					continue
				var a: Vector3 = v[i]
				var b: Vector3 = v[j]
				var c: Vector3 = v[k]
				var n := (b - a).cross(c - a).normalized()
				if n.dot(a + b + c) < 0.0:   # outwards
					var t := b
					b = c
					c = t
					n = -n
				var off := Vector2(randi() % 410, randi() % 410) / 512.0
				var uvs := [off + Vector2(0.0, 1.0) * crop, off + Vector2(0.5, 0.0) * crop, off + Vector2(1.0, 1.0) * crop]
				var pts := [a, b, c]
				for q in 3:
					st.set_normal(n)
					st.set_uv(uvs[q])
					st.add_vertex(pts[q])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.name = "Faces"
	root.add_child(mi)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in v.size():
		for j in range(i + 1, v.size()):
			if near.call(v[i], v[j]):
				lines.surface_add_vertex(v[i] * 1.01)
				lines.surface_add_vertex(v[j] * 1.01)
	lines.surface_end()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	li.name = "Edges"
	root.add_child(li)
	return root


## D-342: the level-20 boss body: a dodecahedron (circumradius `radius`), the
## icosahedron's style: see-through circuit panels and glowing edges.
static func make_dodecahedron(radius: float, texture: Texture2D, edge_color: Color, alpha: float = 0.5) -> Node3D:
	var root := Node3D.new()
	root.name = "Dodecahedron"
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var ip := 1.0 / phi
	var raw := []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				raw.append(Vector3(x, y, z))
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			raw.append(Vector3(0, a * ip, b * phi))
			raw.append(Vector3(a * ip, b * phi, 0))
			raw.append(Vector3(a * phi, 0, b * ip))
	var v := []
	for p in raw:
		v.append((p as Vector3).normalized() * radius)
	# Face normals = the dual icosahedron's vertices (0, +-phi, +-1) and cyclic;
	# each face = the 5 nearest corners. (D-346: the order was swapped before,
	# which picked the wrong corners and broke the shape.)
	var normals := []
	for a in [-1.0, 1.0]:
		for b in [-phi, phi]:
			normals.append(Vector3(0, b, a).normalized())
			normals.append(Vector3(b, a, 0).normalized())
			normals.append(Vector3(a, 0, b).normalized())
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = Color(1, 1, 1, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.emission_enabled = true
	m.emission_texture = texture
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.4
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var crop := 96.0 / 512.0
	for n in normals:
		var corners := v.duplicate()
		corners.sort_custom(func(p, q): return (p as Vector3).dot(n) > (q as Vector3).dot(n))
		corners = corners.slice(0, 5)
		var cen := Vector3.ZERO
		for c in corners:
			cen += c
		cen /= 5.0
		var ax: Vector3 = ((corners[0] as Vector3) - cen).normalized()
		var ay: Vector3 = (n as Vector3).cross(ax)
		corners.sort_custom(func(p, q): return atan2((p - cen).dot(ay), (p - cen).dot(ax)) < atan2((q - cen).dot(ay), (q - cen).dot(ax)))
		var off := Vector2(randi() % 410, randi() % 410) / 512.0
		for i in 5:
			var a: Vector3 = corners[i]
			var b: Vector3 = corners[(i + 1) % 5]
			var tri := [cen, a, b]
			var uvs := [off + Vector2(0.5, 0.5) * crop, off + Vector2(0.5 + 0.5 * cos(i * TAU / 5.0), 0.5 + 0.5 * sin(i * TAU / 5.0)) * crop,
				off + Vector2(0.5 + 0.5 * cos((i + 1) * TAU / 5.0), 0.5 + 0.5 * sin((i + 1) * TAU / 5.0)) * crop]
			for q in 3:
				st.set_normal(n)
				st.set_uv(uvs[q])
				st.add_vertex(tri[q])
			lines.surface_add_vertex(a * 1.01)
			lines.surface_add_vertex(b * 1.01)
	lines.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	root.add_child(mi)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = edge_color * 2.5
	var li := MeshInstance3D.new()
	li.mesh = lines
	li.material_override = lm
	root.add_child(li)
	return root


