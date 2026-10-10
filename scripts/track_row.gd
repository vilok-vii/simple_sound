class_name TrackRow
extends PanelContainer
## One sound in the workspace. Either a loop (plays continuously until removed)
## or an SFX (plays once when triggered by its button or hotkey).

signal changed
signal remove_requested(row: TrackRow)
signal bind_requested(row: TrackRow)

const LOOP_COLOR := Color(0.16, 0.22, 0.30)
const SFX_COLOR := Color(0.20, 0.20, 0.24)
const PLAYING_BORDER := Color(0.35, 0.85, 0.45)
const IDLE_BORDER := Color(0.30, 0.30, 0.34)

var data: Dictionary
var player := AudioStreamPlayer.new()

var _style := StyleBoxFlat.new()
var _volume_label: Label
var _key_button: Button
var _progress: ProgressBar


static func volume_to_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)


## Must be called after the row has been added to the scene tree.
func setup(track: Dictionary, stream: AudioStream) -> void:
	data = track
	player.stream = stream
	player.volume_db = volume_to_db(get_volume())
	add_child(player)

	_style.bg_color = LOOP_COLOR if is_loop() else SFX_COLOR
	_style.border_color = IDLE_BORDER
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style)

	var box := VBoxContainer.new()
	add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)

	var name_label := Label.new()
	name_label.text = str(data.get("name", "Sound"))
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.tooltip_text = str(data.get("file", ""))
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(name_label)

	if stream == null:
		name_label.text += "  (missing or unreadable file)"
		name_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	if is_sfx():
		_key_button = _make_button("", func() -> void: bind_requested.emit(self))
		_key_button.tooltip_text = "Click, then press a key to bind it to this sound"
		_update_key_button()
		top.add_child(_key_button)
		top.add_child(_make_button("Play", play))
		top.add_child(_make_button("Stop", stop))
	else:
		var looping := Label.new()
		looping.text = "Looping" if stream else ""
		looping.add_theme_color_override("font_color", PLAYING_BORDER)
		top.add_child(looping)

	var remove := _make_button("Remove", func() -> void: remove_requested.emit(self))
	remove.tooltip_text = "Remove this sound from the project"
	top.add_child(remove)

	var bottom := HBoxContainer.new()
	box.add_child(bottom)

	var vol_title := Label.new()
	vol_title.text = "Vol"
	bottom.add_child(vol_title)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = get_volume()
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_volume_changed)
	bottom.add_child(slider)

	_volume_label = Label.new()
	_volume_label.custom_minimum_size.x = 56
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_volume_label)
	_update_volume_label()

	if is_sfx():
		_progress = ProgressBar.new()
		_progress.min_value = 0.0
		_progress.max_value = 1.0
		_progress.show_percentage = false
		_progress.custom_minimum_size.y = 6
		box.add_child(_progress)
		player.finished.connect(_update_playing_look)
	elif stream:
		player.play()
		_update_playing_look()

	set_process(is_sfx())


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
	_update_key_button()
	changed.emit()


func set_binding_mode(active: bool) -> void:
	if _key_button == null:
		return
	if active:
		_key_button.text = "Press a key..."
	else:
		_update_key_button()


func play() -> void:
	if player.stream:
		player.play()
		_update_playing_look()


func stop() -> void:
	player.stop()
	_update_playing_look()


func _on_volume_changed(value: float) -> void:
	data["volume"] = value
	player.volume_db = volume_to_db(value)
	_update_volume_label()
	changed.emit()


func _update_volume_label() -> void:
	_volume_label.text = "%d%%" % roundi(get_volume() * 100.0)


func _update_key_button() -> void:
	var code := get_hotkey()
	_key_button.text = "Key: " + OS.get_keycode_string(code) if code != 0 else "Set key"


func _update_playing_look() -> void:
	_style.border_color = PLAYING_BORDER if player.playing else IDLE_BORDER


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button
