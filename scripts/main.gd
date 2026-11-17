extends Node2D
# Road Trip Baseball: arcade baseball for a touch screen.
# You are BLUE, the road team, so you bat first (the top of each inning). RED bats in the bottom.
#
# Touch: drag anywhere on the left half of the screen to steer.
#   Batting:  steer the yellow circle over the incoming pitch in the zone panel and tap SWING at the right
#             moment (B = BUNT). While the ball is in play: GO sends runners for an extra base, HOLD keeps them.
#   Pitching: steer the red crosshair, then tap FAST (fastball) or CHANGE (slower changeup).
#   Fielding: the fielder with the yellow ring runs to the ball by himself unless you steer him.
#             With the ball: push toward a base and tap THROW. No direction = throw for the best out.
# Keyboard (for testing): WASD/arrows steer, J = A button, K = B button.

const PlayerScript = preload("res://scripts/player.gd")
const BallScript = preload("res://scripts/ball.gd")
const FieldScript = preload("res://scripts/field.gd")
const ControlsScript = preload("res://scripts/touch_controls.gd")
const HudScript = preload("res://scripts/hud.gd")

const FT := 4.0                       # pixels per foot
const INNINGS := 3                    # innings per game (change to make games longer)
const MAX_INNINGS := 12               # a tie after this many innings stays a tie
const HUMAN_TEAM := 0
const TEAM_NAMES := ["BLUE", "RED"]

const RUN_SPEED := 27.0 * FT          # base runners, feet per second times FT
const FIELD_SPEED := 24.0 * FT
const FIELD_ACCEL := 28.0 * FT        # fielders need a moment to get up to speed
const FIELD_REACT := 0.25             # seconds before a fielder reacts to a batted ball
const THROW_SPEED := 100.0 * FT
const GRAVITY := 32.0 * FT
const REACH := 4.0 * FT               # how close a fielder must be to catch the ball
const CATCH_Z := 9.0 * FT             # and how low it must be
const TAG_DIST := 4.5 * FT
const FENCE_H := 10.0 * FT
const BASE_DIST := 90.0 * FT
const MOUND := Vector2(0, -60.5 * FT)

const SWING_DELAY := 0.12             # seconds from pressing SWING to the bat reaching the plate
const TIMING_WINDOW := 0.13           # how early or late you can be and still hit it
const CONTACT_R := 0.42               # size of the bat circle, in strike zone half-widths

enum { PRE_PITCH, PITCHING, LIVE, PAUSE, OVER }
enum { RUN_AUTO, RUN_GO, RUN_HOLD }
const FASTBALL := 0
const CHANGEUP := 1

# fielding spots in feet: P, C, 1B, 2B, SS, 3B, LF, CF, RF
const POS_NAMES := ["P", "C", "1B", "2B", "SS", "3B", "LF", "CF", "RF"]
const POSITIONS := [Vector2(0, -58), Vector2(0, 7), Vector2(58, -86), Vector2(28, -132), Vector2(-28, -132),
	Vector2(-58, -86), Vector2(-140, -235), Vector2(0, -285), Vector2(140, -235)]

var rng := RandomNumberGenerator.new()
var players: Array = []
var teams := [[], []]
var ball
var controls
var hud
var camera: Camera2D
var autoplay := false
var humantest := false
var stats := {}

var score := [0, 0]
var hits := [0, 0]
var inning := 1
var top := true
var batting := 0
var fielding := 1
var outs := 0
var balls := 0
var strikes := 0
var lineup := [0, 0]
var batter = null
var batter_runner = null
var runners: Array = []

var phase := PAUSE
var pause_timer := 0.0
var after_pause := ""
var game_over := false
var cam_follow := false

# the current pitch
var pitch_type := FASTBALL
var pitch_loc := Vector2.ZERO          # where it crosses the plate, in strike zone half-widths (y down)
var pitch_dur := 0.85
var pitch_mph := 90
var pitch_clock := 0.0
var pre_timer := 0.0
var aim := Vector2.ZERO
var cursor := Vector2.ZERO
var swung := false
var contact_at := -1.0
var contact_te := 0.0
var contact_d := Vector2.ZERO
var contact_bunt := false
var cpu_swing_at := -1.0
var cpu_cursor := Vector2.ZERO
var zone_show := 0.0

# the ball in play
var play_timer := 0.0
var chase_timer := 0.0
var chaser = null
var chase_point := Vector2.ZERO
var chase_eta := 0.0
var chase_calc_time := 0.0
var chase_catch_fly := false
var cover: Array = []
var second_cover := 3
var run_mode := RUN_AUTO
var hr_called := false
var settle_timer := 0.0
var runs_this_play := 0
var outs_this_play := 0
var error_this_play := false
var human_fielder = null

var score_label: Label
var inning_label: Label
var batter_label: Label
var msg_label: Label
var msg_timer := 0.0

func stat(k: String) -> void:
	stats[k] = stats.get(k, 0) + 1

# ---------------- setup ----------------

