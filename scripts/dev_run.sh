#!/usr/bin/env sh
# Test runs that never take focus or show on the desktop: the window starts
# off-screen, silent. Screenshots read the viewport, so they still work.
#   scripts/dev_run.sh --demo --screenshot=<png> --screenshot-delay=8
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/c/Users/Phoenixfox/Dev/Godot/Godot_v4.7.2-stable_win64_console.exe}"
OVERRIDE="$ROOT/override.cfg"
printf '[display]\n\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(-32000, -32000)\n' > "$OVERRIDE"
trap 'rm -f "$OVERRIDE"' EXIT
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --path "$ROOT" --audio-driver Dummy -- "$@"
