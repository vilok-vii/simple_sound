# Simple Sound

A small sound board for live theater, built with Godot 4.7. Made for a setup with
just a laptop and a speaker.

## Features

- **Projects**: each show gets its own project (a folder). Create, rename and
  delete them in the left sidebar. The last opened project reopens on start.
- **Loops**: background sounds that play on repeat as long as they are in the
  workspace. Each has its own volume slider. Remove it to stop it.
- **SFX**: one-shot sounds with Play/Stop buttons, a volume slider, a progress
  bar and an optional **hotkey**. Click "Set key", then press any key
  (modifiers like Ctrl/Shift work too). Esc cancels, Backspace clears the key.
- **Master volume** slider for the whole app.
- **Stop all SFX**: press **Esc** (or the button) to stop every sound effect.
  Loops keep playing.
- Supports **WAV, OGG and MP3**. You can add files with the buttons, or drag
  them onto the window (left half = loop, right half = SFX).

Sound files are **copied** into the project folder, so the show keeps working
even if the originals get moved or deleted. All settings save automatically.

## Where data is stored

Projects live in the app's user folder under `projects/`:

- Windows: `%APPDATA%\SimpleSound\projects`
- macOS: `~/Library/Application Support/SimpleSound/projects`
- Linux: `~/.local/share/SimpleSound/projects`

The "Open folder" button opens the current project's folder.

## Running and exporting

1. Open `project.godot` in Godot 4.7 and press F5 to run.
2. To make a standalone app for the show laptop: *Project > Export*, add a
   preset for your platform (download the export templates if asked), then export.

## Tips for the show

- Do a sound check at full master volume, then set each sound with its own slider.
- Hotkeys don't fire while you are typing in the project name box. Click
  anywhere else first.
- Switching projects stops all sounds of the previous project.