func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	autoplay = args.has("--autoplay")
	humantest = args.has("--humantest")

	var field = FieldScript.new()
	field.game = self
	field.z_index = -10
	add_child(field)

	for t in 2:
		for i in 9:
			var p = PlayerScript.new()
			var color := "blue" if t == 0 else "red"
			p.setup(self, t, i, load("res://assets/%s_%d.png" % [color, i % 5 + 1]))
			add_child(p)
			players.append(p)
			teams[t].append(p)

	ball = BallScript.new()
	ball.setup(self)
	add_child(ball)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)
	camera.position = Vector2(0, -34 * FT)
	add_child(camera)
	camera.make_current()

	_build_hud()
	_start_half()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.55)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 54
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	hud = HudScript.new()
	hud.game = self
	root.add_child(hud)

	score_label = _make_label(root, 30, Control.PRESET_TOP_WIDE, 8)
	inning_label = _make_label(root, 22, Control.PRESET_TOP_LEFT, 14)
	inning_label.offset_left = 20
	inning_label.offset_right = 360
	inning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	batter_label = _make_label(root, 18, Control.PRESET_TOP_LEFT, 64)
	batter_label.offset_left = 20
	batter_label.offset_right = 420
	batter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	msg_label = _make_label(root, 44, Control.PRESET_CENTER, 0)
	msg_label.offset_left = -500
	msg_label.offset_right = 500
	msg_label.offset_top = -200
	msg_label.offset_bottom = -100

	controls = ControlsScript.new()
	root.add_child(controls)
	controls.a_pressed.connect(_on_a_pressed)
	controls.b_pressed.connect(_on_b_pressed)
	if autoplay:
		controls.visible = false

func _make_label(parent: Control, size: int, preset: int, top_px: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.offset_top = top_px
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 0.8)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# ---------------- field helpers ----------------

func base_pos(b: int) -> Vector2:
	match b % 4:
		1:
			return Vector2(63.64, -63.64) * FT
		2:
			return Vector2(0, -127.28) * FT
		3:
			return Vector2(-63.64, -63.64) * FT
	return Vector2.ZERO

func fence_radius(p: Vector2) -> float:
	# distance from home plate to the wall in the direction of p
	var a := absf(atan2(p.x, -p.y))
	if a <= PI / 4.0:
		return (290.0 + 50.0 * cos(2.0 * a)) * FT
	return minf(290.0, 35.0 / maxf(sin(a - PI / 4.0), 0.01)) * FT

func base_occupied(b: int) -> bool:
	for r in runners:
		if r.on_base == b and r.mode == PlayerScript.RUNNER:
			return true
	return false

func human_batting() -> bool:
	return not autoplay and batting == HUMAN_TEAM

func human_pitching() -> bool:
	return not autoplay and fielding == HUMAN_TEAM

func is_human(p) -> bool:
	return not autoplay and phase == LIVE and p.team == HUMAN_TEAM and p == human_fielder and fielding == HUMAN_TEAM

func _in_zone(l: Vector2) -> bool:
	return absf(l.x) <= 1.0 and absf(l.y) <= 1.0

func _gauss2(sd: float) -> Vector2:
	return Vector2(rng.randfn(0.0, sd), rng.randfn(0.0, sd))

func _pitcher():
	return teams[fielding][0]

func _catcher():
	return teams[fielding][1]

# ---------------- innings and batters ----------------

func _start_half() -> void:
	batting = 0 if top else 1
	fielding = 1 - batting
	outs = 0
	for r in runners:
		r.mode = PlayerScript.OFF
		r.visible = false
	runners.clear()
	for p in teams[fielding]:
		p.mode = PlayerScript.FIELDER
		p.visible = true
		p.position = p.home_spot
		p.target = p.home_spot
		p.velocity = Vector2.ZERO
	for p in teams[batting]:
		p.mode = PlayerScript.OFF
		p.visible = false
	ball.hold(_pitcher())
	_new_batter()
	show_message("%s OF THE %s\n%s BATTING" % ["TOP" if top else "BOTTOM", _ordinal(inning), TEAM_NAMES[batting]], 1.8)
	phase = PAUSE
	pause_timer = 1.8
	after_pause = "pitch"

func _ordinal(n: int) -> String:
	if n == 1:
		return "1ST"
	if n == 2:
		return "2ND"
	if n == 3:
		return "3RD"
	return "%dTH" % n

func _new_batter() -> void:
	batter = teams[batting][lineup[batting]]
	lineup[batting] = (lineup[batting] + 1) % 9
	batter.mode = PlayerScript.BATTER
	batter.visible = true
	batter.position = Vector2(-3.6 * FT, 0)
	batter.facing = 0.0
	batter.swing_t = -1.0
	batter.bunting = false
	batter.trot = false
	balls = 0
	strikes = 0

func _begin_pitch() -> void:
	phase = PRE_PITCH
	cam_follow = false
	pre_timer = rng.randf_range(0.9, 1.5)
	aim = Vector2.ZERO
	cursor = Vector2.ZERO
	swung = false
	contact_at = -1.0
	cpu_swing_at = -1.0
	zone_show = 0.0
	batter.swing_t = -1.0
	batter.bunting = false
	batter.position = Vector2(-3.6 * FT, 0)
	batter.facing = 0.0
	for f in teams[fielding]:
		f.position = f.home_spot
		f.target = f.home_spot
		f.velocity = Vector2.ZERO
		f.running_to_base = false
		f.facing = (Vector2(0, -30 * FT) - f.position).angle()
	_pitcher().facing = PI / 2
	_catcher().facing = -PI / 2
	for r in runners:
		r.seg_t = 0.0
		r.goal = r.on_base
		r.position = base_pos(r.on_base)
		r.facing = (base_pos(r.on_base + 1) - r.position).angle()
	ball.hold(_pitcher())

