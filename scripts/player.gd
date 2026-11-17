extends Node2D
# One baseball player. Depending on mode it is a fielder, the batter at the plate, or a base runner.
# The game manager (main.gd) decides where fielders go and when runners advance; this script moves them.

enum { OFF, FIELDER, BATTER, RUNNER }

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

func setup(g, t: int, i: int, tex: Texture2D) -> void:
	game = g
	team = t
	role = i
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(1.7, 1.7)
	add_child(sprite)
	z_index = 5
	home_spot = game.POSITIONS[i] * game.FT
	visible = false

func is_safe() -> bool:
	return on_base >= 1 and seg_t <= 0.0 and run_delay <= 0.0

func update(delta: float, human: bool, input_vec: Vector2) -> void:
	catch_cooldown = maxf(0.0, catch_cooldown - delta)
	match mode:
		FIELDER:
			_fielder_update(delta, human, input_vec)
		RUNNER:
			if game.phase == game.LIVE:
				_runner_update(delta)
		BATTER:
			if swing_t >= 0.0:
				swing_t += delta
	sprite.rotation = facing
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
	var step: float = game.RUN_SPEED * delta / a.distance_to(b)
	if goal > on_base:
		if not (halfway and seg_t >= 0.25):
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
	# team colored disc under the sprite so the two teams are easy to tell apart
	var col := Color(0.2, 0.45, 1.0, 0.7) if team == 0 else Color(0.95, 0.2, 0.15, 0.7)
	draw_circle(Vector2.ZERO, 16.0, col)
	if game.is_human(self):
		draw_arc(Vector2.ZERO, 21.0, 0, TAU, 32, Color(1, 0.9, 0.2), 3.5)
		var tri := PackedVector2Array([Vector2(-8, -46), Vector2(8, -46), Vector2(0, -35)])
		draw_colored_polygon(tri, Color(1, 0.9, 0.2))
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
	if mode == BATTER:
		# the bat: cocked back, swept through the zone on a swing, squared up for a bunt
		var a := 2.0
		if bunting:
			a = -0.15
		elif swing_t >= 0.0:
			a = lerpf(2.0, -2.8, minf(1.0, swing_t / 0.24))
		var pivot := Vector2(5, 5)
		draw_line(pivot, pivot + Vector2.from_angle(a) * 26.0, Color(0.55, 0.35, 0.15), 5.0)
		draw_line(pivot + Vector2.from_angle(a) * 13.0, pivot + Vector2.from_angle(a) * 26.0, Color(0.75, 0.55, 0.3), 6.5)
