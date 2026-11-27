// The Tilt Breaker pixel starfield as a sky: three layers of square stars on a
// cube grid around the player, with a gentle per-star twinkle.
shader_type sky;

uniform vec3 space_color : source_color = vec3(0.008, 0.01, 0.025);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(17.3, 51.9)));
}

vec3 star_layer(vec3 dir, float cells, float size, float density, vec3 tint, float seed) {
	vec3 a = abs(dir);
	vec2 uv;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = dir.yz / a.x;
		face = dir.x > 0.0 ? 0.0 : 1.0;
	} else if (a.y >= a.z) {
		uv = dir.xz / a.y;
		face = dir.y > 0.0 ? 2.0 : 3.0;
	} else {
		uv = dir.xy / a.z;
		face = dir.z > 0.0 ? 4.0 : 5.0;
	}
	vec2 g = (uv * 0.5 + 0.5) * cells;
	vec2 id = floor(g) + seed + face * 131.0;
	if (hash(id) > density) {
		return vec3(0.0);
	}
	vec2 pos = 0.2 + 0.6 * hash2(id);
	vec2 off = abs(fract(g) - pos);
	float sz = size * (hash(id + 3.1) > 0.85 ? 2.0 : 1.0);
	float on = step(max(off.x, off.y), sz * 0.5);
	float tw = 0.65 + 0.35 * sin(TIME * (1.5 + hash(id + 7.7) * 3.0) + hash(id) * 6.28);
	return tint * on * tw * (0.6 + 0.6 * hash(id + 9.2));
}

void sky() {
	vec3 col = space_color;
	col += star_layer(EYEDIR, 110.0, 0.10, 0.28, vec3(0.35, 0.4, 0.55), 0.0);
	col += star_layer(EYEDIR, 60.0, 0.07, 0.22, vec3(0.6, 0.65, 0.8), 31.0);
	col += star_layer(EYEDIR, 32.0, 0.05, 0.2, vec3(0.9, 0.88, 0.8), 73.0);
	COLOR = col;
}