func _end_half() -> void:
	phase = PAUSE
	if autoplay or humantest:
		print("End of %s %d: BLUE %d - RED %d" % ["top" if top else "bottom", inning, score[0], score[1]])
	show_message("3 OUTS\nSIDE RETIRED", 1.8)
	pause_timer = 1.9
	after_pause = "half"

func _next_half() -> void:
	if top:
		if inning >= INNINGS and score[1] > score[0]:
			_game_end()
			return
		top = false
	else:
		if (inning >= INNINGS and score[0] != score[1]) or inning >= MAX_INNINGS:
			_game_end()
			return
		inning += 1
		top = true
	_start_half()

func _check_walk_off() -> bool:
	if not top and inning >= INNINGS and score[1] > score[0]:
		_game_end()
		return true
	return false

func _game_end() -> void:
	game_over = true
	phase = OVER
	ball.make_dead()
	var result := "TIE GAME"
	if score[0] != score[1]:
		result = "%s WINS!" % ("BLUE" if score[0] > score[1] else "RED")
	show_message("FINAL   BLUE %d - %d RED\n%s   Tap to play again" % [score[0], score[1], result], 9999.0)
	if autoplay or humantest:
		print("FINAL BLUE %d - RED %d  (hits %d - %d, innings %d)" % [score[0], score[1], hits[0], hits[1], inning])
		print(stats)
		get_tree().quit()

# ---------------- pitching and hitting ----------------

func _throw_pitch(type: int) -> void:
	if phase != PRE_PITCH:
		return
	pitch_type = type
	if human_pitching():
		pitch_loc = aim + _gauss2(0.14)
	else:
		pitch_loc = _cpu_pitch_target()
	if type == FASTBALL:
		pitch_dur = rng.randf_range(0.8, 0.9)
		pitch_mph = int(lerpf(95.0, 88.0, (pitch_dur - 0.8) / 0.1))
	else:
		pitch_dur = rng.randf_range(1.05, 1.15)
		pitch_mph = int(lerpf(82.0, 76.0, (pitch_dur - 1.05) / 0.1))
	pitch_clock = 0.0
	ball.start_pitch(MOUND + Vector2(-1.5 * FT, 3.0 * FT), Vector2(pitch_loc.x * 0.8 * FT, -0.8 * FT), (2.5 - pitch_loc.y) * FT)
	phase = PITCHING
	stat("pitches")
	if not human_batting():
		_plan_cpu_swing()

func _cpu_pitch_target() -> Vector2:
	var strike_chance := 0.5
	if balls == 3:
		strike_chance = 0.8
	if rng.randf() < strike_chance:
		return Vector2(rng.randf_range(-0.85, 0.85), rng.randf_range(-0.85, 0.85)) + _gauss2(0.1)
	return Vector2(rng.randf_range(-1.45, 1.45), rng.randf_range(-1.45, 1.45))

func _plan_cpu_swing() -> void:
	var p := 0.06
	if _in_zone(pitch_loc):
		p = 0.68
	elif absf(pitch_loc.x) < 1.35 and absf(pitch_loc.y) < 1.35:
		p = 0.28
	if strikes == 2:
		p += 0.15
	if rng.randf() >= p:
		return
	var te := rng.randfn(0.0, 0.07)
	if pitch_type == CHANGEUP:
		te += 0.05   # fooled a little: out in front
	cpu_swing_at = maxf(0.05, pitch_dur - SWING_DELAY - te)
	cpu_cursor = pitch_loc + _gauss2(0.24)

func _start_swing(cur: Vector2, bunt: bool) -> void:
	if swung or phase != PITCHING:
		return
	swung = true
	batter.bunting = bunt
	if not bunt:
		batter.swing_t = 0.0
	stat("swings")
	var te := pitch_dur - (pitch_clock + SWING_DELAY)     # > 0 early, < 0 late
	var window := 0.25 if bunt else TIMING_WINDOW
	var r := 0.6 if bunt else CONTACT_R
	var d := pitch_loc - cur
	if absf(te) <= window and d.length() <= r:
		contact_at = pitch_clock + SWING_DELAY
		contact_te = te
		contact_d = d
		contact_bunt = bunt

func _resolve_contact() -> void:
	var window := 0.25 if contact_bunt else TIMING_WINDOW
	var r := 0.6 if contact_bunt else CONTACT_R
	var q_time := 1.0 - absf(contact_te) / window
	var q_aim := 1.0 - contact_d.length() / r
	var quality := clampf(q_aim * 0.55 + q_time * 0.45, 0.0, 1.0)
	var speed: float
	var launch: float
	var spray: float
	if contact_bunt:
		speed = rng.randf_range(20.0, 34.0)
		launch = rng.randf_range(-14.0, -4.0)
		spray = -contact_te / window * 25.0 + rng.randf_range(-12.0, 12.0)
	else:
		speed = 52.0 + 75.0 * quality + rng.randf_range(-6.0, 6.0)
		launch = 20.0 - contact_d.y / r * 40.0 + rng.randf_range(-7.0, 7.0)
		spray = -contact_te / window * 55.0 + rng.randf_range(-8.0, 8.0)   # early = pulled to left field
	var fair := absf(spray) <= 45.0
	var dir := Vector2(sin(deg_to_rad(spray)), -cos(deg_to_rad(spray)))
	var lr := deg_to_rad(launch)
	if OS.get_cmdline_user_args().has("--debug"):
		print("contact q=%.2f speed=%d launch=%d spray=%d" % [quality, speed, launch, spray])
	var from: Vector2 = ball.position
	ball.launch(from, 3.0 * FT, dir * speed * FT * cos(lr), speed * FT * sin(lr), fair, fair)
	cam_follow = true
	stat("contact")
	if not fair:
		stat("fouls")
		phase = PAUSE
		if contact_bunt and strikes == 2:
			show_message("FOUL BUNT - STRIKE THREE", 1.3)
			stat("k")
			_batter_out_no_play()
			return
		show_message("FOUL BALL", 1.0)
		if strikes < 2:
			strikes += 1
		pause_timer = 1.4
		after_pause = "pitch"
		return
	second_cover = 4 if spray > 0.0 else 3
	_start_play()

