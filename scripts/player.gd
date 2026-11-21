extends Node2D
# One baseball player. Depending on mode it is a fielder, the batter at the plate, or a base runner.
# The game manager (main.gd) decides where fielders go and when runners advance; this script moves them.

enum { OFF, FIELDER, BATTER, RUNNER }
const View = preload("res://scripts/view.gd")
const SKINS := [Color(0.96, 0.8, 0.66), Color(0.78, 0.57, 0.4), Color(0.55, 0.37, 0.24), Color(0.9, 0.72, 0.55),
	Color(0.42, 0.28, 0.18)]

var game
var team := 0
var role := 0              # fielding position (0 P, 1 C, 2 1B, 3 2B, 4 SS, 5 3B, 6 LF, 7 CF, 8 RF) and batting slot
var mode := OFF
var sprite: Sprite2D
var velocity := Vector2.ZERO
var facing := 0.0
var target := Vector2.ZERO
var home_spot := Vector2.ZERO

# fielder
var catch_cooldown := 0.0
var hold_timer := 0.0
var think_timer := 0.0
var running_to_base := false

# runner: standing on (or leaving) base on_base, seg_t = how far along the path to the next base (0..1)
var on_base := 0
var seg_t := 0.0
var goal := 0              # on_base = stay or go back, on_base + 1 = run to the next base
var forced := false
var retouch := false       # must get back to on_base after a caught fly ball
var trot := false          # home run trot
var keep_going := false   # round the next base without stopping
var halfway := false       # forced runner waiting a few steps off the base while a fly ball hangs
var start_base := 0
var run_delay := 0.0

# batter
var swing_t := -1.0
var bunting := false
var loading := false       # SWING held down: bat cocked back for a power swing

# ratings (ratings.gd) and what they mean here
var r: Dictionary = {}
var run_speed := 27.0 * 4.0
var stealing := false      # running on the pitch
var steal_intent := false  # will run on this pitch (bigger lead: easier to pick off)

# diving
var dive_t := 0.0
var dive_dir := Vector2.RIGHT

# drawing
var stride := 0.0          # running animation phase
var last_pos := Vector2.ZERO

func setup(g, t: int, i: int, tex: Texture2D) -> void:
	game = g
	team = t
	role = i
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(1.7, 1.7)
	add_child(sprite)
	sprite.visible = not View.angled()   # the angled view draws upright figures in _draw instead
	z_index = 5
	home_spot = game.POSITIONS[i] * game.FT
	visible = false

func is_safe() -> bool:
	return on_base >= 1 and seg_t <= 0.0 and run_delay <= 0.0

func set_ratings(rr: Dictionary) -> void:
	r = rr
	run_speed = game.Ratings.run_speed_ft(float(r["speed"])) * game.FT

func update(delta: float, human: bool, input_vec: Vector2) -> void:
	catch_cooldown = maxf(0.0, catch_cooldown - delta)
	match mode:
		FIELDER:
			if dive_t > 0.0:
				dive_t -= delta
				velocity = Vector2.ZERO
			else:
				_fielder_update(delta, human, input_vec)
		RUNNER:
			if game.phase == game.LIVE or (game.phase == game.PITCHING and stealing):
				_runner_update(delta)
		BATTER:
			if swing_t >= 0.0:
				swing_t += delta
	sprite.rotation = facing
	# running animation from how far we actually moved
	var moved := position.distance_to(last_pos)
	last_pos = position
	stride = fmod(stride + moved * 0.09, TAU) if moved > 0.2 else lerpf(stride, 0.0, 0.2)
	queue_redraw()

func _fielder_update(delta: float, human: bool, input_vec: Vector2) -> void:
	var spd: float = game.FIELD_SPEED
	if game.phase == game.PAUSE:
		spd *= 1.6
	var desired := Vector2.ZERO
	if game.phase == game.LIVE or game.phase == game.PAUSE:   # fielding is automatic, also for you
		desired = _seek(target, spd)
	velocity = velocity.move_toward(desired, game.FIELD_ACCEL * (2.5 if game.phase != game.LIVE else 1.0) * delta)
	position += velocity * delta
	# stay inside the walls
	var fr: float = game.fence_radius(position) - 3.0 * game.FT
	if position.length() > fr:
		position = position.normalized() * fr
	var look := velocity
	if look.length() < 10.0:
		look = game.ball.position - position
	if look.length() > 3.0:
		facing = lerp_angle(facing, look.angle(), minf(1.0, 10.0 * delta))

