# Simple Sound

A small sound board for live theater, built with Godot 4.7. Made for a setup with
just a laptop and a speaker.

## Features

Each sound has a **menu button** (three vertical dots) in its top-right
corner; **right-clicking** the sound opens the same menu. **Double-click a
name** to rename it (Enter saves, Esc cancels), and **drag sounds** to change
their order.

- **Projects**: each show gets its own project (a folder) in the left sidebar.
  The menu button next to "Projects" creates or imports a project.
  Right-click a project to open, rename, export, open its folder or delete it.
  The last opened project reopens on start.
- **Loops**: background sounds that play on repeat as long as they are in the
  workspace. Each has its own volume slider. The menu has Rename, Convert to SFX and Remove.
- **SFX**: each sound effect is a tile with a big play button, its name, a
  progress bar and a volume slider. Click to play; clicking again while it
  plays layers another copy on top instead of restarting. The menu has Play,
  Stop, Set/Clear hotkey, Rename, Convert to loop and Remove. For a hotkey, choose
  "Set hotkey...", then press any key (modifiers like Ctrl/Shift work too).
  Esc cancels, Backspace clears the key. The key shows in the tile's corner.
- **Reordering**: drag a loop or SFX tile and drop it where you want it.
  Loops and SFX stay in their own column.
- **Converting** turns a loop into an SFX or the other way round. It moves to
  the end of the other column and keeps its name, volume and hotkey.
- **Renaming** a sound also renames its copied file to match.
- **Export / import**: "Export..." saves a project (settings and all its
  sounds) as one `.zip` file. Copy it to another computer running Simple Sound
  and use "Import..." to load it as a project there.
- **Master volume** slider for the whole app.
- **Stop all SFX** button stops every sound effect, including layered copies.
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

Right-click a project and choose "Open folder" to open it.

## Running and exporting

1. Open `project.godot` in Godot 4.7 and press F5 to run.
2. To make a standalone app for the show laptop: *Project > Export*, add a
   preset for your platform (download the export templates if asked), then export.

## Tips for the show

- Do a sound check at full master volume, then set each sound with its own slider.
- Hotkeys don't fire while you are typing in the project name box. Click
  anywhere else first.
- Switching projects stops all sounds of the previous project.