func _pitch_result() -> void:
	phase = PAUSE
	zone_show = 1.2
	ball.hold(_catcher())
	pause_timer = 1.0
	after_pause = "pitch"
	if swung or _in_zone(pitch_loc):
		strikes += 1
		if strikes >= 3:
			stat("k")
			show_message("STRIKEOUT!", 1.3)
			_batter_out_no_play()
			return
		show_message("SWING AND A MISS" if swung else "STRIKE", 0.9)
	else:
		balls += 1
		stat("balls")
		if balls >= 4:
			_walk()
			return
		show_message("BALL", 0.9)

func _batter_out_no_play() -> void:
	outs += 1
	batter.mode = PlayerScript.OFF
	batter.visible = false
	if outs >= 3:
		_end_half()
	else:
		pause_timer = 1.4
		after_pause = "batter"

func _walk() -> void:
	stat("bb")
	show_message("BALL FOUR - WALK", 1.2)
	var occ := [null, null, null, null]
	for r in runners:
		occ[r.on_base] = r
	if occ[1] != null:
		if occ[2] != null:
			if occ[3] != null:
				_score_runner(occ[3])
			_place_runner(occ[2], 3)
		_place_runner(occ[1], 2)
	batter.mode = PlayerScript.RUNNER
	runners.append(batter)
	_place_runner(batter, 1)
	phase = PAUSE
	pause_timer = 1.3
	after_pause = "batter"
	_check_walk_off()

func _place_runner(r, b: int) -> void:
	r.on_base = b
	r.seg_t = 0.0
	r.goal = b
	r.forced = false
	r.retouch = false
	r.position = base_pos(b)

func _score_runner(r) -> void:
	score[batting] += 1
	runs_this_play += 1
	stat("runs")
	runners.erase(r)
	r.mode = PlayerScript.OFF
	r.visible = false
	if not hr_called:
		show_message("%s SCORES!" % TEAM_NAMES[batting], 1.0)

# ---------------- the ball in play ----------------

func _start_play() -> void:
	phase = LIVE
	play_timer = 0.0
	chase_timer = 0.0
	runs_this_play = 0
	outs_this_play = 0
	error_this_play = false
	run_mode = RUN_AUTO
	hr_called = false
	settle_timer = 0.0
	chaser = null
	stat("in_play")
	var occ := [false, false, false, false]
	for r in runners:
		occ[r.on_base] = true
	for r in runners:
		var b: int = r.on_base
		var f := true
		for k in range(1, b + 1):
			if not occ[k]:
				f = false
		r.forced = f
		r.goal = b + 1 if f else b
		r.keep_going = false
		r.seg_t = 0.08 if f or outs == 2 else 0.0   # secondary lead
		r.start_base = b
		r.retouch = false
		r.trot = false
		r.halfway = false
		r.run_delay = 0.0
	batter.mode = PlayerScript.RUNNER
	batter.on_base = 0
	batter.seg_t = 0.0
	batter.goal = 1
	batter.forced = true
	batter.retouch = false
	batter.trot = false
	batter.halfway = false
	batter.keep_going = false
	batter.start_base = 0
	batter.run_delay = 0.35
	batter.swing_t = -1.0
	batter.bunting = false
	batter_runner = batter
	runners.append(batter)
	_pitcher().catch_cooldown = 0.45   # still in his follow-through

func _live_update(delta: float) -> void:
	play_timer += delta
	chase_timer -= delta
	if chase_timer <= 0.0:
		chase_timer = 0.15
		_update_chase()
		_runner_decisions()
	if ball.state == BallScript.HELD and ball.holder != null and ball.holder.team == fielding:
		human_fielder = ball.holder
	elif ball.state == BallScript.THROWN:
		human_fielder = ball.receiver
	elif ball.state == BallScript.LIVE:
		human_fielder = chaser
	_assign_fielder_targets()
	_check_home_run()
	_check_catches()
	if phase != LIVE:
		return
	_holder_logic(delta)
	_check_outs()
	if phase != LIVE:
		return
	_check_play_over(delta)

func _intercept(f) -> Array:
	# earliest moment this fielder can be where the ball is, low enough to catch
	var n: int = ball.path_p.size()
	var i0: int = ball.index_now()
	var k := i0
	while k < n:
		var t := float(k - i0) / 60.0
		if ball.path_z[k] < CATCH_Z:
			var pk: Vector2 = ball.path_p[k]
			var need := run_time(maxf(0.0, f.position.distance_to(pk) - REACH * 0.7)) + FIELD_REACT
			if need <= t:
				return [t, pk]
		k += 3
	var last: Vector2 = ball.path_p[n - 1]
	var t_end := maxf(float(n - 1 - i0) / 60.0, run_time(f.position.distance_to(last)) + FIELD_REACT)
	return [t_end, last]