func _seek(t: Vector2, spd: float) -> Vector2:
	var to := t - position
	var d := to.length()
	if d < 2.0:
		return Vector2.ZERO
	return to / d * spd * minf(1.0, d / 20.0)

func _runner_update(delta: float) -> void:
	if run_delay > 0.0:
		run_delay -= delta
		return
	var a: Vector2 = game.base_pos(on_base)
	var b: Vector2 = game.base_pos(on_base + 1)
	var step: float = run_speed * delta / a.distance_to(b)
	if goal > on_base:
		if not (halfway and seg_t >= 0.12):
			seg_t += step
		if seg_t >= 1.0:
			seg_t = 0.0
			on_base += 1
			forced = false
			goal = on_base
			position = b
			game.on_runner_reached(self)
			return
	elif seg_t > 0.0:
		seg_t = maxf(0.0, seg_t - step)
		if seg_t <= 0.0:
			retouch = false
	var newpos := a.lerp(b, seg_t)
	var moved := newpos - position
	position = newpos
	if moved.length() > 0.01:
		facing = moved.angle()

func _draw() -> void:
	# on the ground (squashed into an ellipse by the world in the angled view): team disc, your ring, runner arrows
	var col := Color(0.2, 0.45, 1.0, 0.7) if team == 0 else Color(0.95, 0.2, 0.15, 0.7)
	var ground_r := 16.0
	draw_circle(Vector2.ZERO, ground_r, Color(0, 0, 0, 0.3) if View.angled() else col)
	if View.angled():
		draw_arc(Vector2.ZERO, ground_r, 0, TAU, 32, col, 3.0)
	if game.is_human(self):
		draw_arc(Vector2.ZERO, 21.0, 0, TAU, 32, Color(1, 0.9, 0.2), 3.5)
	elif mode == FIELDER and game.phase == game.LIVE and game.ball.state == game.ball.HELD and game.ball.holder == self:
		draw_arc(Vector2.ZERO, 21.0, 0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)
	if mode == RUNNER and game.phase == game.LIVE and run_delay <= 0.0:
		# green arrow: running to the next base. Red: going back
		var to_b: int = on_base + 1 if goal > on_base else on_base
		var d: Vector2 = game.base_pos(to_b) - position
		if d.length() > 6.0 * game.FT:
			var dir := d.normalized()
			var c := Color(0.3, 1.0, 0.4) if goal > on_base else Color(1.0, 0.35, 0.3)
			var tip := dir * 40.0
			draw_line(dir * 22.0, tip, c, 4.0)
			draw_colored_polygon(PackedVector2Array([tip + dir * 10.0, tip + dir.orthogonal() * 7.0, tip - dir.orthogonal() * 7.0]), c)
	if View.angled() and dive_t > 0.0:
		# lying stretched out: rotate in screen-like coordinates, then undo the world's squash
		var side := -1.0 if dive_dir.x < 0.0 else 1.0
		var m := Transform2D(Vector2(1, 0), Vector2(0, 1.0 / View.tilt()), Vector2.ZERO) * Transform2D(side * 1.45, Vector2(side * 8, -4))
		draw_set_transform_matrix(m)
		_draw_figure()
		draw_set_transform(Vector2.ZERO, 0, View.upright())
	elif View.angled():
		draw_set_transform(Vector2.ZERO, 0, View.upright())
		_draw_figure()
	elif mode == BATTER:
		_draw_bat(Vector2(5, 5))
	if game.is_human(self):
		var y := -66.0 if View.angled() else -46.0
		var tri := PackedVector2Array([Vector2(-8, y), Vector2(8, y), Vector2(0, y + 11)])
		draw_colored_polygon(tri, Color(1, 0.9, 0.2))

func _bat_angle() -> float:
	# cocked back, swept through the zone on a swing, squared up for a bunt (an angle on the ground)
	if bunting:
		return -0.15
	if loading and swing_t < 0.0:
		return 2.6
	if swing_t >= 0.0:
		return lerpf(2.0, -2.8, minf(1.0, swing_t / 0.24))
	return 2.0

