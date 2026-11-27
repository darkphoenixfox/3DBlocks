// The paddle's energy field: a rectangle of force around the ship. A bright
// frame with corner brackets, a faint hex fill with a slow sweep, a ripple
// where the plasma lands, and the blast power bar (3 cells) along the bottom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/eye.gdshaderinc"

uniform vec4 field_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
uniform vec4 bar_color : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform vec2 size = vec2(0.4, 0.26);  // metres
uniform vec2 hit = vec2(0.0);
uniform float age = 99.0;
uniform float power = 1.0;            // 0..1
uniform float flash = 0.0;            // whole-field flash (power-up caught)

float hex_edge(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	vec2 q = abs(dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw);
	return 0.5 - max(dot(q, s * 0.5), q.x);
}

void fragment() {
	if (eye_hidden(VIEW_INDEX)) {
		discard;
	}
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * size;
	vec2 e2 = size * 0.5 - abs(p);
	float e = min(e2.x, e2.y);
	float frame = smoothstep(0.007, 0.003, e);
	float bracket = smoothstep(0.014, 0.008, e) * step(max(e2.x, e2.y), 0.05);
	float inner = exp(-e * 55.0) * 0.45;
	float lines = smoothstep(0.08, 0.0, hex_edge(p * 60.0));
	float sweep = 0.5 + 0.5 * sin(p.y * 40.0 - TIME * 3.0);
	float fill = 0.05 + lines * (0.10 + 0.08 * sweep);
	float d = length(p - hit);
	float strength = clamp(1.0 - age / 0.45, 0.0, 1.0);
	float ripple = pow(max(0.0, 1.0 - abs(d - age * 0.9) * 22.0), 2.0);
	float core = exp(-d * d * 500.0);
	float a = fill + frame * 1.5 + bracket * 1.5 + inner
		+ strength * (1.6 * core + 1.2 * ripple + 0.7 * lines + 0.2) + flash;
	vec3 col = field_color.rgb * a;
	// Power bar: three cells just inside the bottom edge.
	float bx = (p.x / (size.x * 0.5 - 0.03)) * 0.5 + 0.5;
	float by = p.y + size.y * 0.5;
	if (bx > 0.0 && bx < 1.0 && by > 0.014 && by < 0.024) {
		float cell = floor(bx * 3.0);
		float f = fract(bx * 3.0);
		float gap = step(0.06, f) * step(f, 0.94);
		float lit = clamp(power * 3.0 - cell, 0.0, 1.0);
		float full = step(0.999, lit);
		col += bar_color.rgb * gap * (0.12 + step(f, 0.06 + 0.88 * lit) * (0.7 + 1.3 * full));
	}
	ALBEDO = col;
	ALPHA = 1.0;
}