func run_time(d: float) -> float:
	# time for a fielder starting from a standstill to cover d pixels
	var ramp := FIELD_SPEED * FIELD_SPEED / (2.0 * FIELD_ACCEL)
	if d < ramp:
		return sqrt(2.0 * d / FIELD_ACCEL)
	return FIELD_SPEED / FIELD_ACCEL + (d - ramp) / FIELD_SPEED

func _update_chase() -> void:
	if ball.state != BallScript.LIVE or hr_called:
		chaser = null
		return
	var best = null
	var best_s := INF
	var best_t := INF
	var best_p := Vector2.ZERO
	for f in teams[fielding]:
		if f.catch_cooldown > 0.3:
			continue
		var res: Array = _intercept(f)
		var t: float = res[0]
		var s := t - (0.3 if f == chaser else 0.0)
		if s < best_s:
			best_s = s
			best_t = t
			best_p = res[1]
			best = f
	chaser = best
	chase_point = best_p
	chase_eta = best_t
	chase_catch_fly = ball.path_bounce < 0 or ball.index_now() + int(best_t * 60.0) < ball.path_bounce
	chase_calc_time = play_timer

func _coverage() -> Array:
	# who covers each base (index 0 = home)
	var f: Array = teams[fielding]
	var busy = chaser
	if ball.state == BallScript.HELD:
		busy = ball.holder
	var c := [f[1], f[2], f[second_cover], f[5]]
	if c[1] == busy:
		c[1] = f[0]
	if c[2] == busy:
		c[2] = f[7 - second_cover]
	if c[3] == busy:
		c[3] = f[4] if c[2] != f[4] else f[0]
	if c[0] == busy:
		c[0] = f[0]
	return c

func _assign_fielder_targets() -> void:
	cover = _coverage()
	for f in teams[fielding]:
		if ball.state == BallScript.HELD and f == ball.holder:
			if not f.running_to_base:
				f.target = f.position
			continue
		if ball.state == BallScript.THROWN and f == ball.receiver:
			f.target = ball.throw_to
			continue
		if ball.state == BallScript.LIVE and f == chaser:
			f.target = chase_point
			continue
		var b := cover.find(f)
		if b >= 0:
			f.target = base_pos(b)
		elif f.role >= 6:
			f.target = f.home_spot.lerp(ball.position, 0.4)
		else:
			f.target = f.home_spot

func _check_home_run() -> void:
	if hr_called or ball.state != BallScript.LIVE or ball.path_hr < 0:
		return
	if ball.index_now() < ball.path_hr:
		return
	hr_called = true
	chaser = null
	stat("hr")
	hits[batting] += 1
	show_message("HOME RUN!", 2.0)
	for r in runners:
		r.trot = true
		r.forced = false
		r.retouch = false
		r.halfway = false
		r.goal = r.on_base + 1

func _check_catches() -> void:
	if hr_called:
		return
	if ball.state == BallScript.LIVE:
		var fly: bool = ball.can_fly_out and not ball.has_bounced()
		for f in teams[fielding]:
			if f.catch_cooldown > 0.0:
				continue
			if f.position.distance_to(ball.position) < REACH and ball.z < CATCH_Z:
				_field_ball(f, fly)
				return
	elif ball.state == BallScript.THROWN:
		var r = ball.receiver
		if r != null and ball.throw_t > 0.5 and r.position.distance_to(ball.position) < REACH:
			ball.hold(r)

func _field_ball(f, fly: bool) -> void:
	var spd: float = ball.speed_now() / FT
	var err := 0.01
	if spd > 85.0 and not fly:
		err = 0.04
	if rng.randf() < err:
		f.catch_cooldown = 0.8
		ball.deflect()
		error_this_play = true
		stat("errors")
		show_message("ERROR!", 0.9)
		return
	ball.hold(f)
	if fly:
		_fly_out()

func _fly_out() -> void:
	if OS.get_cmdline_user_args().has("--debug"):
		print("   flyout by %s at %d ft, t=%.1f" % [POS_NAMES[ball.holder.role], ball.position.length() / FT, play_timer])
	stat("flyouts")
	show_message("CAUGHT! OUT", 1.0)
	_remove_runner(batter_runner)
	batter_runner = null
	outs += 1
	outs_this_play += 1
	if outs >= 3:
		_end_half()
		return
	# everyone else has to get back to where they started
	for r in runners:
		r.forced = false
		r.halfway = false
		if r.on_base > r.start_base:
			r.on_base = r.start_base
			r.seg_t = 1.0
		if r.seg_t > 0.0:
			r.retouch = true
		r.goal = r.on_base

func _remove_runner(r) -> void:
	if r == null:
		return
	runners.erase(r)
	r.mode = PlayerScript.OFF
	r.visible = false

func on_runner_reached(r) -> void:
	if r.on_base >= 4:
		_score_runner(r)
		return
	_decide_runner(r, _fly_danger())

func _runner_time_to(r, b: int) -> float:
	if b == r.on_base + 1:
		return (1.0 - r.seg_t) * BASE_DIST / RUN_SPEED + r.run_delay
	return r.seg_t * BASE_DIST / RUN_SPEED

