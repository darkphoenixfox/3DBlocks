// The plasma ball's ribbon trail: additive, coloured per vertex, with the eye
// training switch.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/eye.gdshaderinc"

void fragment() {
	if (eye_hidden(VIEW_INDEX)) {
		discard;
	}
	ALBEDO = COLOR.rgb * COLOR.a;
	ALPHA = 1.0;
}
