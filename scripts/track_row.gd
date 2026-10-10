class_name TrackRow
extends PanelContainer
## One sound in the workspace. A loop is a row with a volume slider that plays
## until removed. An SFX is a tile with a big play button that plays once.
## Everything else is in the right-click menu; double-click a name to rename.

signal changed
signal remove_requested(row: TrackRow)
signal bind_requested(row: TrackRow)
signal rename_requested(row: TrackRow, new_name: String)

enum { MENU_PLAY, MENU_STOP, MENU_SET_KEY, MENU_CLEAR_KEY, MENU_VOLUME, MENU_RENAME, MENU_REMOVE }

const LOOP_COLOR := Color(0.16, 0.22, 0.30)
const SFX_COLOR := Color(0.20, 0.20, 0.24)
const PLAYING_COLOR := Color(0.35, 0.85, 0.45)
const IDLE_BORDER := Color(0.30, 0.30, 0.34)
const ERROR_COLOR := Color(1.0, 0.45, 0.45)
const TILE_WIDTH := 170
const TILE_BUTTON_HEIGHT := 120

var data: Dictionary
var player := AudioStreamPlayer.new()

var _style := StyleBoxFlat.new()
var _name_label: Label
var _name_edit: LineEdit
var _menu := PopupMenu.new()
var _play_button: PlayButton
var _progress: ProgressBar
var _volume_slider: HSlider
var _volume_label: Label
var _volume_popup: PopupPanel
var _binding := false


## The big SFX button: a play triangle, with the hotkey in the corner.
class PlayButton extends Button:
	var key_text := ""
	var playing := false

	func _draw() -> void:
		var center := size / 2.0
		var r := minf(size.x, size.y) * 0.28
		var points := PackedVector2Array([
			center + Vector2(-r * 0.7, -r),
			center + Vector2(r, 0.0),
			center + Vector2(-r * 0.7, r),
		])
		var color := PLAYING_COLOR if playing else Color(0.92, 0.92, 0.92)
		if disabled:
			color = Color(0.5, 0.5, 0.5)
		draw_colored_polygon(points, color)
		if key_text != "":
			var font := get_theme_default_font()
			var font_size := 16
			draw_string(font, Vector2(8.0, 6.0 + font.get_ascent(font_size)), key_text,
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, font_size, Color(1, 1, 1, 0.8))


static func volume_to_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)


## Must be called after the row has been added to the scene tree.
func setup(track: Dictionary, stream: AudioStream) -> void:
	data = track
	player.stream = stream
	player.volume_db = volume_to_db(get_volume())
	add_child(player)
	player.finished.connect(_update_playing_look)

	_style.bg_color = LOOP_COLOR if is_loop() else SFX_COLOR
	_style.border_color = IDLE_BORDER
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style)

	_build_name()
	_build_volume_controls()
	_build_menu()
	if is_sfx():
		_build_tile()
	else:
		_build_loop_row()
	gui_input.connect(_on_gui_input)

	if is_loop() and stream:
		player.play()
	_update_playing_look()
	set_process(is_sfx())


func _build_name() -> void:
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_name_label.gui_input.connect(_on_name_label_input)
	if player.stream == null:
		_name_label.add_theme_color_override("font_color", ERROR_COLOR)
	update_name()

	_name_edit = LineEdit.new()
	_name_edit.visible = false
	_name_edit.text_submitted.connect(func(_text: String) -> void: _finish_rename(true))
	_name_edit.focus_exited.connect(func() -> void: _finish_rename(true))
	_name_edit.gui_input.connect(_on_name_edit_input)


func _build_volume_controls() -> void:
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = get_volume()
	_volume_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	_volume_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	_volume_slider.focus_mode = Control.FOCUS_NONE
	_volume_slider.value_changed.connect(_on_volume_changed)
	_volume_slider.gui_input.connect(_on_gui_input)

	_volume_label = Label.new()
	_volume_label.custom_minimum_size.x = 56
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_update_volume_label()


func _build_menu() -> void:
	if is_sfx():
		_menu.add_item("Play", MENU_PLAY)
		_menu.add_item("Stop", MENU_STOP)
		_menu.add_separator()
		_menu.add_item("Set hotkey...", MENU_SET_KEY)
		_menu.add_item("Clear hotkey", MENU_CLEAR_KEY)
		_menu.add_item("Volume...", MENU_VOLUME)
		_menu.add_separator()
	_menu.add_item("Rename", MENU_RENAME)
	_menu.add_item("Remove", MENU_REMOVE)
	_menu.id_pressed.connect(_on_menu_pressed)
	add_child(_menu)


func _build_loop_row() -> void:
	var box := VBoxContainer.new()
	add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	_name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_label.clip_text = true
	top.add_child(_name_label)
	_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_name_edit)

	var looping := Label.new()
	looping.text = "Looping" if player.stream else ""
	looping.add_theme_color_override("font_color", PLAYING_COLOR)
	top.add_child(looping)

	var bottom := HBoxContainer.new()
	box.add_child(bottom)
	var vol_title := Label.new()
	vol_title.text = "Vol"
	bottom.add_child(vol_title)
	bottom.add_child(_volume_slider)
	bottom.add_child(_volume_label)


