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
- **Rename sounds**: click "Rename" (or double-click a sound's name), type the
  new name and press Enter. Esc cancels. The copied file is renamed to match.
- **Export / import**: "Export..." saves the current project (settings and all
  its sounds) as one `.zip` file. Copy it to another computer running Simple
  Sound and use "Import..." to load it as a project there.
- **Master volume** slider for the whole app.
- **Stop all SFX**: press **Esc** (or the button) to stop every sound effect.
  Loops keep playing.
- Supports **WAV, OGG (Vorbis) and MP3**. The app checks what is inside a file,
  not just its extension: files that are really M4A/AAC, Opus, FLAC or similar
  (common for "YouTube to MP3" downloads) are refused with a message explaining
  why. Convert them to MP3, WAV or OGG, for example with Audacity.
- Add files with the buttons, or drag them onto the window (left half = loop,
  right half = SFX).

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
