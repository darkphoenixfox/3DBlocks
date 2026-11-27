// Tilt Breaker brick, for a brick seen from every side: each face shows a
// rectangle cut from the director's 16-bit circuit texture (512 px, nearest
// filtering = chunky pixels). crop_offset (per brick) picks where it is cut.
// The glow mask comes from the texture itself: bright, saturated pixels
// (LEDs, lit traces) pulse - the nanomachine swarm is alive.
shader_type spatial;
render_mode specular_schlick_ggx;
#include "res://shaders/eye.gdshaderinc"

uniform sampler2D circuit : source_color, filter_nearest, repeat_enable;
uniform vec3 brick_size = vec3(0.135, 0.075, 0.12);
uniform vec2 crop_size = vec2(0.125, 0.06);
uniform vec2 brick_texels = vec2(64.0, 36.0);  // texels across the front face
uniform vec4 glow_color : source_color = vec4(0.25, 0.8, 1.0, 1.0);
uniform float glow_strength = 1.8;
uniform float pulse_speed = 2.6;
instance uniform vec2 crop_offset = vec2(0.0);
instance uniform float phase = 0.0;
instance uniform float hit_flash = 0.0;
// 0 normal, 1 armoured (2 hits), 2 cracked (hit once), 3 metal, 4 charged
instance uniform float mode = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	if (eye_hidden(VIEW_INDEX)) {
		discard;
	}
	vec3 an = abs(local_normal);
	vec2 uv;
	float is_front = 0.0;
	if (an.z >= an.x && an.z >= an.y) {
		uv = vec2(local_pos.x / brick_size.x, -local_pos.y / brick_size.y) + 0.5;
		is_front = 1.0;
	} else if (an.x >= an.y) {
		uv = vec2(local_pos.z / brick_size.z, -local_pos.y / brick_size.y) + 0.5;
	} else {
		uv = vec2(local_pos.x / brick_size.x, local_pos.z / brick_size.z) + 0.5;
	}
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec3 t = texture(circuit, crop_offset + uv * crop_size).rgb;
	// 16-bit bevel, 1 texel wide: light top/left, dark bottom/right.
	vec2 tx = floor(uv * brick_texels);
	float light = max(step(tx.x, 0.0), step(tx.y, 0.0));
	float dark = max(step(brick_texels.x - 1.0, tx.x), step(brick_texels.y - 1.0, tx.y));
	vec3 face = mix(t, t * 0.35, dark);
	face = mix(face, mix(t, glow_color.rgb, 0.35) * 1.4, light * (1.0 - dark));
	float border2 = max(max(step(tx.x, 1.0), step(tx.y, 1.0)),
		max(step(brick_texels.x - 2.0, tx.x), step(brick_texels.y - 2.0, tx.y)));
	if (mode > 3.5) {
		face = mix(face, vec3(1.0, 0.18, 0.1) * 1.3, border2 * 0.9);
	} else if (mode > 2.5) {
		float lum = dot(t, vec3(0.3, 0.59, 0.11));
		face = vec3(0.32, 0.35, 0.4) * (0.6 + 0.8 * lum) + vec3(0.25) * border2;
		float rivet = step(length(mod(tx, vec2(8.0)) - 4.0), 1.0);
		face += vec3(0.25) * rivet * (1.0 - border2);
	} else if (mode > 0.5) {
		face = mix(face, glow_color.rgb * 1.2, border2 * 0.85);
		if (mode > 1.5) {
			float crack = step(abs(fract((tx.x * 0.9 + tx.y * 1.7) / 11.0) - 0.5), 0.045)
				+ step(abs(fract((tx.x * 1.3 - tx.y * 2.1) / 13.0) - 0.5), 0.04);
			face = mix(face * 0.65, vec3(0.02), clamp(crack, 0.0, 1.0));
		}
	}
	float side = mix(0.6, 1.0, is_front);
	ALBEDO = face * side;
	float hi = max(t.r, max(t.g, t.b));
	float lo = min(t.r, min(t.g, t.b));
	float mask = smoothstep(0.45, 0.8, hi) * smoothstep(0.2, 0.45, hi - lo);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + phase);
	float alive_glow = (mode > 2.5 && mode < 3.5) ? 0.0 : 1.0;
	EMISSION = (t * 0.5 + glow_color.rgb * 0.5) * mask * (0.5 + 1.3 * pulse) * glow_strength * side * alive_glow
		+ glow_color.rgb * border2 * (mode > 0.5 && mode < 1.5 ? 0.6 : 0.0)
		+ vec3(1.0, 0.12, 0.06) * border2 * (mode > 3.5 ? 0.9 + 0.8 * sin(TIME * 6.0 + phase) : 0.0)
		+ vec3(hit_flash);
	ROUGHNESS = 0.6;
	SPECULAR = 0.2;
	METALLIC = 0.1;
}
