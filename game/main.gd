## 3D Blocks: a VR block breaker in Tilt Breaker's style (PinGames). You stand
## at the near end of a corridor of four energy walls, floating above the Earth;
## walls of circuit bricks stand at the far end. The paddle is Tilt Breaker's
## ship inside a rectangular energy field, held in your hand: it follows the
## controller (position and tilt), and the field is what stops the plasma.
##
## VR (run with --xr-mode on, see scripts/run_vr.ps1):
##   trigger          in the menus: click what you point at
##                    in play: takes the paddle into that hand (one-paddle
##                    mode); launches the plasma; hold to charge the blaster,
##                    release to fire
##   B / Y            recentre: the corridor moves to where you stand
##   menu button      back to the menu
## Without a headset it opens a desktop preview: mouse = paddle and pointer,
## left button = trigger (right button = the second paddle's), Esc = menu.
## Dev flags (after --): --demo (plays itself), --start, --level=N,
##   --paddles=N, --eye, --room=N, --speed=N, --lives=N (override the options),
##   --menu=options, --pu=T,K (start with power-ups),
##   --screenshot=<png> [--screenshot-delay=<s>] [--cam=x,y,z]
extends Node3D

const Sim = preload("res://game/sim.gd")
const Fx = preload("res://game/fx.gd")
const Synth = preload("res://game/synth.gd")
const Sounds = preload("res://game/sounds.gd")
const Settings = preload("res://game/settings.gd")
const Menu = preload("res://game/menu.gd")
const Backdrop = preload("res://game/backdrop.gd")
const BRICK_SHADER = preload("res://shaders/brick_circuit.gdshader")
const WALL_SHADER = preload("res://shaders/wall_field.gdshader")
const FIELD_SHADER = preload("res://shaders/paddle_field.gdshader")
const SHIP_SHADER = preload("res://shaders/ship.gdshader")
const EXPLOSION_SHADER = preload("res://shaders/explosion.gdshader")
const SKY_SHADER = preload("res://shaders/starfield_sky.gdshader")
const FONT = preload("res://assets/fonts/pinpixel.ttf")
const PADDLE_MODEL := "res://assets/models/breakout/paddle.glb"
const TEX := "res://assets/textures/breakout/%s.png"
const MUSIC := "res://assets/audio/music/breakout/tilt_breaker_original.ogg"
const MUSIC_2 := "res://assets/audio/music/breakout/tilt_breaker_2_original.ogg"   # levels 11-20
const MUSIC_ATTRACT := "res://assets/audio/music/breakout/dead_ship_attract.ogg"
const MUSIC_GAME_OVER := "res://assets/audio/music/breakout/earths_end.ogg"

const ACCENT := Color("3ec7ff")
const LETTER_COLOUR := {"R": "red", "Y": "yellow", "G": "green", "B": "blue"}
const CIRCUIT_GLOW := {"red": Color("ff5a32"), "yellow": Color("ffd23e"), "green": Color("4dff6a"), "blue": Color("3ec7ff")}
const CIRCUIT_TEXELS := 512.0
const BRICK_TEXELS_W := 64.0
## Tilt Breaker's power-up colours and names.
const POWERUP_COLORS := {"T": Color(0.3, 0.55, 1.0), "P": Color(1.0, 0.25, 0.2), "B": Color(1.0, 0.85, 0.2),
	"I": Color(0.72, 0.3, 1.0), "L": Color(1.0, 1.0, 1.0), "S": Color(0.3, 1.0, 0.4),
	"U": Color(1.0, 0.35, 0.7), "N": Color(1.0, 0.5, 0.05),
	"W": Color(0.2, 1.0, 0.9), "H": Color(0.65, 1.0, 0.2), "K": Color(0.55, 0.75, 1.0)}
const POWERUP_NAMES := {"T": "TRIPLE LASER", "P": "POWER LASER", "B": "BOUNCE PLASMA", "I": "ION CANNON",
	"L": "LIGHTSPEED", "S": "SHIELD", "U": "1UP", "N": "NUCLEAR!", "W": "WAVE BEAM",
	"H": "HOMING MISSILE", "K": "SIDEKICKS"}
## Blast charge levels: glow and bolt colour.
const LEVEL_COLORS := [Color(0.35, 0.65, 1.0), Color(1.0, 0.85, 0.25), Color(1.0, 0.3, 0.2)]

const MODEL_WIDTH := 1.9          # paddle.glb's native length along X
const SHIP_WIDTH := 0.30          # metres in the hand
const HAND_FORWARD := 0.08        # the field floats this far in front of the controller
const STAND_Z := 0.85             # where the player stands (arena z)
const CHEST_BELOW_EYES := 0.38    # the corridor's centre line, below eye height
const PLANET_RADIUS := 600.0
const PLANET_BELOW := 60.0        # metres from the corridor down to the surface
const MENU_DIST := 1.4            # the menu panel, metres in front of the player
const HANDS := ["right", "left"]  # two-paddle mode: paddle 0, paddle 1
const SFX_USED := ["tb_fire", "tb_shield", "tb_brick", "tb_armour", "tb_explode", "tb_explode_big",
	"tb_rack", "tb_extra_life", "tb_blast1", "tb_blast2", "tb_blast3", "tb_charge1", "tb_charge2",
	"tb_charge3", "tb_level1", "tb_level2", "tb_level3", "tb_ion", "tb_wormhole", "tb_pu_drop",
	"tb_pu_get", "tb_low_power", "tb_shield_break", "tb_brick_land", "tb_ship_arrive"]

var sim := Sim.new()
var settings := Settings.new()
var xr_active := false
var _mode := "attract"   # attract | play | clear | over
var _mode_t := 0.0
var _args := {}
var _demo := false

