## The options, kept in user://settings.cfg.
extends RefCounted

const PATH := "user://settings.cfg"
const SPEEDS := ["slow", "normal", "fast"]
const ROOMS := [0.75, 1.0, 1.25, 1.5]            # the corridor's scale
const ROOM_NAMES := ["SMALL", "NORMAL", "LARGE", "HUGE"]
const DEFAULTS := {
	"speed": 1,        # index into SPEEDS
	"lives": 3,        # 1..5
	"room": 1,         # index into ROOMS
	"paddles": 1,      # 1 or 2
	"eye": false,      # eye training mode
	"music": 0.7,      # 0..1
	"sfx": 0.8,        # 0..1
}

var values := DEFAULTS.duplicate()


func load_file() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in DEFAULTS:
		if cf.has_section_key("options", k):
			var v: Variant = cf.get_value("options", k)
			if typeof(v) == typeof(DEFAULTS[k]):
				values[k] = v
	values["speed"] = clampi(values["speed"], 0, SPEEDS.size() - 1)
	values["lives"] = clampi(values["lives"], 1, 5)
	values["room"] = clampi(values["room"], 0, ROOMS.size() - 1)
	values["paddles"] = clampi(values["paddles"], 1, 2)
	values["music"] = clampf(values["music"], 0.0, 1.0)
	values["sfx"] = clampf(values["sfx"], 0.0, 1.0)


func save_file() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("options", k, values[k])
	cf.save(PATH)


func speed_name() -> String:
	return SPEEDS[values["speed"]]


func room_scale() -> float:
	return ROOMS[values["room"]]
