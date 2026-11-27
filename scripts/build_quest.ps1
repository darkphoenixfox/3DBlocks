# Builds the Quest APK: OpenXR via the Godot OpenXR Vendors plugin (Meta
# loader), Gradle build, arm64, debug-signed for sideloading.
# Needs Godot 4.7.2 Android export templates, and the Android SDK + JDK 17
# set in Godot's editor settings (the same setup as PinGames).
# Output: exports\3DBlocks-quest.apk   Install: adb install -r exports\3DBlocks-quest.apk
$ErrorActionPreference = 'Stop'
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = 'C:\Users\Phoenixfox\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe' }
$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force (Join-Path $root 'exports') | Out-Null
& $godot --headless --path $root --import
$extra = @()
if (-not (Test-Path (Join-Path $root 'android\build'))) { $extra += '--install-android-build-template' }
& $godot --headless --path $root @extra --export-debug "Quest" (Join-Path $root 'exports\3DBlocks-quest.apk')
exit $LASTEXITCODE
