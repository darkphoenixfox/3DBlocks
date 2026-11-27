// The paddle ship (and its sidekicks): the model's own texture, lit, with the
// eye training switch. `ghost` > 0 draws it as a Lightspeed afterimage instead:
// a see-through blue echo.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/eye.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ghost = 0.0;
uniform float flash = 0.0;   // yellow recharge flash

void fragment() {
	if (eye_hidden(VIEW_INDEX)) {
		discard;
	}
	vec3 t = texture(albedo_tex, UV).rgb * tint.rgb;
	if (ghost > 0.0) {
		// Dithered so it needs no blending: every other pixel, in blue.
		if (mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 0.5) {
			discard;
		}
		ALBEDO = vec3(0.0);
		EMISSION = mix(t, vec3(0.3, 0.6, 1.0), 0.6) * ghost;
	} else {
		ALBEDO = t;
		EMISSION = vec3(1.0, 0.85, 0.2) * flash;
		ROUGHNESS = 0.6;
		METALLIC = 0.2;
	}
}
