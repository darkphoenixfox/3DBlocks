// Corridor energy wall: the Tilt Breaker shield effect on a whole wall. A faint
// hex grid and a bright frame show where the wall is; a hit flashes a core and
// a ripple that spreads from the hit point (in metres on the wall).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shield_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
uniform vec2 size = vec2(1.6, 1.2);   // metres
uniform vec2 hit = vec2(0.0);         // metres from the centre
uniform float age = 99.0;             // seconds since the hit
uniform float idle = 0.1;             // resting glow
uniform float hex_scale = 9.0;        // cells per metre

float hex_edge(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	vec2 q = abs(dot(h.xy, h.xy) < dot(h.zw, h.zw) ? h.xy : h.zw);
	return 0.5 - max(dot(q, s * 0.5), q.x);
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * size;
	float lines = smoothstep(0.07, 0.0, hex_edge(p * hex_scale));
	vec2 e2 = size * 0.5 - abs(p);
	float e = min(e2.x, e2.y);
	float frame = smoothstep(0.02, 0.004, e) + exp(-e * 22.0) * 0.5;
	float d = length(p - hit);
	float strength = clamp(1.0 - age / 0.6, 0.0, 1.0);
	float ripple = pow(max(0.0, 1.0 - abs(d - age * 1.6) * 7.0), 2.0);
	float core = exp(-d * d * 60.0);
	float near = exp(-d * 3.5);
	float a = strength * (1.4 * core + 0.9 * ripple + (0.25 + 0.9 * lines) * near);
	float i = idle * (0.22 * lines + 0.03 + 1.6 * frame);
	ALBEDO = shield_color.rgb * (2.2 * a + i);
	ALPHA = 1.0;
}
