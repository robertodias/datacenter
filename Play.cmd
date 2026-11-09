@echo off
cd /d "%~dp0"
if exist "build\Hyperscale Datacenter Tycoon.exe" (
    start "" "build\Hyperscale Datacenter Tycoon.exe"
) else if exist ".tools\godot\Godot_v4.5.1-stable_win64.exe" (
    start "" ".tools\godot\Godot_v4.5.1-stable_win64.exe" --path "%~dp0."
) else (
    echo Open project.godot in Godot 4.5.1 or newer, then press F5.
    pause
)
