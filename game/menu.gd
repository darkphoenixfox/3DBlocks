## A menu panel in the room: rows of text you point at (controller ray, or the
## mouse in the desktop preview) and click with the trigger.
## Rows: {id, label, kind: "button" | "choice" | "slider", ...}
##   choice: names: Array of the values' names, value: index
##   slider: value: 0..1 (click or drag along the bar)
## Emits activated(id) for buttons and changed(id, value) for the others.
extends Node3D

signal activated(id: String)
signal changed(id: String, value: Variant)

const FONT = preload("res://assets/fonts/pinpixel.ttf")
const WIDTH := 1.25
const ROW_H := 0.105
const TEXT_H := 0.06
const BAR_X := 0.12                 # sliders: the bar's left end
const BAR_W := 0.42
const COL := Color(0.75, 0.9, 1.0)
const HOVER := Color(1.0, 0.9, 0.35)
const ACCENT := Color("3ec7ff")

var rows: Array = []
var hover := -1
var _nodes: Array = []      # per row: {label, value, fill}
var _panel: MeshInstance3D
var _dragging := -1


func show_rows(new_rows: Array) -> void:
	for c in get_children():
		c.queue_free()
	_nodes.clear()
	rows = new_rows
	hover = -1
	_dragging = -1
	var h := rows.size() * ROW_H + 0.08
	_panel = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH, h)
	_panel.mesh = q
	_panel.material_override = _flat(Color(0.02, 0.05, 0.12, 0.78))
	_panel.position.z = -0.01
	add_child(_panel)
	for edge_y in [h * 0.5, -h * 0.5]:
		var line := MeshInstance3D.new()
		var lq := QuadMesh.new()
		lq.size = Vector2(WIDTH, 0.008)
		line.mesh = lq
		line.material_override = _flat(ACCENT)
		line.position = Vector3(0, edge_y, -0.005)
		add_child(line)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var y := _row_y(i)
		var n := {}
		var is_button: bool = r.kind == "button"
		var label := _text(r.label, Vector3(0.0 if is_button else -WIDTH * 0.5 + 0.07, y, 0))
		if not is_button:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		n["label"] = label
		if r.kind == "choice":
			n["value"] = _text("", Vector3(BAR_X + BAR_W * 0.5, y, 0))
		elif r.kind == "slider":
			var track := MeshInstance3D.new()
			var tq := QuadMesh.new()
			tq.size = Vector2(BAR_W, 0.03)
			track.mesh = tq
			track.material_override = _flat(Color(0.15, 0.25, 0.4))
			track.position = Vector3(BAR_X + BAR_W * 0.5, y, 0.0)
			add_child(track)
			var fill := MeshInstance3D.new()
			var fq := QuadMesh.new()
			fq.size = Vector2(1.0, 0.03)
			fill.mesh = fq
			fill.material_override = _flat(ACCENT)
			add_child(fill)
			n["fill"] = fill
			n["value"] = _text("", Vector3(BAR_X + BAR_W + 0.09, y, 0))
		_nodes.append(n)
		_refresh(i)


func set_value(id: String, value: Variant) -> void:
	for i in rows.size():
		if rows[i].id == id:
			rows[i]["value"] = value
			_refresh(i)


func _row_y(i: int) -> float:
	return (rows.size() - 1) * ROW_H * 0.5 - i * ROW_H


func _text(text: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 48
	l.pixel_size = TEXT_H / 48.0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.modulate = COL
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.position = pos
	add_child(l)
	return l


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _refresh(i: int) -> void:
	var r: Dictionary = rows[i]
	var n: Dictionary = _nodes[i]
	var c := HOVER if i == hover else COL
	(n.label as Label3D).modulate = c
	if r.kind == "choice":
		(n.value as Label3D).text = "< %s >" % str(r.names[int(r.value)])
		(n.value as Label3D).modulate = c
	elif r.kind == "slider":
		var v := clampf(float(r.value), 0.0, 1.0)
		var fill: MeshInstance3D = n.fill
		fill.scale.x = maxf(v * BAR_W, 0.001)
		fill.position = Vector3(BAR_X + v * BAR_W * 0.5, _row_y(i), 0.002)
		(n.value as Label3D).text = "%d" % roundi(v * 10.0)
		(n.value as Label3D).modulate = c


## Where a ray (world space) meets the panel: its point in the panel's own
## plane, or null if it misses.
func ray_point(origin: Vector3, dir: Vector3) -> Variant:
	var inv := global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if d.z >= -1e-5 or o.z <= 0.0:
		return null
	var p := o + d * (-o.z / d.z)
	var h := rows.size() * ROW_H + 0.08
	if absf(p.x) > WIDTH * 0.5 or absf(p.y) > h * 0.5:
		return null
	return Vector2(p.x, p.y)


## Points at the panel (null = nowhere): highlights the row under the point
## and, while a slider is held, drags it.
func point(at: Variant) -> void:
	var row := -1
	if at != null:
		row = clampi(int(floor(((rows.size() * ROW_H * 0.5) - (at as Vector2).y) / ROW_H)), 0, rows.size() - 1)
	if _dragging >= 0 and at != null:
		_slide(_dragging, (at as Vector2).x)
		row = _dragging
	if row != hover:
		var old := hover
		hover = row
		if old >= 0:
			_refresh(old)
		if hover >= 0:
			_refresh(hover)


## Trigger down at `at`. Returns true if it landed on a row.
func press(at: Variant) -> bool:
	point(at)
	if hover < 0 or at == null:
		return false
	var r: Dictionary = rows[hover]
	match r.kind:
		"button":
			activated.emit(r.id)
		"choice":
			# The left part of the value steps back, the rest forward.
			var back: bool = (at as Vector2).x < BAR_X + BAR_W * 0.25 and (at as Vector2).x > BAR_X - 0.05
			var count: int = (r.names as Array).size()
			r["value"] = posmod(int(r.value) + (-1 if back else 1), count)
			_refresh(hover)
			changed.emit(r.id, r.value)
		"slider":
			_dragging = hover
			_slide(hover, (at as Vector2).x)
	return true


func release() -> void:
	_dragging = -1


func _slide(i: int, x: float) -> void:
	var v := snappedf(clampf((x - BAR_X) / BAR_W, 0.0, 1.0), 0.1)
	if not is_equal_approx(v, float(rows[i].value)):
		rows[i]["value"] = v
		_refresh(i)
		changed.emit(rows[i].id, v)