var _arena: Node3D
var _cam: Node3D
var _origin: XROrigin3D
var _controllers := {}
var _pointers := {}       # hand -> beam MeshInstance3D
var _hand := "right"      # one-paddle mode: the hand that holds it
var _press_hand := ""     # the hand whose trigger is down (in play)
var _walls := {}          # side -> {node, mat, age}
var _shield_wall: MeshInstance3D
var _paddles: Array = []  # per paddle: {root, field, mat, age, flash, sidekicks, glow, wide}
var _ship_mat: ShaderMaterial
var _ghost_mat: ShaderMaterial
var _ghost_nodes: Array[Node3D] = []
var _serve_ball: Node3D
var _brick_mesh: BoxMesh
var _brick_mats := {}
var _brick_nodes: Array[MeshInstance3D] = []
var _debris_mats := {}
var _ball_nodes := {}     # id -> [ball, trail]
var _blast_nodes := {}
var _wave_nodes := {}
var _missile_nodes := {}
var _capsule_nodes := {}
var _hud_score: Label3D
var _hud_level: Label3D
var _hud_lives: Label3D
var _hud_blaster: Label3D
var _hud_padup: Label3D
var _msg_sprite: Sprite3D
var _msg_label: Label3D
var _msg_sub: Label3D
var _menu_root: Node3D
var _menu: Menu
var _menu_page := "main"
var _logo: Sprite3D
var _music: AudioStreamPlayer
var _music_path := ""
var _sfx_pool: Array[AudioStreamPlayer3D] = []
var _sfx_next := 0
var _sfx_job: Variant
var _charge_player: AudioStreamPlayer3D
var _mouse := Vector2(0.5, 0.5)
var _demo_t := 0.0
var _demo_hold := 0.0
var _shot_at := -1.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_demo = _args.has("demo")
	if _args.has("screenshot"):
		_shot_at = float(_args.get("screenshot-delay", "3"))
	settings.load_file()
	# Dev overrides of the saved options (not saved).
	for k in ["paddles", "room", "speed", "lives"]:
		if _args.has(k):
			settings.values[k] = int(_args[k])
	if _args.has("eye"):
		settings.values["eye"] = true
	_sfx_job = Synth.begin_many(SFX_USED.map(func(n: String) -> Variant: return Sounds.SOUNDS[n]))
	_build_space()
	_arena = Node3D.new()
	add_child(_arena)
	xr_active = _start_xr()
	if not xr_active:
		_desktop_camera()
	_build_corridor()
	_build_paddles()
	_build_hud()
	_build_menu()
	_build_audio()
	var backdrop := Backdrop.new()
	backdrop.sound = func(sound_name: String, at: Vector3) -> void: _sfx(sound_name, at, -12.0)
	_arena.add_child(backdrop)
	_apply_settings()
	_place_arena()
	if _args.has("start") or _args.has("level") or _demo:
		_start_game()
	else:
		_enter_attract()
		if _args.get("menu", "") == "options":
			_show_page("options")


# --- XR ------------------------------------------------------------------------------
func _start_xr() -> bool:
	var xr := XRServer.find_interface("OpenXR")
	if xr == null or not xr.is_initialized():
		print("3D Blocks: no OpenXR runtime, desktop preview")
		return false
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # the headset paces frames
	_origin = XROrigin3D.new()
	add_child(_origin)
	var cam := XRCamera3D.new()
	cam.far = 2000.0
	_origin.add_child(cam)
	_cam = cam
	for hand in ["left", "right"]:
		var c := XRController3D.new()
		c.tracker = "%s_hand" % hand
		c.pose = &"aim"
		c.button_pressed.connect(_on_button.bind(hand, true))
		c.button_released.connect(_on_button.bind(hand, false))
		_origin.add_child(c)
		_controllers[hand] = c
		# The menu pointer: a thin beam along the controller's aim.
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.004, 0.004, 1.0)
		beam.mesh = box
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = ACCENT
		beam.material_override = m
		beam.visible = false
		c.add_child(beam)
		_pointers[hand] = beam
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	print("3D Blocks: OpenXR running")
	return true


func _on_button(button: String, hand: String, pressed: bool) -> void:
	match button:
		"trigger_click":
			_trigger(hand, pressed)
		"by_button":
			if pressed:
				recenter()
		"menu_button":
			if pressed and _mode != "attract":
				_enter_attract()


## Puts the corridor in front of where you stand now, at your chest height.
func recenter() -> void:
	if xr_active:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	_place_arena()


func _room() -> float:
	return settings.room_scale()


func _place_arena() -> void:
	var s := _room()
	var eye := 1.6
	if xr_active and _cam.position.y > 0.4:
		eye = _cam.position.y
	var y := clampf(eye - CHEST_BELOW_EYES, 0.7, 1.4)
	_arena.scale = Vector3.ONE * s
	_arena.position = Vector3(0, y, 0)
	if xr_active:
		_origin.position = Vector3(0, 0, STAND_Z * s)
		_menu_root.position = Vector3(0, y + 0.1, STAND_Z * s - MENU_DIST)
	else:
		_cam.position = Vector3(0, y + 0.3 * s, (STAND_Z + 0.45) * s)
		_cam.look_at(Vector3(0, y - 0.05, -2.0 * s), Vector3.UP)
		# Dev: --cam=x,y,z places the preview camera elsewhere (screenshots).
		var at := str(_args.get("cam", "")).split(",")
		if at.size() == 3:
			_cam.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
			_cam.look_at(Vector3(0, y, Sim.Z_FRONT * s), Vector3.UP)
		# The preview's menu hangs right in front of the camera.
		_menu_root.global_transform = _cam.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, -0.08, -1.0))


func _desktop_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 80.0
	cam.far = 2000.0
	add_child(cam)
	cam.current = true
	_cam = cam


## The hand that holds paddle `i`.
func _hand_of(i: int) -> String:
	return HANDS[i] if sim.paddle_count == 2 else _hand


func _buzz(amplitude: float, seconds: float, paddle: int = 0) -> void:
	if xr_active:
		(_controllers[_hand_of(paddle)] as XRController3D).trigger_haptic_pulse("haptic", 0.0, amplitude, seconds, 0.0)


# --- input ---------------------------------------------------------------------------
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position / Vector2(get_viewport().get_visible_rect().size)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_trigger("right", ev.pressed)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
		_trigger("left", ev.pressed)
	elif ev is InputEventKey and not ev.echo:
		if ev.keycode == KEY_SPACE:
			_trigger("right", ev.pressed)
		elif ev.pressed and ev.keycode == KEY_ESCAPE:
			if _mode == "attract":
				get_tree().quit()
			else:
				_enter_attract()
		elif ev.pressed and ev.keycode == KEY_R:
			recenter()


## A trigger went down or up.
func _trigger(hand: String, pressed: bool) -> void:
	match _mode:
		"attract":
			if pressed:
				_menu.press(_pointer_at(hand))
			else:
				_menu.release()
		"play":
			if sim.paddle_count == 2:
				var i := HANDS.find(hand)
				if pressed:
					sim.press(i)
				else:
					sim.release(i)
			elif pressed:
				if sim.charge_hand < 0:
					_hand = hand   # the paddle goes to the hand that pulls
					_press_hand = hand
					sim.press(0)
			elif hand == _press_hand:
				_press_hand = ""
				sim.release(0)
			_handle_events()   # events made outside step() would be cleared by it
		"over":
			if pressed and _mode_t > 2.5:
				_enter_attract()


