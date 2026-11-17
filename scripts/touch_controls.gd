extends Control
# Floating joystick (touch anywhere on the left side), two action buttons on the right, and the four base buttons
# (1B, 2B, 3B, HOME) that replace the action buttons while your fielder holds the ball.

signal a_pressed
signal a_released
signal b_pressed
signal base_pressed(b: int)

var joy_index := -1
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
const JOY_RADIUS := 80.0

var a_index := -1
var b_index := -1
var a_text := "SWING"
var b_text := "BUNT"
var show_bases := false       # set by the game while you hold the ball in the field
var base_hint := -1           # the base the CPU would throw to (drawn brighter)
const BASE_R := 46.0
const BASE_LABELS := ["HOME", "1B", "2B", "3B"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func joystick() -> Vector2:
	if joy_index < 0:
		return Vector2.ZERO
	var v := (joy_knob - joy_center) / JOY_RADIUS
	return v if v.length() > 0.15 else Vector2.ZERO

func a_center() -> Vector2:
	return Vector2(size.x - 120, size.y - 130)

func b_center() -> Vector2:
	return Vector2(size.x - 280, size.y - 90)

func base_center(b: int) -> Vector2:
	# a small diamond of buttons near the right thumb, laid out like the field
	var c := Vector2(size.x - 175, size.y - 165)
	match b:
		1:
			return c + Vector2(95, 0)
		2:
			return c + Vector2(0, -95)
		3:
			return c + Vector2(-95, 0)
	return c + Vector2(0, 95)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if show_bases:
				for b in 4:
					if event.position.distance_to(base_center(b)) < BASE_R + 8.0:
						base_pressed.emit(b)
						return
			elif event.position.distance_to(a_center()) < 85.0:
				a_index = event.index
				a_pressed.emit()
				return
			elif event.position.distance_to(b_center()) < 70.0:
				b_index = event.index
				b_pressed.emit()
				return
			if event.position.x < size.x * 0.5 and joy_index < 0:
				joy_index = event.index
				joy_center = event.position
				joy_knob = event.position
		else:
			if event.index == joy_index:
				joy_index = -1
			if event.index == a_index:
				a_index = -1
				a_released.emit()
			if event.index == b_index:
				b_index = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			joy_knob = joy_center + (event.position - joy_center).limit_length(JOY_RADIUS)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# joystick
	if joy_index >= 0:
		draw_circle(joy_center, JOY_RADIUS, Color(1, 1, 1, 0.15))
		draw_arc(joy_center, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		draw_circle(joy_knob, 34.0, Color(1, 1, 1, 0.55))
	else:
		var hint := Vector2(150, size.y - 150)
		draw_arc(hint, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
		draw_circle(hint, 34.0, Color(1, 1, 1, 0.18))
	if show_bases:
		var c := base_center(0) + Vector2(0, -95)
		var pts := PackedVector2Array([base_center(0), base_center(1), base_center(2), base_center(3), base_center(0)])
		draw_polyline(pts, Color(1, 1, 1, 0.35), 4.0)
		_label(c + Vector2(0, 6), "THROW", 18, Color(1, 1, 1, 0.9))
		for b in 4:
			var col := Color(0.15, 0.6, 0.25, 0.9) if b == base_hint else Color(0.12, 0.3, 0.55, 0.85)
			_button(base_center(b), BASE_R, BASE_LABELS[b], col)
		return
	# buttons
	if a_text != "-":
		_button(a_center(), 75.0, a_text, Color(0.95, 0.45, 0.1, 0.75 if a_index < 0 else 0.95))
	else:
		draw_arc(a_center(), 75.0, 0, TAU, 48, Color(1, 1, 1, 0.2), 2.0)
	if b_text != "-":
		_button(b_center(), 58.0, b_text, Color(0.2, 0.5, 0.95, 0.75 if b_index < 0 else 0.95))
	else:
		draw_arc(b_center(), 58.0, 0, TAU, 48, Color(1, 1, 1, 0.2), 2.0)

func _button(c: Vector2, r: float, text: String, col: Color) -> void:
	draw_circle(c, r, col)
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.8), 3.0)
	_label(c + Vector2(0, 22 * 0.35), text, 22, Color.WHITE)

func _label(at: Vector2, text: String, fs: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, at - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(font, at - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
