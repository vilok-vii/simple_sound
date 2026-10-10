extends Control
## Simple Sound: a playback board for live theater.
## Projects are folders in user://projects/. Each holds copies of its sound
## files and a project.json describing how they are used.

const PROJECTS_DIR := "user://projects"
const SETTINGS_PATH := "user://settings.json"
const PROJECT_FILE := "project.json"
const PLAYABLE_FORMATS := ["wav", "ogg", "mp3"]
const FORMAT_NAMES := {
	"m4a": "an M4A/AAC file",
	"webm": "a WebM file",
	"flac": "a FLAC file",
	"opus": "an Opus file",
	"mp2": "an MP2 file",
	"aiff": "an AIFF file",
}
const MODIFIER_KEYS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

var settings := {"master_volume": 1.0, "last_project": ""}
var current_project := ""
var tracks: Array = []
var rows: Array[TrackRow] = []
var binding_row: TrackRow = null
var pending_mode := "sfx"

var project_list: ItemList
var project_name_edit: LineEdit
var project_title: Label
var master_label: Label
var workspace: VBoxContainer
var no_project_label: Label
var loop_box: VBoxContainer
var sfx_box: VBoxContainer
var status_label: Label
var file_dialog: FileDialog
var delete_dialog: ConfirmationDialog
var export_dialog: FileDialog
var import_dialog: FileDialog


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PROJECTS_DIR)
	_load_settings()
	_build_ui()
	AudioServer.set_bus_volume_db(0, TrackRow.volume_to_db(float(settings.master_volume)))
	get_window().files_dropped.connect(_on_files_dropped)

	var names := _get_project_names()
	if settings.last_project in names:
		_open_project(settings.last_project)
	elif not names.is_empty():
		_open_project(names[0])
	else:
		_refresh_project_list()
		_update_workspace_visibility()


# --- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode in MODIFIER_KEYS:
		return

	if binding_row:
		_finish_binding(key)
		get_viewport().set_input_as_handled()
		return

	# Don't fire sounds while typing a project name.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return

	if key.keycode == KEY_ESCAPE:
		_stop_all_sfx()
		get_viewport().set_input_as_handled()
		return

	var code := key.get_keycode_with_modifiers()
	for row in rows:
		if row.is_sfx() and row.get_hotkey() == code:
			row.play()
			get_viewport().set_input_as_handled()


func _on_bind_requested(row: TrackRow) -> void:
	if binding_row:
		binding_row.set_binding_mode(false)
	binding_row = row
	row.set_binding_mode(true)
	_set_status("Press a key for \"%s\". Esc cancels, Backspace clears the key." % row.data.name)


func _finish_binding(key: InputEventKey) -> void:
	var row := binding_row
	binding_row = null
	match key.keycode:
		KEY_ESCAPE:
			row.set_binding_mode(false)
			_set_status("Key binding cancelled.")
		KEY_BACKSPACE, KEY_DELETE:
			row.set_hotkey(0)
			_set_status("Key cleared for \"%s\"." % row.data.name)
		_:
			var code := key.get_keycode_with_modifiers()
			# A key triggers one sound only: take it away from any other SFX.
			for other in rows:
				if other != row and other.get_hotkey() == code:
					other.set_hotkey(0)
			row.set_hotkey(code)
			_set_status("\"%s\" is now on key %s." % [row.data.name, OS.get_keycode_string(code)])


func _stop_all_sfx() -> void:
	for row in rows:
		if row.is_sfx():
			row.stop()


# --- Projects -----------------------------------------------------------------

func _get_project_names() -> Array:
	var names := Array(DirAccess.get_directories_at(PROJECTS_DIR))
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return names


func _project_dir(project_name: String = current_project) -> String:
	return PROJECTS_DIR.path_join(project_name)


func _refresh_project_list() -> void:
	project_list.clear()
	for project_name in _get_project_names():
		var idx := project_list.add_item(project_name)
		if project_name == current_project:
			project_list.select(idx)


func _open_project(project_name: String) -> void:
	_clear_workspace()
	current_project = project_name
	var loaded: Variant = _read_json(_project_dir().path_join(PROJECT_FILE))
	tracks = loaded.get("tracks", []) if loaded is Dictionary else []
	for track in tracks:
		_create_row(track)
	settings.last_project = project_name
	_save_settings()
	_refresh_project_list()
	_update_workspace_visibility()
	_set_status("Opened project \"%s\"." % project_name)