## Where `hand` points on the menu panel (Vector2 in the panel, or null).
func _pointer_at(hand: String) -> Variant:
	if xr_active:
		var c: XRController3D = _controllers[hand]
		if not c.get_has_tracking_data():
			return null
		return _menu.ray_point(c.global_position, -c.global_basis.z)
	var cam := _cam as Camera3D
	var px := _mouse * Vector2(get_viewport().get_visible_rect().size)
	return _menu.ray_point(cam.project_ray_origin(px), cam.project_ray_normal(px))


## Where the hand holds paddle `i`, in arena space.
func _paddle_target(i: int, delta: float) -> Transform3D:
	if xr_active:
		var c: XRController3D = _controllers[_hand_of(i)]
		if not c.get_has_tracking_data():
			return sim.paddles[i]
		var g := c.global_transform
		g.origin += g.basis * Vector3(0, 0, -HAND_FORWARD)
		var t := _arena.global_transform.affine_inverse() * g
		return t
	var want := Vector3((_mouse.x - 0.5) * 2.2 * Sim.HALF.x, (0.5 - _mouse.y) * 2.2 * Sim.HALF.y, 0.25)
	var basis := Basis.IDENTITY
	if _demo:
		want = Vector3(sin(_demo_t * 0.7) * 0.3, sin(_demo_t * 0.9) * 0.2, 0.25)
		var best := -INF
		for b in sim.balls:
			if b.vel.z > 0.0 and b.pos.z > best and b.pos.z < 0.25:
				best = b.pos.z
				# Meet it where it will cross the paddle's plane, a little off
				# centre so the returns wander over the wall.
				var t: float = (0.25 - b.pos.z) / b.vel.z
				var at: Vector3 = b.pos + b.vel * t
				want = Vector3(_fold(at.x, Sim.HALF.x - Sim.BALL_R) + sin(_demo_t * 1.3) * 0.11,
					_fold(at.y, Sim.HALF.y - Sim.BALL_R) + cos(_demo_t * 1.7) * 0.07, 0.25)
		basis = Basis.from_euler(Vector3(sin(_demo_t * 0.5) * 0.25, sin(_demo_t * 0.8) * 0.3, 0.0))
		want = sim.paddles[0].origin.lerp(want, minf(1.0, 14.0 * delta))
	if i == 1:   # the preview's second paddle mirrors the first
		var first := sim.paddles[0].origin
		want = Vector3(-first.x, -first.y, 0.25)
	return Transform3D(basis, want)


## A straight-line coordinate folded back between the walls it bounces off.
static func _fold(v: float, half: float) -> float:
	var span := half * 4.0
	var m := fposmod(v + half, span)
	return (m if m < half * 2.0 else span - m) - half


# --- options ---------------------------------------------------------------------------
func _apply_settings() -> void:
	sim.paddle_count = int(settings.values["paddles"])
	sim.start_lives = int(settings.values["lives"])
	sim.speed = settings.speed_name()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(float(settings.values["music"]), 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), float(settings.values["music"]) <= 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(float(settings.values["sfx"]), 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), float(settings.values["sfx"]) <= 0.0)
	_apply_eye()


## Eye training: the ball in one eye, the paddles and bricks in the other,
## swapping each level. Only while playing; -1 = both eyes.
func _apply_eye() -> void:
	var ball := -1
	var world := -1
	if bool(settings.values["eye"]) and (_mode == "play" or _mode == "clear"):
		ball = (sim.level - 1) % 2
		world = 1 - ball
	RenderingServer.global_shader_parameter_set(&"eye_ball", ball)
	RenderingServer.global_shader_parameter_set(&"eye_world", world)


func _build_menu() -> void:
	_menu_root = Node3D.new()
	add_child(_menu_root)
	_logo = Sprite3D.new()
	_logo.texture = load(TEX % "logo")
	_logo.shaded = false
	_logo.pixel_size = 0.75 / _logo.texture.get_width()
	_logo.position = Vector3(0, 0.62, 0)
	_menu_root.add_child(_logo)
	_menu = Menu.new()
	_menu_root.add_child(_menu)
	_menu.activated.connect(_on_menu_button)
	_menu.changed.connect(_on_menu_changed)


func _show_page(page: String) -> void:
	_menu_page = page
	var v := settings.values
	if page == "options":
		_menu.show_rows([
			{"id": "speed", "label": "SPEED", "kind": "choice", "names": ["SLOW", "NORMAL", "FAST"], "value": v["speed"]},
			{"id": "lives", "label": "LIVES", "kind": "choice", "names": ["1", "2", "3", "4", "5"], "value": int(v["lives"]) - 1},
			{"id": "room", "label": "ROOM SIZE", "kind": "choice", "names": Settings.ROOM_NAMES, "value": v["room"]},
			{"id": "paddles", "label": "PADDLES", "kind": "choice", "names": ["ONE", "TWO"], "value": int(v["paddles"]) - 1},
			{"id": "eye", "label": "EYE TRAINING", "kind": "choice", "names": ["OFF", "ON"], "value": 1 if v["eye"] else 0},
			{"id": "music", "label": "MUSIC", "kind": "slider", "value": v["music"]},
			{"id": "sfx", "label": "SFX", "kind": "slider", "value": v["sfx"]},
			{"id": "back", "label": "BACK", "kind": "button"},
		])
		_menu.position.y = -0.05
		_logo.visible = false
	else:
		var rows := [{"id": "start", "label": "START GAME", "kind": "button"},
			{"id": "options", "label": "OPTIONS", "kind": "button"}]
		if not OS.has_feature("android"):
			rows.append({"id": "quit", "label": "QUIT", "kind": "button"})
		_menu.show_rows(rows)
		_menu.position.y = -0.1
		_logo.visible = true


func _on_menu_button(id: String) -> void:
	_sfx("tb_pu_drop", _menu_root.position - _arena.position)
	match id:
		"start":
			_start_game()
		"options":
			_show_page("options")
		"back":
			_show_page("main")
		"quit":
			get_tree().quit()


