extends Control
# Screen overlay: the mini-map (whole field, runners, fielders, ball, count and outs) in the top-left corner, and the
# strike zone panel ("catcher's view") on the right during each pitch: the incoming pitch with its break, the
# timing ring when you bat, the aim and the meter when you pitch.

var game

const ZX := 60.0   # half width of the strike zone in pixels
const ZY := 75.0   # half height
const MAP_SCALE := 0.36        # mini-map pixels per foot
const MAP_W := 180.0
const MAP_H := 160.0
const RING_START := 62.0       # the timing ring's size (beyond the ball) when it appears
const RING_TIME := 0.45        # seconds before the moment to swing that it appears and starts closing

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_draw_minimap()
	if game.exit_timer > 0.0 and game.exit_text != "":
		# how hard it was hit, right under the score bar
		var font := ThemeDB.fallback_font
		var a := clampf(game.exit_timer / 0.4, 0.0, 1.0)
		_text(font, "EXIT VELO  " + game.exit_text, Vector2(size.x / 2, 86), 24, Color(1, 0.92, 0.5, a))
	if (game.phase == game.PRE_PITCH or game.phase == game.PITCHING) and game.batter != null:
		_draw_cards()
	if game.phase == game.PRE_PITCH or game.phase == game.PITCHING or game.zone_show > 0.0 or game.swing_text_timer > 0.0:
		_draw_zone()
	elif game.phase == game.LIVE:
		_draw_live_hint()

# ---------------- mini-map ----------------

func map_origin() -> Vector2:
	return Vector2(16 + MAP_W / 2, 92 + MAP_H - 18)

func _to_map(p: Vector2) -> Vector2:
	return map_origin() + p / game.FT * MAP_SCALE

func _draw_minimap() -> void:
	var r := Rect2(16, 92, MAP_W, MAP_H + 34)
	draw_rect(r, Color(0.05, 0.06, 0.09, 0.85))
	# the field: walls, infield, bases
	var fan := PackedVector2Array()
	for i in 91:
		var a := deg_to_rad(-45.0 + i)
		var d := Vector2(sin(a), -cos(a))
		fan.append(_to_map(d * game.fence_radius(d * 100.0)))
	var poly := PackedVector2Array([_to_map(Vector2.ZERO)])
	poly.append_array(fan)
	draw_colored_polygon(poly, Color(0.22, 0.5, 0.22, 0.85))
	var dia := PackedVector2Array()
	for b in 5:
		dia.append(_to_map(game.base_pos(b)))
	draw_colored_polygon(dia, Color(0.7, 0.52, 0.33, 0.9))
	draw_polyline(dia, Color(1, 1, 1, 0.8), 1.5)
	for b in [1, 2, 3]:
		var bp := _to_map(game.base_pos(b))
		var on: bool = game.base_occupied(b)
		draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.85, 0.2) if on else Color.WHITE)
	# what the camera shows, so you know where you are looking
	var cam: Camera2D = game.camera
	var half := get_viewport_rect().size / cam.zoom / 2.0
	var tl: Vector2 = game.View.to_floor(cam.position - half)
	var br: Vector2 = game.View.to_floor(cam.position + half)
	var view := Rect2(_to_map(tl), (br - tl) / game.FT * MAP_SCALE)
	draw_rect(view.intersection(Rect2(r.position, Vector2(MAP_W, MAP_H))), Color(1, 1, 1, 0.35), false, 1.0)
	# players: fielders small, runners bigger with their running arrow
	for p in game.players:
		if not p.visible or p.mode == p.OFF:
			continue
		var col := Color(0.35, 0.6, 1.0) if p.team == 0 else Color(1.0, 0.35, 0.3)
		var mp := _to_map(p.position)
		if p.mode == p.RUNNER or p.mode == p.BATTER:
			draw_circle(mp, 4.5, col)
			draw_arc(mp, 4.5, 0, TAU, 12, Color.WHITE, 1.2)
		else:
			draw_circle(mp, 3.0, col)
		if game.is_human(p):
			draw_arc(mp, 6.5, 0, TAU, 12, Color(1, 0.9, 0.2), 1.5)
	# the ball and where a fly ball comes down
	var ball = game.ball
	var inside := Rect2(r.position, Vector2(MAP_W, MAP_H))
	if ball.state == ball.LIVE and ball.can_fly_out and ball.path_bounce > ball.index_now() and inside.has_point(_to_map(ball.path_p[ball.path_bounce])):
		var lp := _to_map(ball.path_p[ball.path_bounce])
		draw_line(lp - Vector2(4, 4), lp + Vector2(4, 4), Color(1, 0.9, 0.2), 2.0)
		draw_line(lp - Vector2(4, -4), lp + Vector2(4, -4), Color(1, 0.9, 0.2), 2.0)
	if ball.state != ball.DEAD and inside.has_point(_to_map(ball.position)):
		draw_circle(_to_map(ball.position), 3.0, Color.WHITE)
		draw_arc(_to_map(ball.position), 3.0, 0, TAU, 10, Color.BLACK, 1.0)
	# count and outs
	var font := ThemeDB.fallback_font
	var y := r.position.y + MAP_H + 24
	_text_left(font, "B %d  S %d" % [game.balls, game.strikes], Vector2(r.position.x + 10, y), 18)
	_text_left(font, "OUT", Vector2(r.position.x + 98, y), 16)
	for i in 3:
		var p := Vector2(r.position.x + 140 + i * 14, y - 6)
		draw_circle(p, 5.5, Color(0.95, 0.25, 0.2) if i < game.outs else Color(1, 1, 1, 0.15))
		draw_arc(p, 5.5, 0, TAU, 12, Color.WHITE, 1.2)