func _defense_time(target: Vector2) -> float:
	# how soon the defense could have the ball at this spot
	if ball.state == BallScript.HELD:
		var h = ball.holder
		if h == null or h.team != fielding:
			return INF
		var d: float = h.position.distance_to(target)
		return minf(d / FIELD_SPEED, d / THROW_SPEED + 0.35) + maxf(0.0, _release_time(h) - h.hold_timer)
	if ball.state == BallScript.THROWN:
		var rem: float = (1.0 - ball.throw_t) * ball.throw_dur
		var d2: float = ball.throw_to.distance_to(target)
		if d2 < 5.0 * FT:
			return rem
		return rem + 0.35 + d2 / THROW_SPEED
	if ball.state == BallScript.LIVE and chaser != null:
		var eta := maxf(0.0, chase_eta - (play_timer - chase_calc_time))
		return eta + 0.35 + chase_point.distance_to(target) / THROW_SPEED
	return INF

func _runner_decisions() -> void:
	if hr_called:
		return
	var in_air := _fly_danger()
	var order := runners.duplicate()
	order.sort_custom(func(a, b): return a.on_base + a.seg_t > b.on_base + b.seg_t)
	for r in order:
		_decide_runner(r, in_air)

func _base_taken(b: int, r) -> bool:
	for q in runners:
		if q != r and q.on_base == b and q.goal == b:
			return true
	return false

func _fly_danger() -> bool:
	# a ball in the air that a fielder is going to catch: runners wait near their base to tag up
	if ball.state != BallScript.LIVE or not ball.can_fly_out or ball.has_bounced():
		return false
	if outs == 2:
		return false   # with two outs everybody runs on contact
	return chaser != null and chase_catch_fly

func _decide_runner(r, in_air: bool) -> void:
	r.halfway = false
	if r.trot:
		r.goal = r.on_base + 1
		return
	if r.run_delay > 0.0:
		return
	if r.retouch:
		r.goal = r.on_base
		return
	if r.forced:
		r.goal = r.on_base + 1
		r.halfway = in_air and r != batter_runner
		return
	var next: int = r.on_base + 1
	if in_air:
		r.goal = r.on_base   # wait to see if it is caught (then tag up)
		r.keep_going = false
		return
	var mode := run_mode if human_batting() else RUN_AUTO
	var margin := 0.3
	if mode == RUN_GO:
		margin = -0.25
	if next < 4 and _base_taken(next, r):
		r.goal = r.on_base   # somebody is standing there: go back
		r.keep_going = false
		return
	var run_t := (1.0 - float(r.seg_t)) * BASE_DIST / RUN_SPEED
	if r.goal == next and r.seg_t > 0.5:
		# committed: look one base further, so he can round this base without stopping
		var nn := next + 1
		r.keep_going = nn <= 4 and mode != RUN_HOLD and not (nn < 4 and _base_taken(nn, r)) \
			and _defense_time(base_pos(nn)) > run_t + BASE_DIST / RUN_SPEED + margin
		return
	if r.seg_t <= 0.0 and r.keep_going and mode != RUN_HOLD:
		r.keep_going = false
		r.goal = next
		return
	r.keep_going = false
	if mode == RUN_HOLD:
		r.goal = r.on_base
		return
	r.goal = next if _defense_time(base_pos(next)) > run_t + margin else r.on_base

func _holder_logic(delta: float) -> void:
	if ball.state != BallScript.HELD or hr_called:
		return
	var h = ball.holder
	if h == null or h.team != fielding:
		return
	h.hold_timer += delta
	if is_human(h):
		if h.hold_timer > 3.0:
			_cpu_fielder_play(h, true)   # you dozed off: make the play for you
			h.hold_timer = 0.0
		return
	if h.hold_timer < _release_time(h):
		return
	h.think_timer -= delta
	if h.think_timer > 0.0:
		return
	h.think_timer = 0.15
	_cpu_fielder_play(h, false)

func _release_time(h) -> float:
	return 0.6 if h.role >= 6 else 0.3

func _cpu_fielder_play(h, force_throw: bool) -> void:
	# go for the runner we can beat by the most (lead runners first)
	var best_base := -1
	var best_s := -INF
	for r in runners:
		if r.trot:
			continue
		var b: int
		if r.retouch:
			b = r.on_base
		elif r.forced:
			b = r.on_base + 1
		elif r.goal > r.on_base:
			b = r.goal
		elif not r.is_safe():
			b = r.on_base
		else:
			continue
		var d: float = h.position.distance_to(base_pos(b))
		var ball_t := minf(d / FIELD_SPEED, d / THROW_SPEED + 0.3)
		var m := _runner_time_to(r, b) - ball_t
		if m > 0.05 and m + b * 0.3 > best_s:
			best_s = m + b * 0.3
			best_base = b
	if best_base >= 0:
		_play_on_base(h, best_base)
		return
	# no out to be had: outfielders get the ball back to the infield
	if h.role >= 6 or force_throw:
		var lead := 1
		for r in runners:
			lead = maxi(lead, r.on_base + 1)
		_play_on_base(h, mini(lead, 4) if lead > 1 else 2)

func _play_on_base(h, b: int) -> void:
	var to := base_pos(b)
	var rcv = cover[b % 4] if cover.size() == 4 else null
	if h.position.distance_to(to) < 30.0 * FT or rcv == null or rcv == h:
		h.target = to
		h.running_to_base = true
		return
	_throw_to(h, rcv, to)

func _throw_to(h, rcv, to: Vector2) -> void:
	stat("throws")
	h.catch_cooldown = 0.5
	if rng.randf() < 0.015:
		# wild throw
		var off := Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(20.0, 35.0) * FT
		ball.throw_ball(h, null, to + off)
		error_this_play = true
		stat("errors")
		show_message("WILD THROW!", 0.9)
		return
	ball.throw_ball(h, rcv, to)