func _draw_bat(hands: Vector2) -> void:
	var dir := View.local(Vector2.from_angle(_bat_angle()))
	var lift := Vector2(0, -6) if View.angled() else Vector2.ZERO
	draw_line(hands, hands + dir * 26.0 + lift, Color(0.55, 0.35, 0.15), 5.0)
	draw_line(hands + dir * 13.0 + lift * 0.5, hands + dir * 26.0 + lift, Color(0.75, 0.55, 0.3), 6.5)

func _draw_figure() -> void:
	# a simple upright ballplayer in screen-like coordinates (feet at 0, 0; up is -y). Placeholder until Phase 3 art.
	var jersey := Color(0.2, 0.42, 0.92) if team == 0 else Color(0.86, 0.2, 0.17)
	var dark := jersey.darkened(0.35)
	var pants := Color(0.9, 0.9, 0.88)
	var skin: Color = SKINS[(role * 3 + team) % SKINS.size()]
	var f := Vector2.from_angle(facing)
	var side := 0.0                      # -1 facing left on screen, +1 right, 0 toward or away from the camera
	if absf(f.x) > 0.35:
		side = signf(f.x)
	var away := f.y < -0.5 and side == 0.0
	var run := sin(stride)
	var crouch := 3.0 if mode == FIELDER and game.phase == game.PITCHING and role != 0 else 0.0
	if mode == FIELDER and role == 1 and (game.phase == game.PRE_PITCH or game.phase == game.PITCHING):
		crouch = 13.0   # the catcher squats, so you can see the batter over him
	# legs
	var hip_y := -18.0 + crouch
	for k in [-1.0, 1.0]:
		var foot := Vector2(k * 4.5 + run * k * 6.0 * (1.0 if side != 0.0 else 0.3), 0)
		draw_line(Vector2(k * 4.0, hip_y), foot, pants, 6.0)
		draw_circle(foot + Vector2(0, -1), 3.2, Color(0.1, 0.1, 0.12))
	# body
	var top := -36.0 + crouch
	draw_rect(Rect2(-8.5, top, 17, hip_y - top + 1), jersey)
	draw_rect(Rect2(-8.5, hip_y - 2, 17, 3), dark)
	# arms (the glove hand is on the left of the body for fielders)
	var sh := top + 3.0
	var swing := -run * 5.0
	var l_hand := Vector2(-11 + swing * 0.5, sh + 13)
	var r_hand := Vector2(11 - swing * 0.5, sh + 13)
	if mode == BATTER:
		l_hand = Vector2(3, sh + 6)
		r_hand = Vector2(6, sh + 7)
	draw_line(Vector2(-8, sh), l_hand, jersey, 5.0)
	draw_line(Vector2(8, sh), r_hand, jersey, 5.0)
	draw_circle(r_hand, 2.6, skin)
	if mode == FIELDER:
		draw_circle(l_hand, 4.6, Color(0.5, 0.3, 0.12))
		if game.ball.state == game.ball.HELD and game.ball.holder == self:
			draw_circle(r_hand, 3.4, Color(0.98, 0.97, 0.92))
	else:
		draw_circle(l_hand, 2.6, skin)
	# number on the back
	if away:
		var font := ThemeDB.fallback_font
		var n := str(role + 1)
		draw_string(font, Vector2(-4 * n.length(), top + 13), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# head and cap
	var head := Vector2(side * 1.0, top - 7.0)
	draw_circle(head, 7.0, skin)
	if not away:
		if side == 0.0:
			draw_circle(head + Vector2(-2.5, 0), 1.2, Color(0.1, 0.1, 0.1))
			draw_circle(head + Vector2(2.5, 0), 1.2, Color(0.1, 0.1, 0.1))
		else:
			draw_circle(head + Vector2(side * 3.5, 0), 1.2, Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(head + Vector2(-7.5, -8), Vector2(15, 5.5)), jersey)
	draw_circle(head + Vector2(0, -4), 6.0, jersey)
	var brim := Vector2(side * 8.0, -2.5) if side != 0.0 else Vector2(0, -1.5)
	if not away:
		draw_line(head + Vector2(-5 + side * 3, -3), head + brim + Vector2(side * 2, 0), dark, 3.0)
	if mode == BATTER:
		_draw_bat((l_hand + r_hand) / 2.0)