func _close_project() -> void:
	_clear_workspace()
	current_project = ""
	tracks = []
	_refresh_project_list()
	_update_workspace_visibility()


func _clear_workspace() -> void:
	binding_row = null
	for row in rows:
		row.stop()
		row.queue_free()
	rows.clear()


func _save_project() -> void:
	if current_project == "":
		return
	_write_json(_project_dir().path_join(PROJECT_FILE), {"tracks": tracks})


func _clean_name(text: String) -> String:
	return text.strip_edges().validate_filename()


func _on_project_selected(index: int) -> void:
	var project_name := project_list.get_item_text(index)
	if project_name != current_project:
		_open_project(project_name)


func _on_new_project() -> void:
	var project_name := _clean_name(project_name_edit.text)
	if project_name == "":
		_set_status("Type a name for the new project first.")
		return
	if DirAccess.dir_exists_absolute(_project_dir(project_name)):
		_set_status("A project called \"%s\" already exists." % project_name)
		return
	DirAccess.make_dir_recursive_absolute(_project_dir(project_name))
	_write_json(_project_dir(project_name).path_join(PROJECT_FILE), {"tracks": []})
	project_name_edit.clear()
	project_name_edit.release_focus()
	_open_project(project_name)


func _on_rename_project() -> void:
	if current_project == "":
		_set_status("Select a project to rename.")
		return
	var new_name := _clean_name(project_name_edit.text)
	if new_name == "":
		_set_status("Type the new name in the box, then press Rename.")
		return
	if DirAccess.dir_exists_absolute(_project_dir(new_name)):
		_set_status("A project called \"%s\" already exists." % new_name)
		return
	var err := DirAccess.rename_absolute(_project_dir(), _project_dir(new_name))
	if err != OK:
		_set_status("Could not rename the project (error %d)." % err)
		return
	_set_status("Renamed \"%s\" to \"%s\"." % [current_project, new_name])
	current_project = new_name
	settings.last_project = new_name
	_save_settings()
	project_name_edit.clear()
	project_name_edit.release_focus()
	_refresh_project_list()
	_update_workspace_visibility()


func _on_delete_project() -> void:
	if current_project == "":
		_set_status("Select a project to delete.")
		return
	delete_dialog.dialog_text = "Delete project \"%s\" and all its sound copies?\nThis cannot be undone." % current_project
	delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var deleted := current_project
	_close_project()
	_remove_dir_recursive(_project_dir(deleted))
	var names := _get_project_names()
	if not names.is_empty():
		_open_project(names[0])
	_set_status("Deleted project \"%s\"." % deleted)


func _on_open_folder() -> void:
	var path := _project_dir() if current_project != "" else PROJECTS_DIR
	OS.shell_open(ProjectSettings.globalize_path(path))


# --- Sounds -------------------------------------------------------------------

func _open_file_dialog(mode: String) -> void:
	pending_mode = mode
	file_dialog.title = "Add loop sounds" if mode == "loop" else "Add sound effects"
	file_dialog.popup_centered_ratio(0.7)


func _on_files_selected(paths: PackedStringArray) -> void:
	_add_files(paths, pending_mode)


func _on_files_dropped(paths: PackedStringArray) -> void:
	# Dropping files on the left half adds loops, on the right half adds SFX.
	var mode := "loop" if get_global_mouse_position().x < loop_box.get_global_rect().end.x else "sfx"
	_add_files(paths, mode)


