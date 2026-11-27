// A plain glowing colour (the plasma ball's core), with the eye training switch.
shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "res://shaders/eye.gdshaderinc"

uniform vec4 color : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform float energy = 3.0;

void fragment() {
	if (eye_hidden(VIEW_INDEX)) {
		discard;
	}
	ALBEDO = color.rgb * energy;
}
