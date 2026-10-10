class_name DotsButton
extends MenuButton
## A menu button drawn as three vertical dots on its own small background,
## so it reads as a separate button and reacts to hover and clicks.

const SIZE := Vector2(28, 30)
const DOT_RADIUS := 2.4
const DOT_SPACING := 6.5
const DOT_COLOR := Color(0.82, 0.82, 0.86)
const DOT_ACTIVE_COLOR := Color(1, 1, 1)


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = false
	text = ""
	custom_minimum_size = SIZE
	tooltip_text = ""
	_set_style("normal", Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.16))
	_set_style("hover", Color(1, 1, 1, 0.20), Color(1, 1, 1, 0.35))
	_set_style("pressed", Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.5))
	_set_style("hover_pressed", Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.5))
	_set_style("disabled", Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _draw() -> void:
	var color := DOT_ACTIVE_COLOR if is_hovered() or is_pressed() else DOT_COLOR
	var center := size / 2.0
	for i in [-1, 0, 1]:
		draw_circle(center + Vector2(0.0, i * DOT_SPACING), DOT_RADIUS, color)


func _set_style(state: String, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	add_theme_stylebox_override(state, style)