func _on_menu_changed(id: String, value: Variant) -> void:
	match id:
		"speed", "room":
			settings.values[id] = int(value)
		"lives", "paddles":
			settings.values[id] = int(value) + 1
		"eye":
			settings.values[id] = int(value) == 1
		"music", "sfx":
			settings.values[id] = float(value)
	settings.save_file()
	_apply_settings()
	if id == "room":
		_place_arena()
	if id == "sfx":
		_sfx("tb_brick", Vector3(0, 0, -0.5))
	elif id != "music":
		_sfx("tb_brick_land", Vector3(0, 0, -0.5))


# --- game flow ------------------------------------------------------------------------
func _enter_attract() -> void:
	_mode = "attract"
	_mode_t = 0.0
	_press_hand = ""
	_stop_charge_sound()
	_apply_settings()
	sim.start_game()
	_build_bricks(false)
	_hide_message()
	_menu_root.visible = true
	_show_page("main")
	_play_music(MUSIC_ATTRACT)
	_refresh_hud()


func _start_game() -> void:
	_menu_root.visible = false
	_apply_settings()
	_place_arena()
	sim.start_game(int(_args.get("level", "1")))
	for kind in str(_args.get("pu", "")).split(",", false):
		sim.apply_powerup(kind)
	_mode = "play"
	_mode_t = 0.0
	_apply_eye()
	_build_bricks(true)
	_show_ready()
	_play_music(_level_music())
	_sfx("tb_ship_arrive", sim.paddles[0].origin)
	_refresh_hud()


func _show_ready() -> void:
	var sub := "TRIGGER: LAUNCH    HOLD: CHARGE THE BLASTER"
	if bool(settings.values["eye"]):
		sub = "EYE TRAINING: BALL IN YOUR %s EYE" % ("LEFT" if (sim.level - 1) % 2 == 0 else "RIGHT")
	_show_message("ready", "LEVEL %d" % sim.level, sub)


func _level_music() -> String:
	return MUSIC_2 if ((sim.level - 1) % Sim.LEVEL_COUNT) >= 10 else MUSIC


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	_mode_t += delta
	_demo_t += delta
	if _sfx_job != null and Synth.many_done(_sfx_job):
		Synth.finish_many(_sfx_job)
		_sfx_job = null
	for i in sim.paddle_count:
		sim.set_paddle(i, _paddle_target(i, delta))
	if _mode == "play":
		sim.step(delta)
		_handle_events()
	elif _mode == "clear" and _mode_t > 2.6:
		sim.next_level()
		_mode = "play"
		_apply_eye()
		_build_bricks(true)
		_show_ready()
		_play_music(_level_music())
		_refresh_hud()
	elif _mode == "attract":
		_update_pointers()
	if _demo:
		_demo_play(delta)
	_animate(delta)
	if _shot_at >= 0.0 and _mode_t >= _shot_at and Engine.get_process_frames() > 10:
		_shot_at = -1.0
		_screenshot.call_deferred()


## In the menus: the row under a pointer lights up; the beams show the aim.
func _update_pointers() -> void:
	var at: Variant = null
	if xr_active:
		for hand in _controllers:
			var p: Variant = _pointer_at(hand)
			if p != null and (at == null or hand == _hand):
				at = p
	else:
		at = _pointer_at("right")
	_menu.point(at)


func _demo_play(delta: float) -> void:
	if _mode == "play" and sim.state == Sim.State.SERVE and _mode_t > 2.5 and sim.serve_lock <= 0.0:
		_trigger("right", true)
		_trigger("right", false)
	elif _mode == "play" and sim.state == Sim.State.PLAY:
		# Charge the blaster whenever the bar is full; let go at the top.
		if sim.charge_hand < 0 and sim.power >= 0.999:
			_trigger("right", true)
			_demo_hold = 0.0
		elif sim.charge_hand >= 0:
			_demo_hold += delta
			if _demo_hold > 0.3 and sim.blast_charge <= 0.0:
				_trigger("right", false)
	elif _mode == "over" and _mode_t > 4.0:
		_start_game()


func _screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(_args["screenshot"]))
	get_tree().quit()