func _add_files(paths: PackedStringArray, mode: String) -> void:
	if current_project == "":
		_set_status("Create or select a project before adding sounds.")
		return
	var added := 0
	var problems: Array[String] = []
	for src in paths:
		var format := _detect_format(src)
		if not format in PLAYABLE_FORMATS:
			problems.append(_unplayable_message(src.get_file(), format))
			continue
		var file_name := _unique_file_name(src.get_file())
		var dst := _project_dir().path_join(file_name)
		var err := DirAccess.copy_absolute(src, ProjectSettings.globalize_path(dst))
		if err != OK:
			problems.append("Could not copy \"%s\" (error %d)." % [src.get_file(), err])
			continue
		if _load_stream(dst, false) == null:
			DirAccess.remove_absolute(dst)
			problems.append(_unplayable_message(src.get_file(), ""))
			continue
		var track := {
			"file": file_name,
			"name": src.get_file().get_basename(),
			"mode": mode,
			"volume": 1.0,
			"key": 0,
		}
		tracks.append(track)
		_create_row(track)
		added += 1
	if added > 0:
		_save_project()
		problems.push_front("Added %d %s." % [added, "loop(s)" if mode == "loop" else "sound effect(s)"])
	_set_status("  ".join(problems))


func _unplayable_message(file_name: String, format: String) -> String:
	if format in FORMAT_NAMES:
		return ("\"%s\" can't be played: it is really %s, which this app can't read. "
				+ "Convert it to MP3, WAV or OGG (for example with Audacity) and add it again.") % [file_name, FORMAT_NAMES[format]]
	return ("\"%s\" can't be played: it is not a WAV, OGG or MP3 file the app can read. "
			+ "Convert it to MP3, WAV or OGG (for example with Audacity) and add it again.") % file_name


