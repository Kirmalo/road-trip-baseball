extends Control
# Screen overlay: the base/out diamond, and the strike zone panel ("catcher's view") during each pitch.

var game

const ZX := 60.0   # half width of the strike zone in pixels
const ZY := 75.0   # half height

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_draw_bases()
	if game.phase == game.PRE_PITCH or game.phase == game.PITCHING or game.zone_show > 0.0:
		_draw_zone()

func _draw_bases() -> void:
	var c := Vector2(size.x - 80, 100)
	draw_rect(Rect2(c - Vector2(52, 38), Vector2(104, 96)), Color(0, 0, 0, 0.45))
	var spots := [Vector2(0, 0), Vector2(22, 0), Vector2(0, -22), Vector2(-22, 0)]
	for b in [1, 2, 3]:
		var p: Vector2 = c + spots[b] + Vector2(0, 8)
		var on: bool = game.base_occupied(b)
		draw_set_transform(p, PI / 4.0, Vector2.ONE)
		draw_rect(Rect2(-8, -8, 16, 16), Color(1, 0.85, 0.2) if on else Color(1, 1, 1, 0.15))
		draw_rect(Rect2(-8, -8, 16, 16), Color.WHITE, false, 2.0)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for i in 3:
		var p := c + Vector2(-20 + i * 20, 42)
		draw_circle(p, 7, Color(0.95, 0.25, 0.2) if i < game.outs else Color(1, 1, 1, 0.15))
		draw_arc(p, 7, 0, TAU, 16, Color.WHITE, 1.5)

func zone_center() -> Vector2:
	return Vector2(size.x - 210, 330)

func _draw_zone() -> void:
	var pc := zone_center()
	var z := Vector2(ZX, ZY)
	draw_rect(Rect2(pc - Vector2(125, 150), Vector2(250, 300)), Color(0, 0, 0, 0.45))
	# zone with a faint 3x3 grid
	draw_rect(Rect2(pc - z, z * 2), Color(1, 1, 1, 0.06))
	for i in range(1, 3):
		var fx := -ZX + ZX * 2 * i / 3.0
		var fy := -ZY + ZY * 2 * i / 3.0
		draw_line(pc + Vector2(fx, -ZY), pc + Vector2(fx, ZY), Color(1, 1, 1, 0.15), 1.0)
		draw_line(pc + Vector2(-ZX, fy), pc + Vector2(ZX, fy), Color(1, 1, 1, 0.15), 1.0)
	draw_rect(Rect2(pc - z, z * 2), Color(1, 1, 1, 0.85), false, 2.0)
	var plate := PackedVector2Array([pc + Vector2(-ZX, ZY + 34), pc + Vector2(ZX, ZY + 34), pc + Vector2(ZX, ZY + 44), pc + Vector2(0, ZY + 52), pc + Vector2(-ZX, ZY + 44)])
	draw_colored_polygon(plate, Color(1, 1, 1, 0.7))

	# your aim (pitching) or your bat (batting)
	if game.human_pitching() and game.phase == game.PRE_PITCH:
		var a: Vector2 = pc + game.aim * z
		draw_arc(a, 12, 0, TAU, 24, Color(1, 0.3, 0.25), 2.5)
		draw_line(a - Vector2(18, 0), a + Vector2(18, 0), Color(1, 0.3, 0.25), 2.0)
		draw_line(a - Vector2(0, 18), a + Vector2(0, 18), Color(1, 0.3, 0.25), 2.0)
	if game.human_batting():
		var cp: Vector2 = pc + game.cursor * z
		draw_set_transform(cp, 0, Vector2(ZX, ZY) * game.CONTACT_R / 30.0)
		draw_circle(Vector2.ZERO, 30.0, Color(1, 0.9, 0.2, 0.18))
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, Color(1, 0.9, 0.2), 2.5)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_circle(cp, 3, Color(1, 0.9, 0.2))

	# the pitch coming in: small and high at release, full size at the plate
	var font := ThemeDB.fallback_font
	if game.phase == game.PITCHING or game.zone_show > 0.0:
		var p: float = game.ball.pitch_t if game.phase == game.PITCHING else 1.0
		var start := pc + Vector2(-0.15 * ZX, -1.6 * ZY)
		var fin: Vector2 = pc + game.pitch_loc * z
		var bp := start.lerp(fin, p)
		if game.pitch_type == game.CHANGEUP:
			bp.y -= p * (1.0 - p) * ZY * 0.9
		var r := 3.0 + 10.0 * p * p
		draw_circle(bp, r + 1.5, Color(0, 0, 0, 0.6))
		draw_circle(bp, r, Color(0.98, 0.97, 0.92))
		var pname := "FASTBALL" if game.pitch_type == game.FASTBALL else "CHANGEUP"
		_text(font, "%s  %d MPH" % [pname, game.pitch_mph], pc + Vector2(0, 135), 18)
	elif game.phase == game.PRE_PITCH:
		if game.human_pitching():
			_text(font, "AIM, THEN PICK A PITCH", pc + Vector2(0, 135), 18)
		elif game.human_batting():
			_text(font, "COVER THE BALL, THEN SWING", pc + Vector2(0, 135), 18)
	_text(font, "BALLS %d   STRIKES %d" % [game.balls, game.strikes], pc + Vector2(0, -128), 18)

func _text(font: Font, t: String, at: Vector2, fs: int) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, at - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