func _build_tile() -> void:
	custom_minimum_size.x = TILE_WIDTH
	var box := VBoxContainer.new()
	add_child(box)

	_play_button = PlayButton.new()
	_play_button.custom_minimum_size = Vector2(TILE_WIDTH - 16, TILE_BUTTON_HEIGHT)
	_play_button.focus_mode = Control.FOCUS_NONE
	_play_button.disabled = player.stream == null
	_play_button.tooltip_text = "Click to play. Right-click for options."
	_play_button.pressed.connect(play)
	_play_button.gui_input.connect(_on_gui_input)
	box.add_child(_play_button)
	_update_key_text()

	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.custom_minimum_size.x = TILE_WIDTH - 16
	box.add_child(_name_label)
	box.add_child(_name_edit)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 6
	_progress.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_progress)

	_volume_popup = PopupPanel.new()
	var popup_box := HBoxContainer.new()
	popup_box.custom_minimum_size.x = 280
	var vol_title := Label.new()
	vol_title.text = "Volume"
	popup_box.add_child(vol_title)
	popup_box.add_child(_volume_slider)
	popup_box.add_child(_volume_label)
	_volume_popup.add_child(popup_box)
	add_child(_volume_popup)


func _process(_delta: float) -> void:
	if player.playing and player.stream:
		var length := player.stream.get_length()
		_progress.value = player.get_playback_position() / length if length > 0.0 else 0.0
	elif _progress.value != 0.0:
		_progress.value = 0.0


func is_loop() -> bool:
	return data.get("mode", "sfx") == "loop"


func is_sfx() -> bool:
	return not is_loop()


func get_volume() -> float:
	return float(data.get("volume", 1.0))


func get_hotkey() -> int:
	return int(data.get("key", 0))


func set_hotkey(code: int) -> void:
	data["key"] = code
	_update_key_text()
	changed.emit()


func set_binding_mode(active: bool) -> void:
	_binding = active
	_update_key_text()


func play() -> void:
	if player.stream:
		player.play()
		_update_playing_look()


func stop() -> void:
	player.stop()
	_update_playing_look()


func update_name() -> void:
	_name_label.text = str(data.get("name", "Sound"))
	_name_label.tooltip_text = str(data.get("file", ""))
	if player.stream == null:
		_name_label.text += "  (missing or unreadable file)"


func start_rename() -> void:
	_name_edit.text = str(data.get("name", ""))
	_name_label.visible = false
	_name_edit.visible = true
	_name_edit.grab_focus()
	_name_edit.select_all()


func _finish_rename(accept: bool) -> void:
	if not _name_edit.visible:
		return
	_name_edit.visible = false
	_name_label.visible = true
	var new_name := _name_edit.text.strip_edges()
	if accept and new_name != "" and new_name != str(data.get("name", "")):
		rename_requested.emit(self, new_name)


func _show_menu() -> void:
	if is_sfx():
		_menu.set_item_disabled(_menu.get_item_index(MENU_PLAY), player.stream == null)
		_menu.set_item_disabled(_menu.get_item_index(MENU_CLEAR_KEY), get_hotkey() == 0)
	_menu.popup(Rect2i(Vector2i(get_screen_position() + get_local_mouse_position()), Vector2i.ZERO))


func _on_menu_pressed(id: int) -> void:
	match id:
		MENU_PLAY:
			play()
		MENU_STOP:
			stop()
		MENU_SET_KEY:
			bind_requested.emit(self)
		MENU_CLEAR_KEY:
			set_hotkey(0)
		MENU_VOLUME:
			_volume_popup.popup(Rect2i(Vector2i(get_screen_position() + get_local_mouse_position()), Vector2i.ZERO))
		MENU_RENAME:
			start_rename()
		MENU_REMOVE:
			remove_requested.emit(self)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_menu()
		get_viewport().set_input_as_handled()


func _on_name_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		start_rename()


func _on_name_edit_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_finish_rename(false)
		_name_edit.accept_event()


func _on_volume_changed(value: float) -> void:
	data["volume"] = value
	player.volume_db = volume_to_db(value)
	_update_volume_label()
	changed.emit()


func _update_volume_label() -> void:
	_volume_label.text = "%d%%" % roundi(get_volume() * 100.0)


func _update_key_text() -> void:
	if _play_button == null:
		return
	var code := get_hotkey()
	if _binding:
		_play_button.key_text = "Press a key..."
	else:
		_play_button.key_text = OS.get_keycode_string(code) if code != 0 else ""
	_play_button.queue_redraw()


func _update_playing_look() -> void:
	_style.border_color = PLAYING_COLOR if player.playing else IDLE_BORDER
	if _play_button:
		_play_button.playing = player.playing
		_play_button.queue_redraw()