## Works out the audio format from the file's contents, since downloaded files
## often have the wrong extension (e.g. an M4A saved as .mp3).
static func _detect_format(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var head := file.get_buffer(64)
	if head.size() < 12:
		return ""
	var tag := head.slice(0, 4).get_string_from_ascii()
	if tag == "RIFF" and head.slice(8, 12).get_string_from_ascii() == "WAVE":
		return "wav"
	if tag == "OggS":
		return "opus" if head.slice(28, 36).get_string_from_ascii() == "OpusHead" else "ogg"
	if tag == "fLaC":
		return "flac"
	if tag == "FORM":
		return "aiff"
	if head.slice(4, 8).get_string_from_ascii() == "ftyp":
		return "m4a"
	if head[0] == 0x1A and head[1] == 0x45 and head[2] == 0xDF and head[3] == 0xA3:
		return "webm"
	if head.slice(0, 3).get_string_from_ascii() == "ID3":
		return "mp3"
	if head[0] == 0xFF and (head[1] & 0xE0) == 0xE0:
		match (head[1] >> 1) & 0x03:
			0x01:
				return "mp3"
			0x02, 0x03:
				return "mp2"
			_:
				return "m4a" # ADTS AAC stream
	return ""


func _unique_file_name(file_name: String) -> String:
	var base := file_name.get_basename()
	var ext := file_name.get_extension()
	var candidate := file_name
	var n := 2
	while FileAccess.file_exists(_project_dir().path_join(candidate)):
		candidate = "%s (%d).%s" % [base, n, ext]
		n += 1
	return candidate


func _create_row(track: Dictionary) -> void:
	var loop: bool = track.get("mode", "sfx") == "loop"
	var stream := _load_stream(_project_dir().path_join(str(track.get("file", ""))), loop)
	var row := TrackRow.new()
	(loop_box if loop else sfx_box).add_child(row)
	row.setup(track, stream)
	row.changed.connect(_save_project)
	row.remove_requested.connect(_on_remove_track)
	row.bind_requested.connect(_on_bind_requested)
	row.rename_requested.connect(_on_rename_track)
	rows.append(row)


func _on_remove_track(row: TrackRow) -> void:
	if binding_row == row:
		binding_row = null
	row.stop()
	rows.erase(row)
	tracks.erase(row.data)
	DirAccess.remove_absolute(_project_dir().path_join(str(row.data.get("file", ""))))
	row.queue_free()
	_save_project()
	_set_status("Removed \"%s\"." % row.data.get("name", ""))


func _on_rename_track(row: TrackRow, new_name: String) -> void:
	var old_file := str(row.data.get("file", ""))
	var ext := old_file.get_extension()
	var new_file := (new_name.validate_filename() + "." + ext) if ext != "" else new_name.validate_filename()
	if new_file != old_file:
		new_file = _unique_file_name(new_file)
		var err := DirAccess.rename_absolute(_project_dir().path_join(old_file), _project_dir().path_join(new_file))
		if err == OK:
			row.data["file"] = new_file
		else:
			_set_status("Renamed the sound, but could not rename its file (error %d)." % err)
	row.data["name"] = new_name
	row.update_name()
	_save_project()
	_set_status("Renamed sound to \"%s\"." % new_name)


static func _load_stream(path: String, loop: bool) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	path = ProjectSettings.globalize_path(path)
	match _detect_format(path):
		"wav":
			var wav := AudioStreamWAV.load_from_file(path)
			if wav and loop:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
			return wav
		"ogg":
			var ogg := AudioStreamOggVorbis.load_from_file(path)
			if ogg:
				ogg.loop = loop
			return ogg
		"mp3":
			var mp3 := AudioStreamMP3.load_from_file(path)
			if mp3:
				mp3.loop = loop
			return mp3
	return null


# --- Export / import ----------------------------------------------------------

func _on_export_project() -> void:
	if current_project == "":
		_set_status("Select a project to export.")
		return
	export_dialog.current_file = current_project + ".zip"
	export_dialog.popup_centered_ratio(0.7)


func _on_export_path_selected(path: String) -> void:
	if path.get_extension().to_lower() != "zip":
		path += ".zip"
	var zip := ZIPPacker.new()
	var err := zip.open(path)
	if err != OK:
		_set_status("Could not create \"%s\" (error %d)." % [path.get_file(), err])
		return
	var files := [PROJECT_FILE]
	for track in tracks:
		var file_name := str(track.get("file", ""))
		if file_name != "" and FileAccess.file_exists(_project_dir().path_join(file_name)):
			files.append(file_name)
	for file_name in files:
		zip.start_file(file_name)
		zip.write_file(FileAccess.get_file_as_bytes(_project_dir().path_join(file_name)))
		zip.close_file()
	zip.close()
	_set_status("Exported \"%s\" with %d sound(s) to %s" % [current_project, files.size() - 1, path])


func _on_import_project() -> void:
	import_dialog.popup_centered_ratio(0.7)


func _on_import_path_selected(path: String) -> void:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		_set_status("Could not open \"%s\"." % path.get_file())
		return
	var entries := zip.get_files()
	if not PROJECT_FILE in entries:
		zip.close()
		_set_status("\"%s\" is not a Simple Sound export (no %s inside)." % [path.get_file(), PROJECT_FILE])
		return

	var base_name := _clean_name(path.get_file().get_basename())
	if base_name == "":
		base_name = "Imported project"
	var project_name := base_name
	var n := 2
	while DirAccess.dir_exists_absolute(_project_dir(project_name)):
		project_name = "%s (%d)" % [base_name, n]
		n += 1

	var dir := _project_dir(project_name)
	DirAccess.make_dir_recursive_absolute(dir)
	for entry in entries:
		# Only take plain files from the top of the zip; ignore folders and odd paths.
		if entry.ends_with("/") or entry.get_file() != entry or entry.validate_filename() != entry:
			continue
		var file := FileAccess.open(dir.path_join(entry), FileAccess.WRITE)
		if file:
			file.store_buffer(zip.read_file(entry))
	zip.close()
	_open_project(project_name)
	_set_status("Imported \"%s\"." % project_name)


# --- Master volume & settings -------------------------------------------------

func _on_master_changed(value: float) -> void:
	settings.master_volume = value
	AudioServer.set_bus_volume_db(0, TrackRow.volume_to_db(value))
	master_label.text = "%d%%" % roundi(value * 100.0)
	_save_settings()


func _load_settings() -> void:
	var loaded: Variant = _read_json(SETTINGS_PATH)
	if loaded is Dictionary:
		settings.merge(loaded, true)


func _save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


# --- Helpers ------------------------------------------------------------------

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Could not save %s (error %d)." % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(value, "\t"))


func _remove_dir_recursive(path: String) -> void:
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name in DirAccess.get_directories_at(path):
		_remove_dir_recursive(path.path_join(dir_name))
	DirAccess.remove_absolute(path)


func _set_status(text: String) -> void:
	status_label.text = text


func _update_workspace_visibility() -> void:
	var has_project := current_project != ""
	workspace.visible = has_project
	no_project_label.visible = not has_project
	project_title.text = current_project if has_project else "No project"


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 18
	theme = ui_theme

	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	background.add_child(margin)

	var split := HSplitContainer.new()
	margin.add_child(split)

	# Sidebar: projects.
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 250
	split.add_child(sidebar)
	sidebar.add_child(_make_label("Projects", 22))

	project_list = ItemList.new()
	project_list.size_flags_vertical = SIZE_EXPAND_FILL
	project_list.focus_mode = FOCUS_NONE
	project_list.item_selected.connect(_on_project_selected)
	sidebar.add_child(project_list)

	project_name_edit = LineEdit.new()
	project_name_edit.placeholder_text = "Project name"
	project_name_edit.text_submitted.connect(func(_text: String) -> void: _on_new_project())
	sidebar.add_child(project_name_edit)

	var project_buttons := HBoxContainer.new()
	sidebar.add_child(project_buttons)
	for entry in [["New", _on_new_project], ["Rename", _on_rename_project], ["Delete", _on_delete_project]]:
		var button := _make_button(entry[0], entry[1])
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		project_buttons.add_child(button)
	var share_buttons := HBoxContainer.new()
	sidebar.add_child(share_buttons)
	for entry in [["Export...", _on_export_project], ["Import...", _on_import_project]]:
		var button := _make_button(entry[0], entry[1])
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		share_buttons.add_child(button)
	sidebar.add_child(_make_button("Open folder", _on_open_folder))

	# Main area.
	var main := VBoxContainer.new()
	main.size_flags_horizontal = SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	split.add_child(main)

	var top := HBoxContainer.new()
	main.add_child(top)
	project_title = _make_label("No project", 26)
	project_title.size_flags_horizontal = SIZE_EXPAND_FILL
	project_title.clip_text = true
	top.add_child(project_title)
	top.add_child(_make_label("Master", 20))

	var master_slider := HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.01
	master_slider.custom_minimum_size.x = 300
	master_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	master_slider.focus_mode = FOCUS_NONE
	master_slider.value = float(settings.master_volume)
	master_slider.value_changed.connect(_on_master_changed)
	top.add_child(master_slider)

	master_label = _make_label("%d%%" % roundi(float(settings.master_volume) * 100.0), 20)
	master_label.custom_minimum_size.x = 64
	master_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(master_label)

	no_project_label = _make_label("Create a project on the left to get started.", 20)
	no_project_label.size_flags_vertical = SIZE_EXPAND_FILL
	no_project_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_project_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main.add_child(no_project_label)

	workspace = VBoxContainer.new()
	workspace.size_flags_vertical = SIZE_EXPAND_FILL
	main.add_child(workspace)

	var actions := HBoxContainer.new()
	workspace.add_child(actions)
	actions.add_child(_make_button("+ Add Loop...", func() -> void: _open_file_dialog("loop")))
	actions.add_child(_make_button("+ Add SFX...", func() -> void: _open_file_dialog("sfx")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(spacer)
	actions.add_child(_make_button("Stop all SFX (Esc)", _stop_all_sfx))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	workspace.add_child(columns)
	loop_box = _make_column(columns, "Loops")
	sfx_box = _make_column(columns, "Sound effects")

	status_label = _make_label("", 16)
	status_label.modulate = Color(1, 1, 1, 0.75)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(status_label)

	# Dialogs.
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.wav, *.ogg, *.mp3 ; Audio files"])
	file_dialog.use_native_dialog = true
	file_dialog.files_selected.connect(_on_files_selected)
	add_child(file_dialog)

	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Delete project"
	delete_dialog.ok_button_text = "Delete"
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_dialog)

	export_dialog = FileDialog.new()
	export_dialog.title = "Export project"
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.filters = PackedStringArray(["*.zip ; Simple Sound export"])
	export_dialog.use_native_dialog = true
	export_dialog.file_selected.connect(_on_export_path_selected)
	add_child(export_dialog)

	import_dialog = FileDialog.new()
	import_dialog.title = "Import project"
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.filters = PackedStringArray(["*.zip ; Simple Sound export"])
	import_dialog.use_native_dialog = true
	import_dialog.file_selected.connect(_on_import_path_selected)
	add_child(import_dialog)


func _make_column(parent: Control, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(column)
	column.add_child(_make_label(title, 20))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


func _make_label(text: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(callback)
	return button