func _handle_events() -> void:
	var nuked := sim.events.any(func(ev: Array) -> bool: return ev[0] == "nuke")
	for e in sim.events:
		match e[0]:
			"serve":
				_sfx("tb_fire", e[1])
				_hide_message()
				_buzz(0.5, 0.08, sim.serve_hand)
			"paddle":
				_sfx("tb_shield", e[1][0])
				var pv: Dictionary = _paddles[e[1][2]]
				pv.age = 0.0
				var off: Vector2 = e[1][1]
				(pv.mat as ShaderMaterial).set_shader_parameter("hit", off * sim.paddle_half())
				_buzz(0.7, 0.06, e[1][2])
			"ghost":
				_sfx("tb_shield", e[1], -4.0)
			"wall":
				_sfx("tb_shield", e[1][1], -8.0)
				_flash_wall(e[1][0], e[1][1])
			"brick":
				var idx: int = e[1][0]
				var n := _brick_nodes[idx]
				n.visible = false
				_explode(e[1][1], _brick_glow(sim.bricks[idx]), 1.5 if nuked else 1.0)
				if not nuked:
					_sfx("tb_brick", e[1][1])
				_refresh_hud()
			"armour":
				var n := _brick_nodes[e[1][0]]
				n.set_instance_shader_parameter("mode", 2.0)
				_flash_brick(n)
				_sfx("tb_armour", e[1][1])
			"metal":
				_flash_brick(_brick_nodes[e[1][0]])
				_sfx("tb_armour", e[1][1], -6.0)
			"ball_free":
				_sfx("tb_pu_drop", e[1])
			"rack_clear":
				_mode = "clear"
				_mode_t = 0.0
				_stop_charge_sound()
				_sfx("tb_rack", Vector3(0, 0, -1.5))
				_show_message("", "LEVEL CLEAR  +%d" % Sim.RACK_BONUS, "")
				_refresh_hud()
			"lost":
				_stop_charge_sound()
				_sfx("tb_explode_big" if sim.state == Sim.State.OVER else "tb_explode", e[1])
				_explode(Vector3(e[1].x, e[1].y, Sim.Z_DRAIN - 0.1), ACCENT, 2.0)
				_buzz(1.0, 0.3)
				if sim.state != Sim.State.OVER:
					_show_ready()
				_refresh_hud()
			"over":
				_mode = "over"
				_mode_t = 0.0
				_apply_eye()
				_show_message("game_over", "SCORE %d" % sim.score, "")
				_play_music(MUSIC_GAME_OVER)
			"charge_start":
				_stop_charge_sound()
				_charge_player = _sfx("tb_charge%d" % int(e[1]), sim.paddles[maxi(sim.charge_hand, 0)].origin)
			"charged":
				_stop_charge_sound()
				_sfx("tb_level%d" % int(e[1]), sim.paddles[maxi(sim.charge_hand, 0)].origin)
				_buzz(0.3 + 0.2 * int(e[1]), 0.05, maxi(sim.charge_hand, 0))
			"blast":
				_stop_charge_sound()
				_sfx("tb_blast%d" % clampi(int(e[1][2]), 1, 3), e[1][1])
				_buzz(0.5, 0.06, maxi(sim.charge_hand, 0))
			"blast_fail":
				_sfx("tb_low_power", sim.paddles[0].origin)
			"blast_end":
				if e[1][2] < 0:
					_explode(e[1][1], LEVEL_COLORS[clampi(int(e[1][3]), 1, 3) - 1], 0.6, false)
			"ion_beam":
				_stop_charge_sound()
				_sfx("tb_ion", e[1][0])
				_ion_beam(e[1][0], e[1][1])
				_buzz(0.9, 0.2, maxi(sim.charge_hand, 0))
			"wave_fire":
				_stop_charge_sound()
				_sfx("tb_blast2", e[1])
			"missile_fire", "bounce_ball":
				_stop_charge_sound()
				_sfx("tb_fire", e[1])
			"missile_blast":
				_sfx("tb_explode", e[1])
				_explode(e[1], POWERUP_COLORS["H"], 3.0, false)
			"pu_drop":
				_sfx("tb_pu_drop", e[1][1])
			"pu_get":
				_sfx("tb_pu_get", e[1][1])
				for pv in _paddles:
					pv.flash = 1.0
				_popup(POWERUP_NAMES[e[1][0]], e[1][1], POWERUP_COLORS[e[1][0]])
				_buzz(0.6, 0.15)
				_refresh_hud()
			"pu_end":
				_refresh_hud()
			"shield_save":
				_sfx("tb_shield_break", e[1])
				_explode(e[1], POWERUP_COLORS["S"], 1.2, false)
			"extra_life":
				_sfx("tb_extra_life", Vector3(0, 0, -1.0))
				_popup("EXTRA LIFE", Vector3(0, 0.2, -1.2), POWERUP_COLORS["U"])
				_refresh_hud()
			"nuke":
				_sfx("tb_explode_big", Vector3(0, 0, Sim.Z_FRONT))


# --- per-frame view --------------------------------------------------------------------
func _animate(delta: float) -> void:
	var playing := _mode == "play"
	var half := sim.paddle_half()
	var charge_level := int(floor(sim.blast_charge + 0.0001))
	for i in _paddles.size():
		var pv: Dictionary = _paddles[i]
		var root: Node3D = pv.root
		root.visible = i < sim.paddle_count
		if not root.visible:
			continue
		root.transform = sim.paddles[i]
		pv.age += delta
		pv.flash = maxf(0.0, float(pv.flash) - delta * 2.5)
		var mat: ShaderMaterial = pv.mat
		mat.set_shader_parameter("age", pv.age)
		mat.set_shader_parameter("power", sim.power)
		mat.set_shader_parameter("flash", float(pv.flash) * 0.6)
		mat.set_shader_parameter("bar_color", POWERUP_COLORS.get(sim.powerup, Color(1.0, 0.85, 0.25)))
		if half != pv.half:
			pv.half = half
			((pv.field as MeshInstance3D).mesh as QuadMesh).size = half * 2.0
			mat.set_shader_parameter("size", half * 2.0)
		for sk in pv.sidekicks:
			(sk as Node3D).visible = sim.padup == "K"
		# The charge gathers in front of the nose.
		var glow: Node3D = pv.glow
		glow.visible = playing and sim.charge_hand == i and sim.blast_charge > 0.02
		if glow.visible:
			glow.scale = Vector3.ONE * (0.35 + 0.45 * sim.blast_charge + 0.08 * sin(_mode_t * 30.0))
			Fx.tint_plasma(glow, POWERUP_COLORS.get(sim.powerup, LEVEL_COLORS[clampi(charge_level, 0, 2)]))
	# Lightspeed afterimages.
	var ghosts := sim.ghosts() if playing else ([] as Array[Transform3D])
	for i in _ghost_nodes.size():
		_ghost_nodes[i].visible = i < ghosts.size()
		if i < ghosts.size():
			_ghost_nodes[i].transform = ghosts[i]
	for side in _walls:
		var w: Dictionary = _walls[side]
		if w.age < 2.0:
			w.age += delta
			(w.mat as ShaderMaterial).set_shader_parameter("age", w.age)
	_shield_wall.visible = sim.shield_active and playing
	for hand in _pointers:
		var beam: MeshInstance3D = _pointers[hand]
		beam.visible = _mode == "attract"
		if beam.visible:
			var c: XRController3D = _controllers[hand]
			var length := (_menu_root.global_position - c.global_position).length() + 0.3
			beam.scale = Vector3(1, 1, length)
			beam.position = Vector3(0, 0, -length * 0.5)
	_serve_ball.visible = playing and sim.state == Sim.State.SERVE and sim.serve_lock <= 0.0
	_serve_ball.position = sim.serve_pos()
	var eye := _arena.to_local(_cam.global_position)
	# Balls, shots and capsules: one node per live thing in the sim.
	_sync(_ball_nodes, sim.balls if playing else [], func(_b: Dictionary) -> Array:
		var ball := Fx.make_plasma_ball(Sim.BALL_R, Fx.EYE_BALL)
		var trail := Fx.Trail.new(Fx.EYE_BALL)
		_arena.add_child(ball)
		_arena.add_child(trail)
		return [ball, trail])
	for b in sim.balls:
		if _ball_nodes.has(b.id):
			(_ball_nodes[b.id][0] as Node3D).position = b.pos
			(_ball_nodes[b.id][1] as Fx.Trail).update(b.pos, eye)
	_sync(_blast_nodes, sim.blasts if playing else [], func(s: Dictionary) -> Array:
		var lvl := clampi(int(s.level), 1, 3)
		var bolt := Fx.make_plasma_ball(Sim.BLAST_R * float(Sim.BLAST_SCALE[lvl - 1]) * 1.2)
		Fx.tint_plasma(bolt, POWERUP_COLORS.get(sim.powerup, LEVEL_COLORS[lvl - 1]))
		_arena.add_child(bolt)
		return [bolt])
	_sync(_wave_nodes, sim.waves if playing else [], func(_w: Dictionary) -> Array:
		var wave := Fx.make_plasma_ball(0.09)
		Fx.tint_plasma(wave, POWERUP_COLORS["W"])
		_arena.add_child(wave)
		return [wave])
	_sync(_missile_nodes, sim.missiles if playing else [], func(_m: Dictionary) -> Array:
		var missile := Fx.make_plasma_ball(0.03)
		Fx.tint_plasma(missile, POWERUP_COLORS["H"])
		var trail := Fx.Trail.new()
		trail.head_color = Color(0.8, 1.0, 0.4, 0.9)
		trail.tail_color = Color(1.0, 0.5, 0.1, 0.0)
		trail.width = 0.02
		_arena.add_child(missile)
		_arena.add_child(trail)
		return [missile, trail])
	for m in sim.missiles:
		if _missile_nodes.has(m.id):
			(_missile_nodes[m.id][1] as Fx.Trail).update(m.pos, eye)
	_sync(_capsule_nodes, sim.capsules if playing else [], func(c: Dictionary) -> Array:
		var cap := Fx.Capsule.new(c.kind, POWERUP_COLORS[c.kind], Sim.POWERUP_R, c.kind in Sim.PADDLE_KINDS)
		_arena.add_child(cap)
		return [cap])
	# The prompt under the title art blinks.
	_msg_label.modulate.a = 0.55 + 0.45 * sin(_mode_t * 5.0)
	_msg_label.outline_modulate.a = _msg_label.modulate.a


