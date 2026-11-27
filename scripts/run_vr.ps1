# Runs 3D Blocks in VR. Start your OpenXR runtime first (SteamVR, or Quest
# Link / Air Link with the Meta runtime). Extra arguments go to the game.
# Without a headset it opens the desktop preview.
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '.godot'))) {
    & $godot --headless --path $root --import
}
& $godot --path $root --xr-mode on -- @args
exit $LASTEXITCODE
