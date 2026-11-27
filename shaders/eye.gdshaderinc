// Eye training mode: things in the "ball" group are drawn in one eye only and
// things in the "world" group (paddles, bricks) in the other. The game sets the
// two globals to the eye (0 left, 1 right) each group shows in, or -1 for both.
// A material picks its group with eye_group: 0 none (both eyes), 1 ball, 2 world.
// Without a headset there is one view, index 0: the left eye's picture.
global uniform int eye_ball;
global uniform int eye_world;
uniform int eye_group = 0;

bool eye_hidden(int view) {
	int eye = eye_group == 1 ? eye_ball : (eye_group == 2 ? eye_world : -1);
	return eye >= 0 && view != eye;
}