## Keeps one set of nodes per live thing (matched by id) and moves the first
## node of each to the thing's position.
func _sync(nodes: Dictionary, things: Array, make: Callable) -> void:
	var live := {}
	for t in things:
		live[t.id] = true
		if not nodes.has(t.id):
			nodes[t.id] = make.call(t)
		(nodes[t.id][0] as Node3D).position = t.pos
	for id in nodes.keys():
		if not live.has(id):
			for n in nodes[id]:
				(n as Node).queue_free()
			nodes.erase(id)


# --- the world -------------------------------------------------------------------------
func _build_space() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.5, 0.65)
	e.ambient_light_energy = 0.6
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Linear keeps arcade colours saturated.
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		e.glow_enabled = true
		e.glow_intensity = 0.5
		e.glow_bloom = 0.05
		e.glow_hdr_threshold = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	add_child(sun)
	# The Earth, under the corridor: you look down on it through the floor wall
	# and its horizon curves across the view ahead.
	var planet := Fx.Planet.new(PLANET_RADIUS)
	planet.position = Vector3(0, -(PLANET_RADIUS + PLANET_BELOW), -40.0)
	add_child(planet)


## Four energy walls around the play space and one behind the bricks.
func _build_corridor() -> void:
	var h := Sim.HALF
	var z_len := Sim.Z_DRAIN - Sim.Z_BACK
	var zc := (Sim.Z_DRAIN + Sim.Z_BACK) * 0.5
	# side: [size, position, rotation]
	var specs := {
		"l": [Vector2(z_len, h.y * 2.0), Vector3(-h.x, 0, zc), Vector3(0, PI * 0.5, 0)],
		"r": [Vector2(z_len, h.y * 2.0), Vector3(h.x, 0, zc), Vector3(0, -PI * 0.5, 0)],
		"t": [Vector2(h.x * 2.0, z_len), Vector3(0, h.y, zc), Vector3(PI * 0.5, 0, 0)],
		"b": [Vector2(h.x * 2.0, z_len), Vector3(0, -h.y, zc), Vector3(-PI * 0.5, 0, 0)],
		"k": [Vector2(h.x * 2.0, h.y * 2.0), Vector3(0, 0, Sim.Z_BACK), Vector3.ZERO],
	}
	for side in specs:
		var spec: Array = specs[side]
		var m := _field_quad(spec[0], WALL_SHADER)
		m.position = spec[1]
		m.rotation = spec[2]
		var mat := m.material_override as ShaderMaterial
		mat.set_shader_parameter("idle", 0.16 if side != "b" else 0.11)   # the floor a little clearer: the Earth is below
		_arena.add_child(m)
		_walls[side] = {"node": m, "mat": mat, "age": 99.0}
	# The Shield power-up: a green barrier behind the paddle.
	_shield_wall = _field_quad(h * 2.0, WALL_SHADER)
	_shield_wall.position = Vector3(0, 0, Sim.Z_SHIELD)
	var sm := _shield_wall.material_override as ShaderMaterial
	sm.set_shader_parameter("shield_color", POWERUP_COLORS["S"])
	sm.set_shader_parameter("idle", 0.2)
	sm.set_shader_parameter("hex_scale", 14.0)
	_shield_wall.visible = false
	_arena.add_child(_shield_wall)
	_serve_ball = Fx.make_plasma_ball(Sim.BALL_R, Fx.EYE_BALL)
	_serve_ball.visible = false
	_arena.add_child(_serve_ball)


func _field_quad(size: Vector2, shader: Shader) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("size", size)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _flash_wall(side: String, at: Vector3) -> void:
	var w: Dictionary = _walls[side]
	var local := (w.node as Node3D).transform.affine_inverse() * at
	(w.mat as ShaderMaterial).set_shader_parameter("hit", Vector2(local.x, local.y))
	(w.mat as ShaderMaterial).set_shader_parameter("age", 0.0)
	w.age = 0.0


## Tilt Breaker's ship, `width` metres long, drawn with `mat` (ship.gdshader).
func _make_ship(width: float, mat: ShaderMaterial) -> Node3D:
	var scene := load(PADDLE_MODEL) as PackedScene
	if scene == null:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, width * 0.28, width * 0.3)
		box.mesh = bm
		return box
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * (width / MODEL_WIDTH)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if mat.get_shader_parameter("albedo_tex") == null and inst.mesh != null and inst.mesh.get_surface_count() > 0:
			var src := inst.mesh.surface_get_material(0) as BaseMaterial3D
			if src != null:
				_ship_mat.set_shader_parameter("albedo_tex", src.albedo_texture)
				_ghost_mat.set_shader_parameter("albedo_tex", src.albedo_texture)
		inst.material_override = mat
	return model


