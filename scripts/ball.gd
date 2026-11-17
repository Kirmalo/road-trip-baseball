extends Node2D
# The baseball. position = spot on the ground; z = height above the ground (drawn as an upward offset).
# A batted ball follows a flight path that is worked out once at contact (path_p / path_z, 60 samples a second),
# so the fielders can look ahead and run to where they can catch it.

enum { DEAD, HELD, PITCH, LIVE, THROWN }

var game
var state := DEAD
var holder = null
var z := 0.0

# pitch
var pitch_from := Vector2.ZERO
var pitch_to := Vector2.ZERO
var pitch_z_end := 10.0
var pitch_t := 0.0

# batted or loose ball
var path_p := PackedVector2Array()
var path_z := PackedFloat32Array()
var path_bounce := -1      # first sample on the ground
var path_hr := -1          # sample where it cleared the fence on the fly
var live_t := 0.0
var can_fly_out := false   # caught before it touches the ground = out

# throw
var thrower = null
var receiver = null
var throw_from := Vector2.ZERO
var throw_to := Vector2.ZERO
var throw_t := 0.0
var throw_dur := 1.0
var throw_peak := 0.0
var trail: Array = []      # recent drawn positions of a batted ball (world space)

func setup(g) -> void:
	game = g
	z_index = 20

func hold(p) -> void:
	state = HELD
	holder = p
	receiver = null
	p.hold_timer = 0.0
	p.think_timer = 0.0
	p.running_to_base = false

func make_dead() -> void:
	state = DEAD
	holder = null
	receiver = null

func start_pitch(from: Vector2, to: Vector2, z_end: float) -> void:
	state = PITCH
	holder = null
	pitch_from = from
	pitch_to = to
	pitch_z_end = z_end
	pitch_t = 0.0
	position = from

func launch(from: Vector2, z0: float, v: Vector2, vz: float, fly_out_ok: bool, fair := true) -> void:
	state = LIVE
	holder = null
	receiver = null
	live_t = 0.0
	can_fly_out = fly_out_ok
	_simulate(from, z0, v, vz, fair)
	position = from
	z = z0

func throw_ball(from_p, to_p, to: Vector2) -> void:
	state = THROWN
	thrower = from_p
	receiver = to_p
	holder = null
	throw_from = from_p.position
	throw_to = to
	throw_t = 0.0
	var d := throw_from.distance_to(to)
	throw_dur = maxf(0.15, d / game.THROW_SPEED)
	throw_peak = d * 0.05
	can_fly_out = false

func deflect() -> void:
	# a bobble: the ball squirts away from the fielder
	var dir := Vector2.from_angle(game.rng.randf_range(-PI, PI))
	launch(position, minf(z, 3.0 * game.FT), dir * game.rng.randf_range(10.0, 25.0) * game.FT, 4.0 * game.FT, false)

func index_now() -> int:
	return mini(int(live_t * 60.0), path_p.size() - 1)

func has_bounced() -> bool:
	return path_bounce >= 0 and index_now() >= path_bounce

func speed_now() -> float:
	if state != LIVE:
		return 0.0
	var i := index_now()
	if i + 1 >= path_p.size():
		return 0.0
	return path_p[i].distance_to(path_p[i + 1]) * 60.0

func _simulate(p0: Vector2, z0: float, v0: Vector2, vz0: float, fair: bool) -> void:
	path_p = PackedVector2Array()
	path_z = PackedFloat32Array()
	path_bounce = -1
	path_hr = -1
	var p := p0
	var zz := z0
	var v := v0
	var vz := vz0
	var dt := 1.0 / 60.0
	var FT: float = game.FT
	var g: float = game.GRAVITY
	var after_hr := 0
	for i in 1200:
		path_p.append(p)
		path_z.append(zz)
		if path_hr >= 0:
			after_hr += 1
			if after_hr > 90:
				break
		elif zz <= 0.0 and vz == 0.0 and v.length() < 1.0:
			break
		if zz > 0.0 or vz > 0.0:
			vz -= g * dt
			zz += vz * dt
			if zz <= 0.0:
				zz = 0.0
				if path_bounce < 0 and path_hr < 0:   # a home run never "lands" for the fielders
					path_bounce = i + 1
				vz = -vz * 0.38
				v *= 0.72
				if vz < 5.0 * FT:
					vz = 0.0
		else:
			# rolling on the grass
			var sp := maxf(0.0, v.length() - 24.0 * FT * dt)
			v = v.normalized() * sp
		p += v * dt
		# outfield wall and the walls around foul territory
		var fr: float = game.fence_radius(p)
		if path_hr < 0 and p.length() >= fr:
			var ang := absf(atan2(p.x, -p.y))
			if fair and path_bounce < 0 and zz > game.FENCE_H and ang <= PI / 4.0:
				path_hr = i + 1
			else:
				var n := p.normalized()
				v = (v - 2.0 * v.dot(n) * n) * 0.35
				p = n * (fr - 2.0)

func update(delta: float) -> void:
	var FT: float = game.FT
	match state:
		HELD:
			if holder != null:
				position = holder.position + Vector2.from_angle(holder.facing) * 7.0
				z = 4.0 * FT
		PITCH:
			position = pitch_from.lerp(pitch_to, pitch_t)
			z = lerpf(6.0 * FT, pitch_z_end, pitch_t) + sin(pitch_t * PI) * 1.2 * FT
		LIVE:
			live_t += delta
			var i := index_now()
			position = path_p[i]
			z = path_z[i]
		THROWN:
			throw_t += delta / throw_dur
			if throw_t >= 1.0:
				# nobody caught it: it drops and rolls on
				var dir := (throw_to - throw_from).normalized()
				launch(throw_to, 4.0 * FT, dir * 18.0 * FT, 0.0, false)
				return
			position = throw_from.lerp(throw_to, throw_t)
			z = 5.0 * FT + 4.0 * throw_peak * throw_t * (1.0 - throw_t)
		DEAD:
			z = maxf(0.0, z - 60.0 * delta)
	if state == LIVE and speed_now() > 15.0 * FT:
		trail.append(position + Vector2(0, -z * 0.35))
		if trail.size() > 14:
			trail.pop_front()
	elif not trail.is_empty():
		trail.pop_front()
	queue_redraw()

func _draw() -> void:
	var FT: float = game.FT
	# trail behind a hit ball
	for i in range(1, trail.size()):
		var a: float = float(i) / trail.size()
		draw_line(trail[i - 1] - position, trail[i] - position, Color(1, 1, 1, 0.45 * a), 2.0 + 4.0 * a)
	# shadow on the ground
	draw_set_transform(Vector2(0, 1.5), 0, Vector2(1, 0.55))
	draw_circle(Vector2.ZERO, maxf(3.0, 6.0 - z / (30.0 * FT)), Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# the ball, lifted by its height (squashed so high flies stay on screen)
	var c := Vector2(0, -z * 0.35)
	var r := 4.2 + z / (22.0 * FT)
	draw_circle(c, r + 0.9, Color(0.1, 0.1, 0.1, 0.8))
	draw_circle(c, r, Color(0.98, 0.97, 0.92))
	if r > 3.2:
		draw_arc(c + Vector2(-r * 0.9, 0), r * 0.7, -0.9, 0.9, 8, Color(0.85, 0.1, 0.1), 1.0)
		draw_arc(c + Vector2(r * 0.9, 0), r * 0.7, PI - 0.9, PI + 0.9, 8, Color(0.85, 0.1, 0.1), 1.0)
