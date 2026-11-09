# Standalone demo quick start

Extract the ZIP to a normal writable folder. Run `Hyperscale Datacenter Tycoon.exe`.
No installer, engine, account or internet connection is required. This is an unsigned
development executable; verify that it is the copy supplied by the project owner.

Choose **New Company → Littlebrook → Standard**, keep the guided introduction on,
and follow the highlighted controls. Buy and clear warehouse 04-06, build a hall,
then add a substation on 03-06 and cooling on 04-07. Run time, review the first
contracts and leave room for utility failures. The help button explains all systems.

Use F11 or Alt+Enter to enter and leave fullscreen. Escape first closes an open
panel, then exits fullscreen or opens the pause menu. Space pauses; F4 changes speed.
The game begins new and loaded towns paused. Settings include text size, display
mode, independent music/ambience, reduced motion and remappable core controls.

## Save and update
Use Save for a named slot or F5 for quicksave. There are also three rotating autosaves
and scenario checkpoints. The application data directory intentionally retains the
earlier project name: `%APPDATA%\Datacenter Tycoons`. Your towns are in `saves`.

Before an update, save and close the game, then back up that application-data folder.
Extract the new release into a separate folder and run its executable. Saves remain
in the shared user directory; replacing a build folder does not delete them. Load an
existing slot or select Continue. Version 1.2.0 reads save schemas 1–12, including the
1.2 previews. Older executables cannot read new schema-12 saves; keep the backup if
you may return to an older build. Never keep two game versions writing the same saves.

If a slot is damaged, use the load browser's previous-good recovery option. Failed
loads leave the current town intact. Do not delete the whole application-data folder
to resolve a display problem: with the game closed, rename `settings.cfg` to retain
it as a backup, then relaunch with default settings. This does not remove towns.

## Reporting a problem
Include the build version, what you clicked, expected/actual behavior, display
resolution/text scale and whether it happened after loading a save. Attach a copy of
the relevant slot if possible, preserving your original. State whether the problem
reproduces in a fresh town. Do not send unrelated personal files.

Godot logs are under the application-data folder's `logs` directory. To capture a
specific session from PowerShell in the extracted release folder:

```powershell
& '.\Hyperscale Datacenter Tycoon.exe' --log-file "$env:TEMP\Hyperscale-playtest.log"
```

## Demo boundaries
Three towns and sandbox are playable offline. Achievements are local to each saved
company. Steam Achievements, Steam Cloud and store publication are not enabled.
English and Windows x64 are the verified release targets. Lower-spec hardware and
another physical monitor need testing; screenshots at other viewport sizes do not
substitute for testing those devices.