## The paddles: Tilt Breaker's ship, face on, inside its rectangular energy
## field. Two are built; the second shows in two-paddle mode.
func _build_paddles() -> void:
	_ship_mat = ShaderMaterial.new()
	_ship_mat.shader = SHIP_SHADER
	_ship_mat.set_shader_parameter("eye_group", Fx.EYE_WORLD)
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = SHIP_SHADER
	_ghost_mat.set_shader_parameter("eye_group", Fx.EYE_WORLD)
	_ghost_mat.set_shader_parameter("ghost", 0.9)
	for i in 2:
		var root := Node3D.new()
		_arena.add_child(root)
		var ship := _make_ship(SHIP_WIDTH, _ship_mat)
		ship.position = Vector3(0, 0, 0.02)   # just behind the field
		root.add_child(ship)
		# Sidekicks (K): a mini ship docked at each side.
		var sidekicks: Array = []
		for sx in [-1.0, 1.0]:
			var sk := _make_ship(Sim.SIDEKICK_W * 0.85, _ship_mat)
			sk.position = Vector3(sx * (Sim.PADDLE_HALF.x + Sim.SIDEKICK_W * 0.5), 0, 0.02)
			sk.visible = false
			root.add_child(sk)
			sidekicks.append(sk)
		var field := _field_quad(Sim.PADDLE_HALF * 2.0, FIELD_SHADER)
		var mat := field.material_override as ShaderMaterial
		mat.set_shader_parameter("eye_group", Fx.EYE_WORLD)
		root.add_child(field)
		var glow := Fx.make_plasma_ball(0.05)
		glow.position = Vector3(0, 0, -0.1)
		glow.visible = false
		root.add_child(glow)
		# A soft blue key light so the white hull reads against space.
		var key := OmniLight3D.new()
		key.light_color = Color(0.7, 0.85, 1.0)
		key.omni_range = 0.6
		key.light_energy = 0.8
		key.position = Vector3(0, 0.12, 0.2)
		root.add_child(key)
		_paddles.append({"root": root, "field": field, "mat": mat, "age": 99.0, "flash": 0.0,
			"sidekicks": sidekicks, "glow": glow, "half": Sim.PADDLE_HALF})
	# Lightspeed afterimages: two per paddle at most.
	for i in 4:
		var g := Node3D.new()
		var ship := _make_ship(SHIP_WIDTH, _ghost_mat)
		ship.position = Vector3(0, 0, 0.02)
		g.add_child(ship)
		g.visible = false
		_arena.add_child(g)
		_ghost_nodes.append(g)


## The Ion cannon's beam: a purple shaft that thins away.
func _ion_beam(from: Vector3, to: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = Sim.ION_R * 0.7
	cyl.bottom_radius = Sim.ION_R * 0.7
	cyl.height = from.distance_to(to)
	cyl.radial_segments = 12
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = POWERUP_COLORS["I"] * 2.0
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	m.position = (from + to) * 0.5
	_arena.add_child(m)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(0.05, 1.0, 0.05), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_property(mat, "albedo_color", Color(0, 0, 0, 1), 0.5)
	tw.chain().tween_callback(m.queue_free)


# --- bricks ----------------------------------------------------------------------------
func _brick_glow(b: Dictionary) -> Color:
	if b.metal:
		return Color(0.6, 0.65, 0.7)
	return CIRCUIT_GLOW[LETTER_COLOUR[b.colour]]


func _brick_material(colour: String) -> ShaderMaterial:
	if not _brick_mats.has(colour):
		var size := Sim.BRICK_SIZE
		var m := ShaderMaterial.new()
		m.shader = BRICK_SHADER
		m.set_shader_parameter("circuit", load(TEX % ("circuit_" + colour)))
		m.set_shader_parameter("glow_color", CIRCUIT_GLOW[colour])
		m.set_shader_parameter("brick_size", size)
		m.set_shader_parameter("eye_group", Fx.EYE_WORLD)
		var w := BRICK_TEXELS_W / CIRCUIT_TEXELS
		m.set_shader_parameter("crop_size", Vector2(w, w * size.y / size.x))
		m.set_shader_parameter("brick_texels", Vector2(BRICK_TEXELS_W, roundf(BRICK_TEXELS_W * size.y / size.x)))
		_brick_mats[colour] = m
	return _brick_mats[colour]


## One box per brick. With `fly_in` the walls assemble: each brick arrives from
## deep space, one after another, wall by wall.
func _build_bricks(fly_in: bool) -> void:
	for n in _brick_nodes:
		n.queue_free()
	_brick_nodes.clear()
	if _brick_mesh == null:
		_brick_mesh = BoxMesh.new()
		_brick_mesh.size = Sim.BRICK_SIZE
	for i in sim.bricks.size():
		var b: Dictionary = sim.bricks[i]
		var n := MeshInstance3D.new()
		n.mesh = _brick_mesh
		n.material_override = _brick_material(LETTER_COLOUR[b.colour])
		var at: Vector3 = (b.aabb as AABB).get_center()
		n.position = at
		n.set_instance_shader_parameter("crop_offset",
			Vector2(randi() % int(CIRCUIT_TEXELS), randi() % int(CIRCUIT_TEXELS)) / CIRCUIT_TEXELS)
		# The pulse ripples diagonally across each wall.
		n.set_instance_shader_parameter("phase", -(b.col * 0.55 + b.row * 0.8 + b.layer * 1.3) + float((i * 37) % 11) * 0.08)
		n.set_instance_shader_parameter("mode", 3.0 if b.metal else (4.0 if b.charged else (1.0 if b.armoured else 0.0)))
		if b.plasma:   # its captured plasma ball, on show
			var pb := Fx.make_plasma_ball(Sim.BALL_R * 0.8, Fx.EYE_WORLD)
			pb.position = Vector3(0, 0, Sim.BRICK_SIZE.z * 0.5 + 0.01)
			n.add_child(pb)
		_arena.add_child(n)
		_brick_nodes.append(n)
		if fly_in:
			n.position = at + Vector3(0, 0, -14.0)
			n.scale = Vector3.ONE * 0.05
			var delay: float = b.layer * 0.35 + (b.row * Sim.COLS + b.col) * 0.008
			var tw := n.create_tween().set_parallel(true)
			tw.tween_property(n, "position", at, 0.45).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if i % 9 == 0:
				get_tree().create_timer(delay + 0.4).timeout.connect(_sfx.bind("tb_brick_land", at, -6.0))


func _flash_brick(n: MeshInstance3D) -> void:
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void: n.set_instance_shader_parameter("hit_flash", v), 0.9, 0.0, 0.25)