# ---------------- rating cards ----------------

func _draw_cards() -> void:
	var font := ThemeDB.fallback_font
	var y := size.y - 112
	var br: Dictionary = game.batter.r
	var bx := size.x / 2 - 290
	_card(Rect2(bx, y, 230, 96), Color(0.2, 0.45, 1.0) if game.batting == 0 else Color(0.95, 0.25, 0.2))
	_text_left(font, "AT BAT  #%d  %s" % [int(br["number"]), game.POS_NAMES[game.batter.role]], Vector2(bx + 10, y + 22), 17)
	_bar(font, "CON", br["contact"], Vector2(bx + 10, y + 42))
	_bar(font, "POW", br["power"], Vector2(bx + 10, y + 62))
	_bar(font, "SPD", br["speed"], Vector2(bx + 10, y + 82))
	var pr: Dictionary = game.pitcher_r()
	var px := size.x / 2 - 50
	_card(Rect2(px, y, 230, 96), Color(0.2, 0.45, 1.0) if game.fielding == 0 else Color(0.95, 0.25, 0.2))
	_text_left(font, "PITCHER  #%d   %d P" % [int(pr["number"]), int(pr["pitch_count"])], Vector2(px + 10, y + 22), 17)
	_bar(font, "VEL", pr["velocity"], Vector2(px + 10, y + 42))
	_bar(font, "CTL", pr["control"], Vector2(px + 10, y + 62))
	var e: float = game.pitcher_energy()
	var ecol := Color(0.3, 0.9, 0.4) if e > 0.5 else (Color(1, 0.8, 0.2) if e > 0.25 else Color(1, 0.3, 0.25))
	_bar(font, "ARM", e * 100.0, Vector2(px + 10, y + 82), ecol)

func _card(r: Rect2, team_col: Color) -> void:
	draw_rect(r, Color(0.05, 0.06, 0.09, 0.82))
	draw_rect(Rect2(r.position, Vector2(5, r.size.y)), team_col)

func _bar(font: Font, label: String, v: float, at: Vector2, col := Color(0.95, 0.8, 0.3)) -> void:
	_text_left(font, label, at, 14)
	var x0 := at.x + 42
	draw_rect(Rect2(x0, at.y - 10, 150, 10), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(x0, at.y - 10, 150 * clampf(v / 100.0, 0.0, 1.0), 10), col)

# ---------------- strike zone panel ----------------

func zone_center() -> Vector2:
	return Vector2(size.x - 210, 268)

func _pitch_screen_pos(pc: Vector2, p: float) -> Vector2:
	# where the incoming pitch is drawn in the panel at progress p (0 = release, 1 = at the plate)
	var start := pc + Vector2(-0.15 * ZX, -1.6 * ZY)
	var fin: Vector2 = pc + game.pitch_loc * Vector2(ZX, ZY)
	# it travels toward where it looks like it's going, then breaks late
	var brk: Vector2 = game.pitch_brk * Vector2(ZX, ZY)
	return start.lerp(fin - brk, p) + brk * pow(p, 3.0)

