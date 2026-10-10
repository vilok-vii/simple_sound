# Simple Sound

A sound board for live theater (just a laptop and a speaker), built with Godot 4.7.

## Workflow

- You may always open a pull request for your changes, and merge it yourself
  when the change is tested and working. Ask first if something is unclear or
  would change how the app is used.

## Code

- GDScript in `scripts/`: `main.gd` (projects, file loading, hotkeys, master
  volume, export/import) and `track_row.gd` (one loop or SFX row).
- The UI is built in code; `main.tscn` only holds the root Control.
- Indent with tabs, never spaces.
- Projects are folders in `user://projects/` with a `project.json` and copies of
  their sound files. Keep the export/import zip format in sync with `project.json`.

## Testing

- Run Godot 4.7 headless (`--headless --script <test.gd>`) to check scripts load
  and to exercise features from a test script.