## A fireball in the brick's colour and shards that fly at the player.
func _explode(pos: Vector3, color: Color, size_scale: float = 1.0, debris: bool = true) -> void:
	var blast := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3) * size_scale
	blast.mesh = quad
	var bm := ShaderMaterial.new()
	bm.shader = EXPLOSION_SHADER
	bm.set_shader_parameter("tint", color)
	blast.material_override = bm
	blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blast.position = pos
	blast.set_instance_shader_parameter("seed", randf() * 100.0)
	_arena.add_child(blast)
	var tw := blast.create_tween()
	tw.tween_method(func(a: float) -> void: blast.set_instance_shader_parameter("age", a), 0.0, 1.0, 0.55)
	tw.tween_callback(blast.queue_free)
	if not debris:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.local_coords = true   # in the arena's space, so it scales with the room
	p.amount = int(12 * size_scale)
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0, 1)
	p.spread = 38.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3.ZERO
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Sim.BRICK_SIZE * 0.4
	p.particle_flag_rotate_y = true
	p.angle_max = 360.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(0.7, 0.9))
	fade.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = fade
	var shard := BoxMesh.new()
	shard.size = Vector3(0.028, 0.012, 0.02)
	p.mesh = shard
	p.material_override = _debris_material(color)
	p.position = pos
	_arena.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.1).timeout.connect(p.queue_free)


func _debris_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _debris_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color.darkened(0.35)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.9
		m.metallic = 0.4
		m.roughness = 0.45
		_debris_mats[key] = m
	return _debris_mats[key]


# --- HUD -------------------------------------------------------------------------------
func _label(text: String, height: float, pos: Vector3, color: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 48
	l.pixel_size = height / 48.0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = pos
	_arena.add_child(l)
	return l


## Score, level and lives float over the far end of the corridor and the two
## power-up slots under it; title art and prompts appear in the middle.
func _build_hud() -> void:
	var y := Sim.HALF.y + 0.16
	_hud_level = _label("", 0.11, Vector3(-Sim.HALF.x + 0.3, y, Sim.Z_BACK), ACCENT)
	_hud_score = _label("", 0.15, Vector3(0, y + 0.02, Sim.Z_BACK))
	_hud_lives = _label("", 0.11, Vector3(Sim.HALF.x - 0.3, y, Sim.Z_BACK), ACCENT)
	_hud_blaster = _label("", 0.1, Vector3(-Sim.HALF.x * 0.5, -Sim.HALF.y - 0.12, Sim.Z_BACK))
	_hud_padup = _label("", 0.1, Vector3(Sim.HALF.x * 0.5, -Sim.HALF.y - 0.12, Sim.Z_BACK))
	_msg_sprite = Sprite3D.new()
	_msg_sprite.shaded = false
	_msg_sprite.position = Vector3(0, 0.12, -1.3)
	_msg_sprite.render_priority = 3
	_arena.add_child(_msg_sprite)
	_msg_label = _label("", 0.07, Vector3(0, -0.22, -1.3), Color(1.0, 0.95, 0.7))
	_msg_sub = _label("", 0.04, Vector3(0, -0.33, -1.3), Color(0.75, 0.9, 1.0))
	for l in [_msg_label, _msg_sub]:
		l.render_priority = 3
		l.outline_render_priority = 2


func _refresh_hud() -> void:
	_hud_score.text = "%06d" % sim.score
	_hud_level.text = "LEVEL %d" % sim.level
	_hud_lives.text = "LIVES %d" % maxi(sim.balls_left, 0)
	_hud_blaster.text = POWERUP_NAMES.get(sim.powerup, "PLASMA CANNON")
	_hud_blaster.modulate = POWERUP_COLORS.get(sim.powerup, Color(0.5, 0.6, 0.7))
	_hud_padup.text = POWERUP_NAMES.get(sim.padup, "")
	_hud_padup.modulate = POWERUP_COLORS.get(sim.padup, Color.WHITE)
	for l in [_hud_score, _hud_level, _hud_lives, _hud_blaster, _hud_padup]:
		l.visible = _mode != "attract"


func _show_message(art: String, text: String, sub: String) -> void:
	var tex: Texture2D = load(TEX % art) if art != "" and ResourceLoader.exists(TEX % art) else null
	_msg_sprite.texture = tex
	_msg_sprite.visible = tex != null
	if tex != null:
		_msg_sprite.pixel_size = 0.9 / tex.get_width()
	_msg_label.text = text
	_msg_label.visible = true
	_msg_sub.text = sub
	_msg_sub.visible = true


func _hide_message() -> void:
	_msg_sprite.visible = false
	_msg_label.visible = false
	_msg_sub.visible = false


func _popup(text: String, at: Vector3, color: Color) -> void:
	var l := _label(text, 0.06, at + Vector3(0, 0.12, -0.05), color)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.25, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.5).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


# --- audio -----------------------------------------------------------------------------
func _build_audio() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -6.0
	_music.bus = &"Music"
	add_child(_music)
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.bus = &"SFX"
		_arena.add_child(p)
		_sfx_pool.append(p)


## Plays a synthesized effect at a place in the corridor (arena space).
func _sfx(sound_name: String, at: Vector3, db: float = 0.0) -> AudioStreamPlayer3D:
	if _sfx_job != null:
		return null   # still being synthesized
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = Synth.make(Sounds.SOUNDS[sound_name])
	p.position = at
	p.volume_db = db
	p.play()
	return p


## Cuts the rising charge whine short (if its player hasn't moved on to another sound).
func _stop_charge_sound() -> void:
	if _charge_player != null and _charge_player.playing and _is_charge_stream(_charge_player.stream):
		_charge_player.stop()
	_charge_player = null


func _is_charge_stream(stream: AudioStream) -> bool:
	for n in ["tb_charge1", "tb_charge2", "tb_charge3"]:
		if stream == Synth.make(Sounds.SOUNDS[n]):
			return true
	return false


func _play_music(path: String) -> void:
	if path == _music_path and _music.playing:
		return
	_music_path = path
	if not ResourceLoader.exists(path):
		_music.stop()
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = path != MUSIC_GAME_OVER
	_music.stream = stream
	_music.play()