func _draw_zone() -> void:
	var pc := zone_center()
	var z := Vector2(ZX, ZY)
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(pc - Vector2(125, 150), Vector2(250, 300)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(pc - z, z * 2), Color(1, 1, 1, 0.06))
	for i in range(1, 3):
		var fx := -ZX + ZX * 2 * i / 3.0
		var fy := -ZY + ZY * 2 * i / 3.0
		draw_line(pc + Vector2(fx, -ZY), pc + Vector2(fx, ZY), Color(1, 1, 1, 0.15), 1.0)
		draw_line(pc + Vector2(-ZX, fy), pc + Vector2(ZX, fy), Color(1, 1, 1, 0.15), 1.0)
	draw_rect(Rect2(pc - z, z * 2), Color(1, 1, 1, 0.85), false, 2.0)
	var plate := PackedVector2Array([pc + Vector2(-ZX, ZY + 34), pc + Vector2(ZX, ZY + 34), pc + Vector2(ZX, ZY + 44), pc + Vector2(0, ZY + 52), pc + Vector2(-ZX, ZY + 44)])
	draw_colored_polygon(plate, Color(1, 1, 1, 0.7))
	_text(font, "BALLS %d   STRIKES %d" % [game.balls, game.strikes], pc + Vector2(0, -128), 18)

	# pitching: aim crosshair, then the meter
	if game.human_pitching() and game.phase == game.PRE_PITCH:
		var a: Vector2 = pc + game.aim * z
		draw_arc(a, 12, 0, TAU, 24, Color(1, 0.3, 0.25), 2.5)
		draw_line(a - Vector2(18, 0), a + Vector2(18, 0), Color(1, 0.3, 0.25), 2.0)
		draw_line(a - Vector2(0, 18), a + Vector2(0, 18), Color(1, 0.3, 0.25), 2.0)
		if game.meter_active:
			_draw_meter(pc + Vector2(0, 112))
			_text(font, "%s: STOP IN THE GREEN" % game.Ratings.PITCH_LONG[game.pitch_type], pc + Vector2(0, 140), 16)
		else:
			_text(font, "AIM, THEN PICK A PITCH", pc + Vector2(0, 135), 18)
		return

	# the pitch coming in
	if game.phase == game.PITCHING or game.zone_show > 0.0 or game.swing_text_timer > 0.0:
		var p: float = game.ball.pitch_t if game.phase == game.PITCHING else 1.0
		var bp := _pitch_screen_pos(pc, p)
		var r := 3.0 + 10.0 * p * p
		# timing ring: closes on the ball and touches it at the moment to tap SWING
		if game.human_batting() and game.phase == game.PITCHING and not game.swung:
			var left: float = (game.pitch_dur - game.SWING_DELAY) - game.pitch_clock
			var window: float = game._contact_window(false)
			var rr := r + 4.0 + RING_START * clampf(left / RING_TIME, 0.0, 1.0)   # appears, then closes steadily
			var col := Color(1, 1, 1, 0.85)
			if absf(left) <= window * game._perfect_frac():
				col = Color(0.3, 1.0, 0.4)
			elif absf(left) <= window:
				col = Color(1, 0.85, 0.2)
			if left > -window:
				draw_arc(bp, rr, 0, TAU, 40, col, 3.5)
		draw_circle(bp, r + 1.5, Color(0, 0, 0, 0.6))
		draw_circle(bp, r, Color(0.98, 0.97, 0.92))
		_text(font, "%s  %d MPH" % [game.Ratings.PITCH_LONG[game.pitch_type], game.pitch_mph], pc + Vector2(0, 135), 18)
	elif game.phase == game.PRE_PITCH and game.human_batting():
		_text(font, "TAP SWING WHEN THE RING CLOSES", pc + Vector2(0, 128), 16)
		_text(font, "stick UP = fly ball   DOWN = grounder", pc + Vector2(0, 146), 14)
	# how your swing was timed
	if game.swing_text_timer > 0.0:
		var t: String = game.swing_text
		var col := Color(1, 0.6, 0.2)
		if t == "PERFECT!":
			col = Color(0.35, 1.0, 0.45)
		elif t.begins_with("WAY"):
			col = Color(1, 0.35, 0.3)
		_text(font, t, pc + Vector2(0, -88), 30, col)

func _draw_meter(c: Vector2) -> void:
	var w := 200.0
	var green: float = game.meter_green()
	draw_rect(Rect2(c - Vector2(w / 2, 9), Vector2(w, 18)), Color(0.75, 0.2, 0.15, 0.9))
	draw_rect(Rect2(c - Vector2(w / 2 * 0.6, 9), Vector2(w * 0.6, 18)), Color(0.9, 0.7, 0.15, 0.9))
	draw_rect(Rect2(c - Vector2(w / 2 * green, 9), Vector2(w * green, 18)), Color(0.2, 0.85, 0.3))
	draw_rect(Rect2(c - Vector2(w / 2, 9), Vector2(w, 18)), Color.WHITE, false, 2.0)
	var x: float = c.x + game.meter_pos * w / 2
	draw_rect(Rect2(Vector2(x - 3, c.y - 15), Vector2(6, 30)), Color.WHITE)

func _draw_live_hint() -> void:
	var font := ThemeDB.fallback_font
	var at := Vector2(size.x / 2, size.y - 24)
	if game.human_batting():
		var mode: int = game.run_mode
		var t := "RUNNERS: AUTO   (GO = take an extra base,  HOLD = stay put)"
		if mode == game.RUN_GO:
			t = "RUNNERS: GOING FOR IT"
		elif mode == game.RUN_HOLD:
			t = "RUNNERS: HOLDING"
		_text(font, t, at, 18)
	elif game.ball.state == game.ball.HELD and game.is_human(game.ball.holder):
		_text(font, "TAP A BASE TO THROW   (green = best play)", at, 18)

func _text(font: Font, t: String, at: Vector2, fs: int, col := Color.WHITE) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, at - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _text_left(font: Font, t: String, at: Vector2, fs: int) -> void:
	draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