func _check_outs() -> void:
	if ball.state != BallScript.HELD or hr_called:
		return
	var h = ball.holder
	if h == null or h.team != fielding:
		return
	for r in runners.duplicate():
		if r.trot:
			continue
		var how := ""
		if r.forced and h.position.distance_to(base_pos(r.on_base + 1)) < 4.0 * FT:
			how = "force"
		elif r.retouch and h.position.distance_to(base_pos(r.on_base)) < 4.0 * FT:
			how = "doubled_off"
		elif not r.is_safe() and h.position.distance_to(r.position) < TAG_DIST:
			how = "tag"
		if how != "":
			_runner_out(r, how)
			if phase != LIVE:
				return

func _runner_out(r, how: String) -> void:
	stat("out_" + how)
	if OS.get_cmdline_user_args().has("--debug"):
		print("   out %s by %s" % [how, POS_NAMES[ball.holder.role]])
	var force_like: bool = how == "force" or r.on_base == 0
	outs += 1
	outs_this_play += 1
	for q in runners:
		if q != r and q.on_base >= r.on_base:
			q.forced = false
	if r == batter_runner:
		batter_runner = null
	_remove_runner(r)
	if outs_this_play >= 3:
		show_message("TRIPLE PLAY!", 1.4)
	elif outs_this_play == 2:
		show_message("DOUBLE PLAY!", 1.2)
	else:
		show_message("OUT!", 0.9)
	if outs >= 3:
		if force_like and runs_this_play > 0:
			score[batting] -= runs_this_play   # runs don't count when the third out is a force out
		_end_half()

func _check_play_over(delta: float) -> void:
	if hr_called:
		if runners.is_empty():
			_end_play()
		return
	var settled: bool = ball.state == BallScript.HELD and ball.holder != null and ball.holder.team == fielding
	if settled:
		for r in runners:
			if not r.is_safe() or r.goal != r.on_base:
				settled = false
	settle_timer = settle_timer + delta if settled else 0.0
	if settle_timer > 0.4 or play_timer > 25.0:
		if play_timer > 25.0:
			for r in runners.duplicate():
				if r.seg_t >= 0.5 or r.on_base == 0:
					r.on_base += 1
					if r.on_base >= 4:
						_score_runner(r)
						continue
				_place_runner(r, r.on_base)
		_end_play()

func _end_play() -> void:
	if OS.get_cmdline_user_args().has("--debug"):
		var st := []
		for r in runners:
			st.append("%d(seg %.2f goal %d)" % [r.on_base, r.seg_t, r.goal])
		print("   end play t=%.1f outs=%d runners=%s ball=%d holder=%s" % [play_timer, outs, str(st), ball.state, POS_NAMES[ball.holder.role] if ball.holder != null else "-"])
	phase = PAUSE
	pause_timer = 1.4
	after_pause = "batter"
	if batter_runner != null and runners.has(batter_runner) and not error_this_play and not hr_called:
		hits[batting] += 1
		stat("hits")
		var names := ["", "SINGLE", "DOUBLE", "TRIPLE"]
		var b: int = clampi(batter_runner.on_base, 1, 3)
		if outs_this_play == 0:
			show_message(names[b] + "!", 1.2)
		stat(names[b].to_lower())
		if OS.get_cmdline_user_args().has("--debug"):
			print("   HIT " + names[b])
	for r in runners:
		r.forced = false
		r.retouch = false
		r.trot = false
		r.halfway = false
		r.goal = r.on_base
		r.start_base = r.on_base
	for f in teams[fielding]:
		f.target = f.home_spot
		f.running_to_base = false
	_check_walk_off()

# ---------------- input ----------------

func _on_a_pressed() -> void:
	if game_over:
		get_tree().reload_current_scene()
		return
	if phase == PRE_PITCH and human_pitching():
		_throw_pitch(FASTBALL)
	elif phase == PITCHING and human_batting():
		_start_swing(cursor, false)
	elif phase == LIVE and human_batting():
		run_mode = RUN_GO
		show_message("GO! GO! GO!", 0.7)
		_runner_decisions()
	elif phase == LIVE and human_pitching() and ball.state == BallScript.HELD and is_human(ball.holder):
		_human_throw()

func _on_b_pressed() -> void:
	if game_over:
		return
	if phase == PRE_PITCH and human_pitching():
		_throw_pitch(CHANGEUP)
	elif phase == PITCHING and human_batting():
		_start_swing(cursor, true)
	elif phase == LIVE and human_batting():
		run_mode = RUN_HOLD
		show_message("HOLD UP!", 0.7)
		_runner_decisions()

func _human_throw() -> void:
	var h = ball.holder
	var v := _input_vector()
	if v.length() < 0.3:
		_cpu_fielder_play(h, true)
		return
	var best := 1
	var best_dot := -INF
	for b in [1, 2, 3, 0]:
		var to: Vector2 = base_pos(b) - h.position
		if to.length() < 6.0 * FT:
			continue
		var dt: float = v.normalized().dot(to.normalized())
		if dt > best_dot:
			best_dot = dt
			best = b
	_play_on_base(h, best)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J or event.keycode == KEY_SPACE:
			_on_a_pressed()
		elif event.keycode == KEY_K:
			_on_b_pressed()

func _input_vector() -> Vector2:
	var v: Vector2 = controls.joystick()
	if humantest:
		v = _humantest_input()
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	return v.limit_length(1.0)

# developer testing only (-- --humantest): a scripted "thumb" that uses every control
func _humantest_input() -> Vector2:
	if phase == PITCHING and human_batting():
		var to := pitch_loc - cursor
		return to.normalized() if to.length() > 0.05 else Vector2.ZERO
	if phase == PRE_PITCH and human_pitching():
		var to2 := Vector2(0.5, 0.3) - aim
		return to2.normalized() if to2.length() > 0.05 else Vector2.ZERO
	return Vector2.ZERO

func _humantest_presses() -> void:
	if phase == PRE_PITCH and human_pitching() and _frame % 50 == 0:
		if rng.randf() < 0.6:
			_on_a_pressed()
		else:
			_on_b_pressed()
	elif phase == PITCHING and human_batting() and not swung and pitch_clock >= pitch_dur - SWING_DELAY - 0.02:
		if _in_zone(pitch_loc) or rng.randf() < 0.03:
			if rng.randf() < 0.08:
				_on_b_pressed()
			else:
				_on_a_pressed()
	elif phase == LIVE:
		if human_pitching() and ball.state == BallScript.HELD and is_human(ball.holder) and ball.holder.hold_timer > 0.4:
			_on_a_pressed()
		if human_batting() and _frame % 150 == 0:
			if rng.randf() < 0.5:
				_on_a_pressed()
			else:
				_on_b_pressed()

# ---------------- main loop ----------------

var _frame := 0

func _debug_screenshots() -> void:
	# developer testing only: run with -- --shots to save screenshots to /tmp
	if OS.get_cmdline_user_args().has("--shots") and _frame % 150 == 0 and _frame > 0:
		get_viewport().get_texture().get_image().save_png("/tmp/baseball_%04d.png" % _frame)
		if _frame >= 3000:
			get_tree().quit()

func _physics_process(delta: float) -> void:
	_frame += 1
	_debug_screenshots()
	_update_message(delta)
	zone_show = maxf(0.0, zone_show - delta)
	var input := _input_vector()
	match phase:
		PRE_PITCH:
			if human_pitching():
				aim = (aim + input * 1.8 * delta).clamp(Vector2(-1.6, -1.6), Vector2(1.6, 1.6))
			else:
				pre_timer -= delta
				if pre_timer <= 0.0:
					_throw_pitch(FASTBALL if rng.randf() < 0.65 else CHANGEUP)
			if human_batting():
				cursor = (cursor + input * 2.6 * delta).clamp(Vector2(-1.5, -1.5), Vector2(1.5, 1.5))
		PITCHING:
			pitch_clock += delta
			ball.pitch_t = minf(1.0, pitch_clock / pitch_dur)
			if human_batting():
				cursor = (cursor + input * 2.6 * delta).clamp(Vector2(-1.5, -1.5), Vector2(1.5, 1.5))
			if cpu_swing_at >= 0.0 and pitch_clock >= cpu_swing_at:
				cpu_swing_at = -1.0
				_start_swing(cpu_cursor, false)
			if contact_at >= 0.0 and pitch_clock >= contact_at:
				contact_at = -1.0
				_resolve_contact()
			elif contact_at < 0.0 and pitch_clock >= pitch_dur:
				_pitch_result()
		LIVE:
			_live_update(delta)
		PAUSE:
			pause_timer -= delta
			if pause_timer <= 0.0:
				match after_pause:
					"pitch":
						_begin_pitch()
					"batter":
						_new_batter()
						_begin_pitch()
					"half":
						_next_half()
	if humantest and not game_over:
		_humantest_presses()
	ball.update(delta)
	for p in players:
		if p.mode != PlayerScript.OFF:
			p.update(delta, is_human(p), input)
	_update_camera(delta)
	_update_hud()

func _update_camera(delta: float) -> void:
	var tgt := Vector2(0, -34 * FT)
	var zm := 1.5
	if hr_called and phase == LIVE:
		tgt = Vector2(0, -64 * FT)
		zm = 0.85
	elif cam_follow:
		tgt = ball.position + Vector2(0, -ball.z * 0.35)
		zm = 0.95
	camera.position = camera.position.lerp(tgt, 1.0 - exp(-5.0 * delta))
	var zz := lerpf(camera.zoom.x, zm, 1.0 - exp(-3.0 * delta))
	camera.zoom = Vector2(zz, zz)

# ---------------- HUD ----------------

func show_message(text: String, time := 1.2) -> void:
	msg_label.text = text
	msg_label.modulate.a = 1.0
	msg_timer = time

func _update_message(delta: float) -> void:
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer < 0.4:
			msg_label.modulate.a = maxf(0.0, msg_timer / 0.4)

func _update_hud() -> void:
	score_label.text = "BLUE  %d   -   %d  RED" % [score[0], score[1]]
	inning_label.text = "%s %d   %s BATTING" % ["TOP" if top else "BOT", inning, TEAM_NAMES[batting]]
	batter_label.text = "AT BAT: %s #%d" % [TEAM_NAMES[batting], batter.role + 1] if batter != null else ""
	var a := "-"
	var b := "-"
	if phase == PRE_PITCH or phase == PITCHING:
		if human_pitching():
			if phase == PRE_PITCH:
				a = "FAST"
				b = "CHANGE"
		elif human_batting():
			a = "SWING"
			b = "BUNT"
	elif phase == LIVE:
		if human_batting():
			a = "GO"
			b = "HOLD"
		elif ball.state == BallScript.HELD and is_human(ball.holder):
			a = "THROW"
	controls.a_text = a
	controls.b_text = b
