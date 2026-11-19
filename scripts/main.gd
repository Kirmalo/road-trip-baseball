extends Node2D
# Road Trip Baseball: arcade baseball for a touch screen.
# You are BLUE, the road team, so you bat first (the top of each inning). RED bats in the bottom.
#
# Touch: the joystick is on the left half of the screen, the buttons on the right.
#   Batting:  tap SWING when the ring around the pitch closes (the zone panel on the right). Hold the stick up
#             while you swing to lift the ball, down to chop it on the ground. B = BUNT.
#             While the ball is in play: GO sends runners for an extra base, HOLD keeps them.
#   Pitching: steer the red crosshair, tap FAST or CHANGE, then tap again to stop the meter in the green.
#   Fielding: fielders run and catch by themselves. When yours has the ball, tap a base button to throw there
#             (the green one is the best play; after a moment he makes that play by himself).
# Keyboard (for testing): WASD/arrows steer, J = A button, K = B button, 1-4 = throw to 1B, 2B, 3B, HOME.

const PlayerScript = preload("res://scripts/player.gd")
const BallScript = preload("res://scripts/ball.gd")
const FieldScript = preload("res://scripts/field.gd")
const ControlsScript = preload("res://scripts/touch_controls.gd")
const HudScript = preload("res://scripts/hud.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
const View = preload("res://scripts/view.gd")
const Ratings = preload("res://scripts/ratings.gd")
const AudioScript = preload("res://scripts/audio.gd")

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
const CPU_WINDOW := 0.135             # CPU batters: how early or late they can be and still hit it
const BUNT_WINDOW := 0.25
const METER_PERIOD := 1.1             # seconds for the pitch meter to sweep across and back
const HOLD_AUTO_TIME := 2.5           # your fielder makes the best play by himself after this long

enum { PRE_PITCH, PITCHING, LIVE, PAUSE, OVER }
enum { RUN_AUTO, RUN_GO, RUN_HOLD }
const FASTBALL := 0
const CHANGEUP := 1
const CURVE := 2
const SLIDER := 3
# how each pitch moves late (zone half-widths at a 60 rating), how much slower it is, how it fools a hitter
const BREAK := [Vector2(0, 0), Vector2(0, 0.35), Vector2(0.25, 0.55), Vector2(0.55, 0.15)]
const SLOWER := [0.0, 0.25, 0.2, 0.08]
const MPH_LESS := [0, 10, 13, 6]
const FOOL := [0.0, 0.05, 0.04, 0.02]
const DIVE_REACH := 9.0 * FT          # a diving fielder can reach this far
const DERBY_OUTS := 10
const RELIEF_AT := 0.5
const TOUCH_LATENCY := 0.03            # touch screens report a tap a little late; a swing counts this much earlier                 # you can bring in a reliever once your pitcher's energy drops below this

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
var world: Node2D          # everything on the field; its scale draws the 3/4 view (see view.gd)
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
var team_data := [{}, {}]              # Ratings.make_team(): "players" (by role) and "staff" (starter + 2 relievers)
var pitcher_idx := [0, 0]              # which of the staff is pitching
var pitch_brk := Vector2.ZERO           # this pitch's late break (zone units), for the panel

# steals, pickoffs and other plays that aren't a ball in play
var special_play := ""                 # "steal" or "pickoff" while one runs as a live play
var special_after := "pitch"
var steal_on := false                  # you pressed STEAL for this pitch
var pickoff_tried := false
var slowmo_left := 0.0

# Home Run Derby
static var next_mode := ""             # "derby": the next scene load starts a derby (survives reload)
var derby := false
var derby_hr := 0
var derby_outs := 0
var derby_last_hr := false
var batter = null
var batter_runner = null
var runners: Array = []

var phase := PAUSE
var pause_timer := 0.0
var after_pause := ""
var game_over := false
var cam_follow := false
var cam_last_pos := Vector2(0, -30 * FT)
var cam_last_zoom := 1.3

# the current pitch
var pitch_type := FASTBALL
var pitch_loc := Vector2.ZERO          # where it crosses the plate, in strike zone half-widths (y down)
var pitch_dur := 0.85
var pitch_mph := 90
var pitch_clock := 0.0
var pre_timer := 0.0
var aim := Vector2.ZERO
var swung := false
var contact_at := -1.0
var contact_te := 0.0
var contact_stick := 0.0               # +1 = stick held up (lift it), -1 = down (chop it)
var contact_bunt := false
var cpu_swing_at := -1.0
var cpu_stick := 0.0
var zone_show := 0.0
var meter_active := false              # your pitch meter is sweeping
var meter_t := 0.0
var meter_pos := -1.0                  # -1..1, 0 = the middle of the green zone
var swing_text := ""                   # EARLY / PERFECT / LATE after your swing
var swing_text_timer := 0.0
var ht_swing_err := 0.0                # --humantest: how far off the scripted swing is

var level := Difficulty.NORMAL
var testing := false
var menu_open := false
var menu: Control
var marker: Node2D
var audio

# feel: hit-stop, camera punch and shake, the exit-speed readout
var hitstop_left := 0.0
var cam_punch := 0.0
var cam_shake := 0.0
var exit_text := ""
var exit_timer := 0.0
var last_phys_usec := 0

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
var robbed_checked := false
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
	derby = args.has("--derby") or next_mode == "derby"
	next_mode = ""
	Engine.time_scale = 1.0
	testing = not args.is_empty()
	level = Difficulty.from_args(args, Difficulty.NORMAL if testing else Difficulty.load_level())
	View.from_args(args)

	audio = AudioScript.new()
	add_child(audio)
	world = Node2D.new()
	world.scale = Vector2(1.0, View.tilt())
	world.y_sort_enabled = true          # nearer players (lower on screen) draw in front
	add_child(world)
	var field = FieldScript.new()
	field.game = self
	field.z_index = -10
	world.add_child(field)
	marker = Node2D.new()
	marker.z_index = 1
	marker.draw.connect(_draw_marker)
	world.add_child(marker)

	for t in 2:
		team_data[t] = Ratings.make_team(t)
		for i in 9:
			var p = PlayerScript.new()
			var color := "blue" if t == 0 else "red"
			p.setup(self, t, i, load("res://assets/%s_%d.png" % [color, i % 5 + 1]))
			world.add_child(p)
			p.set_ratings(team_data[t]["players"][i])
			players.append(p)
			teams[t].append(p)

	ball = BallScript.new()
	ball.setup(self)
	world.add_child(ball)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.3, 1.3)
	camera.position = View.to_screen(Vector2(0, -30 * FT))
	add_child(camera)
	camera.make_current()

	_build_hud()
	if derby:
		_start_derby()
	else:
		_start_half()
		if not testing:
			_open_menu("ROAD TRIP BASEBALL", "PICK A LEVEL")

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
	controls.base_pressed.connect(_on_base_pressed)
	controls.pitch_pressed.connect(_on_pitch_pressed)
	controls.small_pressed.connect(_on_small_pressed)
	if autoplay:
		controls.visible = false

func _open_menu(title: String, sub: String) -> void:
	# the level picker: at the start, and after every game
	menu_open = true
	controls.visible = false
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.add_child(box)
	for t in [[title, 44], [sub, 26]]:
		var l := Label.new()
		l.text = t[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ls := LabelSettings.new()
		ls.font_size = t[1]
		ls.outline_size = 6
		ls.outline_color = Color(0, 0, 0, 0.8)
		l.label_settings = ls
		box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var colors := [Color(0.2, 0.6, 0.3), Color(0.2, 0.45, 0.8), Color(0.75, 0.25, 0.2)]
	for k in 3:
		var b := Button.new()
		b.text = Difficulty.NAMES[k]
		b.custom_minimum_size = Vector2(230, 100)
		b.add_theme_font_size_override("font_size", 32)
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[k]
		sb.set_corner_radius_all(16)
		sb.border_color = Color(1, 0.9, 0.2) if k == level else Color(1, 1, 1, 0.6)
		sb.set_border_width_all(6 if k == level else 2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(_on_level_chosen.bind(k))
		row.add_child(b)
	var hint := Label.new()
	hint.text = "Easy: big timing windows.  Hard: a sharp CPU and tight timing."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var d := Button.new()
	d.text = "HOME RUN DERBY"
	d.custom_minimum_size = Vector2(320, 70)
	d.add_theme_font_size_override("font_size", 26)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.85, 0.55, 0.1)
	dsb.set_corner_radius_all(14)
	dsb.border_color = Color(1, 1, 1, 0.7)
	dsb.set_border_width_all(2)
	d.add_theme_stylebox_override("normal", dsb)
	d.add_theme_stylebox_override("hover", dsb)
	d.add_theme_stylebox_override("pressed", dsb)
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	d.pressed.connect(_on_derby_chosen)
	box.add_child(d)
	controls.get_parent().add_child(menu)

func _on_derby_chosen() -> void:
	audio.play("tap")
	next_mode = "derby"
	get_tree().reload_current_scene()

func _on_level_chosen(k: int) -> void:
	audio.play("tap")
	level = k
	if not testing:
		Difficulty.save_level(k)
	if game_over:
		get_tree().reload_current_scene()
		return
	menu_open = false
	menu.queue_free()
	menu = null
	controls.visible = not autoplay

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
	special_play = ""
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
	if inning == 1 and top:
		audio.ump("ump_playball")
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
	batter = teams[batting][Ratings.ORDER[lineup[batting]]]
	lineup[batting] = (lineup[batting] + 1) % 9
	batter.mode = PlayerScript.BATTER
	batter.visible = true
	batter.position = Vector2(-3.6 * FT, 0)
	batter.facing = 0.0
	batter.swing_t = -1.0
	batter.bunting = false
	batter.trot = false
	batter.stealing = false
	batter.steal_intent = false
	balls = 0
	strikes = 0
	if not human_pitching() and not derby and pitcher_energy() < 0.15 and pitcher_idx[fielding] < 2:
		_change_pitcher()

func _begin_pitch() -> void:
	phase = PRE_PITCH
	cam_follow = false
	pre_timer = rng.randf_range(0.9, 1.5)
	aim = Vector2.ZERO
	swung = false
	contact_at = -1.0
	cpu_swing_at = -1.0
	zone_show = 0.0
	meter_active = false
	meter_t = 0.0
	meter_pos = -1.0
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
	steal_on = false
	pickoff_tried = false
	if base_occupied(1):
		var fb = teams[fielding][2]   # the first baseman holds the runner
		fb.position = base_pos(1) + Vector2(-1, -5) * FT
		fb.target = fb.position
	if base_occupied(2):
		var ss = teams[fielding][4]   # the shortstop cheats toward second
		ss.position = Vector2(-14, -122) * FT
		ss.target = ss.position
	for r in runners:
		r.stealing = false
		r.steal_intent = false
	if not human_batting() and not derby:
		var c = _steal_candidate()
		if c != null:
			var p := clampf((float(c.r["speed"]) - 50.0) / 90.0, 0.0, 0.3)
			if c.on_base == 2:
				p *= 0.5
			if outs == 2:
				p *= 0.7
			c.steal_intent = rng.randf() < p
	_set_leads()
	ball.hold(_pitcher())

func _steal_candidate():
	# the lead runner who has an empty base in front of him (steals of second and third)
	var best = null
	for r in runners:
		if r.on_base >= 1 and r.on_base <= 2 and not base_occupied(r.on_base + 1):
			if best == null or r.on_base > best.on_base:
				best = r
	return best

func _set_leads() -> void:
	for r in runners:
		var lead := 0.05 if r.on_base == 3 else 0.07
		if r.steal_intent:
			lead = 0.16
		r.seg_t = lead
		r.goal = r.on_base
		r.position = base_pos(r.on_base).lerp(base_pos(r.on_base + 1), lead)
		r.facing = (base_pos(r.on_base + 1) - r.position).angle()

func _start_steals() -> void:
	for r in runners:
		if r.steal_intent:
			r.stealing = true
			r.goal = r.on_base + 1
			r.seg_t = maxf(r.seg_t, 0.2)
			r.run_delay = 0.0
			stat("steal_att")
			show_message("HE'S RUNNING!", 0.8)

func _change_pitcher() -> void:
	pitcher_idx[fielding] += 1
	stat("relievers")
	show_message("NEW PITCHER: #%d" % int(pitcher_r()["number"]), 1.4)

func _start_special(kind: String, after: String) -> void:
	# a live play without a batted ball: the catcher's throw on a steal, or a pickoff throw
	special_play = kind
	special_after = after
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
	batter_runner = null
	second_cover = 4
	cam_follow = true
	for r in runners:
		r.forced = false
		r.retouch = false
		r.trot = false
		r.halfway = false
		r.keep_going = false
		r.start_base = r.on_base
		if not r.stealing:
			r.goal = r.on_base
	cover = _coverage()

func _pickoff(b: int) -> void:
	var target = null
	for r in runners:
		if r.on_base == b:
			target = r
	if target == null or phase != PRE_PITCH or meter_active:
		return
	_start_special("pickoff", "pitch")
	target.run_delay = 0.35 if target.steal_intent else 0.15   # leaning toward the next base: slow to get back
	for r in runners:
		r.steal_intent = false
	stat("pickoff_att")
	show_message("PICKOFF THROW!", 0.8)
	_throw_to(_pitcher(), cover[b], base_pos(b))

func _slowmo(sec: float) -> void:
	if testing:
		return
	Engine.time_scale = 0.35
	slowmo_left = sec

func _process(delta: float) -> void:
	if slowmo_left > 0.0:
		slowmo_left -= delta / maxf(Engine.time_scale, 0.01)
		if slowmo_left <= 0.0:
			Engine.time_scale = 1.0

# ---------------- home run derby ----------------

func _start_derby() -> void:
	top = true
	batting = HUMAN_TEAM
	fielding = 1 - HUMAN_TEAM
	outs = 0
	for p in teams[fielding]:
		p.mode = PlayerScript.FIELDER
		p.visible = true
		p.position = p.home_spot
		p.target = p.home_spot
	for p in teams[batting]:
		p.mode = PlayerScript.OFF
		p.visible = false
	batter = teams[batting][2]   # the cleanup hitter
	batter.mode = PlayerScript.BATTER
	batter.visible = true
	derby_hr = 0
	derby_outs = 0
	ball.hold(_pitcher())
	show_message("HOME RUN DERBY\nAny swing that isn't a homer is an out", 2.2)
	phase = PAUSE
	pause_timer = 2.2
	after_pause = "pitch"

func _derby_result() -> void:
	if derby_last_hr:
		derby_hr += 1
		stat("hr")
		show_message("HOME RUN!  %d" % derby_hr, 1.0)
		audio.play("roar", -3.0)
		audio.swell(1.0, 2.0)
	else:
		derby_outs += 1
		show_message("OUT  %d / %d" % [derby_outs, DERBY_OUTS], 1.0)
	if derby_outs >= DERBY_OUTS:
		_derby_end()
		return
	phase = PAUSE
	pause_timer = 1.0
	after_pause = "pitch"

func _derby_end() -> void:
	game_over = true
	phase = OVER
	var cfg := ConfigFile.new()
	cfg.load(Difficulty.PATH)
	var best := int(cfg.get_value("derby", "best", 0))
	if derby_hr > best and not testing:
		cfg.set_value("derby", "best", derby_hr)
		cfg.save(Difficulty.PATH)
	best = maxi(best, derby_hr)
	if testing:
		print("DERBY %d home runs" % derby_hr)
		print(stats)
		get_tree().quit()
		return
	_open_menu("HOME RUN DERBY:  %d HOME RUNS" % derby_hr, "BEST %d.   PLAY AGAIN:" % best)

func _end_half() -> void:
	phase = PAUSE
	special_play = ""
	if autoplay or humantest:
		print("End of %s %d: BLUE %d - RED %d" % ["top" if top else "bottom", inning, score[0], score[1]])
	show_message("3 OUTS\nSIDE RETIRED", 1.8)
	audio.organ("organ_sting")
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
	if not testing:
		_open_menu("FINAL   BLUE %d - %d RED" % [score[0], score[1]], "%s   PLAY AGAIN:" % result)
	else:
		show_message("FINAL   BLUE %d - %d RED\n%s" % [score[0], score[1], result], 9999.0)
	if autoplay or humantest:
		print("FINAL BLUE %d - RED %d  (hits %d - %d, innings %d)" % [score[0], score[1], hits[0], hits[1], inning])
		print(stats)
		get_tree().quit()

# ---------------- pitching and hitting ----------------

func _cpu_level() -> int:
	return Difficulty.NORMAL if autoplay else level

func pitcher_r() -> Dictionary:
	return team_data[fielding]["staff"][pitcher_idx[fielding]]

func pitcher_energy() -> float:
	return Ratings.energy(pitcher_r())

func pitch_menu() -> Array:
	# the pitch types this pitcher throws, fastball first
	var out := []
	for t in [FASTBALL, CHANGEUP, CURVE, SLIDER]:
		if pitcher_r()["pitches"].has(t):
			out.append(t)
	return out

func _pitch_rating(t: int) -> float:
	return float(pitcher_r()["pitches"].get(t, 40))

func _cpu_pick_pitch() -> int:
	var menu_t := pitch_menu()
	if rng.randf() < 0.5 or balls == 3:
		return FASTBALL
	return menu_t[rng.randi() % menu_t.size()]

func meter_green() -> float:
	# your pitch meter's green zone: the level, the pitcher's control, and how tired he is
	var e := pitcher_energy()
	var c := float(pitcher_r()["control"])
	return Difficulty.value(level, "meter_green") * (0.75 + c * 0.005) * (0.6 + 0.4 * minf(1.0, e * 2.0))

func _throw_pitch(type: int) -> void:
	if phase != PRE_PITCH or meter_active:
		return
	pitch_type = type
	if human_pitching():
		# start the meter; the pitch goes when you stop it
		meter_active = true
		meter_t = 0.0
		meter_pos = -1.0
		return
	var lv := _cpu_level()
	var e := pitcher_energy()
	var scatter := Difficulty.value(lv, "cpu_scatter") * (1.5 - float(pitcher_r()["control"]) / 100.0)
	if e < 0.5:
		scatter *= 1.0 + (0.5 - e) * 1.6
	_deliver_pitch(_cpu_pitch_target(lv) + _gauss2(scatter))

func _release_meter() -> void:
	if not meter_active:
		return
	meter_active = false
	var off := absf(meter_pos)
	var green := meter_green()
	var scatter := 0.05
	if off <= green:
		show_message("ON TARGET", 0.7)
	else:
		scatter = 0.12 + (off - green) / (1.0 - green) * 0.55
	stat("meter_" + ("green" if off <= green else "miss"))
	_deliver_pitch(aim + _gauss2(scatter))

func _deliver_pitch(loc: Vector2) -> void:
	var pr := pitcher_r()
	var e := pitcher_energy()
	pitch_loc = loc
	pitch_brk = BREAK[pitch_type] * (_pitch_rating(pitch_type) / 60.0)
	var vel := float(pr["velocity"])
	var fb_dur := lerpf(0.92, 0.76, vel / 100.0) + (1.0 - e) * 0.08
	pitch_dur = fb_dur + SLOWER[pitch_type] + rng.randf_range(-0.02, 0.02)
	pitch_mph = int(84.0 + vel * 0.14 - (1.0 - e) * 5.0) - MPH_LESS[pitch_type] + rng.randi_range(-1, 1)
	pr["pitch_count"] = int(pr["pitch_count"]) + 1
	audio.play("whoosh", -12.0, 0.9 + (90.0 - pitch_dur * 90.0) * 0.003)
	pitch_clock = 0.0
	ball.start_pitch(MOUND + Vector2(-1.5 * FT, 3.0 * FT), Vector2(pitch_loc.x * 0.8 * FT, -0.8 * FT), (2.5 - pitch_loc.y) * FT)
	phase = PITCHING
	stat("pitches")
	stat("pitch_" + Ratings.PITCH_NAMES[pitch_type].to_lower())
	ht_swing_err = rng.randfn(0.0, 0.05)
	_start_steals()
	if not human_batting():
		_plan_cpu_swing()

func _cpu_pitch_target(lv: int) -> Vector2:
	if derby:
		return Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
	var strike_chance := Difficulty.value(lv, "cpu_strikes")
	if balls == 3:
		strike_chance = 0.8
	if rng.randf() < strike_chance:
		return Vector2(rng.randf_range(-0.85, 0.85), rng.randf_range(-0.85, 0.85))
	return Vector2(rng.randf_range(-1.45, 1.45), rng.randf_range(-1.45, 1.45))

func _plan_cpu_swing() -> void:
	var lv := _cpu_level()
	var p := 0.06
	if _in_zone(pitch_loc):
		p = Difficulty.value(lv, "cpu_zone_swing")
	elif absf(pitch_loc.x) < 1.35 and absf(pitch_loc.y) < 1.35:
		p = Difficulty.value(lv, "cpu_chase") * (1.0 + _pitch_rating(pitch_type) / 200.0 if pitch_type != FASTBALL else 1.0)
	if strikes == 2:
		p += 0.15
	if rng.randf() >= p:
		return
	var con := float(batter.r["contact"])
	var te := rng.randfn(0.0, Difficulty.value(lv, "cpu_timing_sd") * (1.2 - con * 0.004))
	te += FOOL[pitch_type] * (_pitch_rating(pitch_type) / 60.0) * minf(1.0, pitcher_energy() * 2.0)   # fooled: out in front
	cpu_swing_at = maxf(0.05, pitch_dur - SWING_DELAY - te)
	cpu_stick = 0.0
	var roll := rng.randf()
	var pw := float(batter.r["power"])
	if roll < 0.06 + pw * 0.0015:
		cpu_stick = 1.0      # power hitters try to lift it
	elif roll < 0.2 + pw * 0.0015:
		cpu_stick = -1.0

func _contact_window(bunt: bool) -> float:
	# how early or late the swing may be and still hit it; pitches off the plate are harder to hit
	var w := CPU_WINDOW
	if bunt:
		w = BUNT_WINDOW
	elif human_batting():
		w = Difficulty.value(level, "swing_window")
	if not bunt and batter != null and not batter.r.is_empty():
		w *= Ratings.contact_mult(float(batter.r["contact"]))
	var d := maxf(absf(pitch_loc.x), absf(pitch_loc.y))
	if d > 1.0:
		w *= clampf(1.0 - (d - 1.0) * 1.1, 0.25, 1.0)
	return w

func _perfect_frac() -> float:
	return Difficulty.value(level, "perfect_frac") if human_batting() else 0.28

func _press_clock() -> float:
	# the pitch clock at the moment your finger hit the screen: pitch_clock only moves once a frame, so add the time
	# since the last frame, and take off the touch screen's reporting delay
	var since := clampf(float(Time.get_ticks_usec() - last_phys_usec) / 1000000.0, 0.0, 1.0 / 30.0)
	return pitch_clock + since - (0.0 if humantest else TOUCH_LATENCY)

func _start_swing(stick: float, bunt: bool, at_clock := -1.0) -> void:
	if swung or phase != PITCHING:
		return
	swung = true
	batter.bunting = bunt
	if not bunt:
		batter.swing_t = 0.0
	stat("swings")
	var clk := pitch_clock if at_clock < 0.0 else at_clock
	var te := pitch_dur - (clk + SWING_DELAY)     # > 0 early, < 0 late
	var window := _contact_window(bunt)
	var feel := "EARLY" if te > 0.0 else "LATE"
	if absf(te) <= window * _perfect_frac():
		feel = "PERFECT!"
	if absf(te) <= window:
		contact_at = clk + SWING_DELAY
		contact_te = te
		contact_stick = stick
		contact_bunt = bunt
	elif feel != "PERFECT!":
		feel = "WAY " + feel
	if human_batting():
		swing_text = "BUNT" if bunt and contact_at >= 0.0 else feel
		swing_text_timer = 1.1

func _resolve_contact() -> void:
	var window := _contact_window(contact_bunt)
	var q := 1.0 - absf(contact_te) / window
	var perfect := absf(contact_te) <= window * _perfect_frac()
	var speed: float
	var launch: float
	var spray: float
	if contact_bunt:
		speed = rng.randf_range(20.0, 34.0)
		launch = rng.randf_range(-14.0, -4.0)
		spray = -contact_te / window * 25.0 + rng.randf_range(-12.0, 12.0)
	else:
		speed = (54.0 + 64.0 * q) * (1.0 if _in_zone(pitch_loc) else 0.85) + rng.randf_range(-6.0, 6.0)
		speed += Ratings.power_ft(float(batter.r["power"])) - (_pitch_rating(pitch_type) - 50.0) * 0.08
		speed += (1.0 - pitcher_energy()) * 6.0   # a tired pitcher gets hit harder
		launch = 10.0 + rng.randfn(0.0, 15.0) - pitch_loc.y * 6.0 + contact_stick * 18.0
		if perfect:
			# PERFECT always means a hard, well-struck ball: the luck goes into where it goes, not how it's hit
			speed = maxf(speed + 4.0, 100.0 + Ratings.power_ft(float(batter.r["power"])))
			launch = clampf(lerpf(launch, 16.0 + contact_stick * 14.0, 0.5), 3.0, 36.0)
			stat("perfect")
		spray = -contact_te / window * 62.0 + rng.randf_range(-9.0, 9.0)   # early = pulled to left field
	var fair := absf(spray) <= 45.0
	var dir := Vector2(sin(deg_to_rad(spray)), -cos(deg_to_rad(spray)))
	var lr := deg_to_rad(launch)
	if OS.get_cmdline_user_args().has("--debug"):
		print("contact q=%.2f speed=%d launch=%d spray=%d" % [q, speed, launch, spray])
	var from: Vector2 = ball.position
	ball.launch(from, 3.0 * FT, dir * speed * FT * cos(lr), speed * FT * sin(lr), fair, fair)
	_contact_feel(perfect, q, speed, fair)
	cam_follow = true
	cam_last_pos = View.to_screen(Vector2(0, -60 * FT))
	cam_last_zoom = 0.9
	stat("contact")
	if derby:
		phase = PAUSE
		derby_last_hr = fair and ball.path_hr >= 0
		var t := float(ball.path_hr if derby_last_hr else mini(ball.path_p.size() - 1, 180)) / 60.0
		pause_timer = clampf(t + 0.3, 1.0, 3.5)
		after_pause = "derby"
		return
	if not fair:
		stat("fouls")
		audio.ump("ump_foul", -4.0)
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

func _contact_feel(perfect: bool, q: float, speed: float, fair: bool) -> void:
	# the bigger the contact, the bigger the reaction: sound, a short freeze, a camera punch, the crowd
	if contact_bunt:
		audio.play("bat_weak", -6.0, 1.2)
	elif perfect:
		audio.play("bat_perfect", 0.0, rng.randf_range(0.97, 1.03))
		hitstop_left = 0.08
		cam_punch = 0.07
		cam_shake = 5.0
	elif q > 0.45:
		audio.play("bat_good", -2.0, rng.randf_range(0.95, 1.05))
		hitstop_left = 0.035
		cam_punch = 0.03
	else:
		audio.play("bat_weak", -3.0)
	if not fair:
		audio.play("foul_tick", -4.0)
	exit_text = "%d MPH" % int(round(speed * 0.682))   # feet per second -> miles per hour
	exit_timer = 1.8
	if fair and not contact_bunt:
		var far: float = ball.path_p[ball.path_p.size() - 1].length() / FT
		if ball.path_hr >= 0 or far > 230.0:
			audio.swell(0.85, 2.5)   # the crowd rises with a deep fly
		elif speed > 90.0:
			audio.swell(0.4, 1.2)

func _pitch_result() -> void:
	if derby:
		phase = PAUSE
		zone_show = 1.2
		ball.hold(_catcher())
		pause_timer = 1.0
		after_pause = "pitch"
		if swung:
			derby_last_hr = false
			_derby_result()
		else:
			show_message("TAKE", 0.6)
		return
	var stealer = null
	for r in runners:
		if r.stealing:
			stealer = r
	_pitch_count_result()
	if stealer != null and runners.has(stealer) and stealer.stealing and phase == PAUSE and outs < 3 and not game_over:
		_start_special("steal", after_pause)

func _pitch_count_result() -> void:
	phase = PAUSE
	zone_show = 1.2
	ball.hold(_catcher())
	audio.play("mitt", -1.0 if _in_zone(pitch_loc) else -5.0)
	pause_timer = 1.0
	after_pause = "pitch"
	if swung or _in_zone(pitch_loc):
		strikes += 1
		if strikes >= 3:
			stat("k")
			show_message("STRIKEOUT!", 1.3)
			audio.ump("ump_strike3")
			audio.swell(0.5, 1.5)
			_batter_out_no_play()
			return
		show_message("SWING AND A MISS" if swung else "STRIKE", 0.9)
		if not swung:
			audio.ump("ump_strike", -2.0)
	else:
		balls += 1
		stat("balls")
		if balls >= 4:
			audio.ump("ump_ball4", -3.0)
			_walk()
			return
		show_message("BALL", 0.9)
		audio.ump("ump_ball", -7.0)

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
	r.stealing = false
	r.steal_intent = false
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
		# a home crowd: it loves RED's runs and groans at the visitors'
		if batting == 1:
			audio.play("cheer", -4.0)
			audio.swell(0.7, 2.0)
		else:
			audio.play("groan", -8.0)

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
	robbed_checked = false
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
		r.goal = b + 1 if f or r.stealing else b
		r.keep_going = false
		if f or outs == 2 or r.stealing:
			r.seg_t = maxf(r.seg_t, 0.08)   # secondary lead (a stealing runner keeps his jump)
		r.stealing = false
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
	if ball.path_hr >= 0 and i0 < ball.path_hr:
		var c: Vector2 = ball.path_p[ball.path_hr]
		var cp := c.normalized() * (c.length() - 3.0 * FT)
		var t_hr := float(ball.path_hr - i0) / 60.0
		return [maxf(t_hr, run_time(f.position.distance_to(cp)) + _react(f)), cp]
	var k := i0
	while k < n:
		var t := float(k - i0) / 60.0
		if ball.path_z[k] < CATCH_Z:
			var pk: Vector2 = ball.path_p[k]
			var need := run_time(maxf(0.0, f.position.distance_to(pk) - REACH * 0.7)) + _react(f)
			if need <= t:
				return [t, pk]
		k += 3
	var last: Vector2 = ball.path_p[n - 1]
	var t_end := maxf(float(n - 1 - i0) / 60.0, run_time(f.position.distance_to(last)) + _react(f))
	return [t_end, last]

func _react(f) -> float:
	var base := FIELD_REACT
	if not autoplay and f.team != HUMAN_TEAM:
		base = Difficulty.value(level, "cpu_react")
	return maxf(0.12, base + Ratings.react_offset(float(f.r["fielding"])))

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
	# an outfielder at the wall can leap and rob it if it barely clears
	var cross: Vector2 = ball.path_p[ball.path_hr]
	var hz: float = ball.path_z[maxi(ball.path_hr - 1, 0)]
	if hz < FENCE_H + 5.0 * FT and not robbed_checked:
		robbed_checked = true
		for f in teams[fielding]:
			if f.role >= 6 and f.position.distance_to(cross) < 10.0 * FT:
				if rng.randf() < clampf(0.3 + (float(f.r["fielding"]) - 50.0) * 0.008, 0.1, 0.6):
					f.position = cross.normalized() * (cross.length() - 3.0 * FT)
					f.dive_t = 0.7
					f.dive_dir = Vector2.UP
					ball.hold(f)
					stat("robbed")
					audio.play("glove", 0.0)
					audio.play("roar", -2.0)
					audio.swell(1.0, 3.0)
					_slowmo(0.8)
					_fly_out("ROBBED A HOME RUN!")
					return
	hr_called = true
	chaser = null
	stat("hr")
	hits[batting] += 1
	show_message("HOME RUN!", 2.0)
	audio.play("roar", 0.0)
	audio.ump("pa_homerun", -2.0)
	audio.organ("organ_homer", -5.0)
	audio.swell(1.0, 4.0)
	cam_shake = 9.0
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
			if f.catch_cooldown > 0.0 or f.dive_t > 0.0:
				continue
			var d: float = f.position.distance_to(ball.position)
			if d < REACH and ball.z < CATCH_Z:
				_field_ball(f, fly)
				return
			# just out of reach and getting away: dive for it
			if f == chaser and d < DIVE_REACH and ball.z < CATCH_Z and ball.speed_now() > 25.0 * FT:
				var i: int = ball.index_now()
				var nxt: Vector2 = ball.path_p[mini(i + 5, ball.path_p.size() - 1)]
				var me: Vector2 = f.position + f.velocity * (5.0 / 60.0)
				var away: bool = me.distance_to(nxt) > REACH * 1.1 and me.distance_to(nxt) >= d - 2.0
				var landing: bool = fly and ball.path_bounce - i < 5
				if away or landing:
					_dive(f, fly, d)
					return
	elif ball.state == BallScript.THROWN:
		var r = ball.receiver
		if r != null and ball.throw_t > 0.5 and r.position.distance_to(ball.position) < REACH:
			ball.hold(r)
			audio.play("glove", -3.0)

func _dive(f, fly: bool, d: float) -> void:
	f.dive_t = 0.9
	f.dive_dir = (ball.position - f.position).normalized()
	f.position += f.dive_dir * maxf(0.0, d - REACH * 0.5)
	f.velocity = Vector2.ZERO
	stat("dives")
	var p := clampf(0.2 + (float(f.r["fielding"]) - 50.0) * 0.006, 0.08, 0.45)
	if rng.randf() < p:
		stat("dive_catch")
		ball.hold(f)
		audio.play("glove", 0.0)
		audio.play("cheer", -2.0)
		audio.swell(0.9, 2.5)
		f.hold_timer = -0.5   # he has to get up first
		_slowmo(0.6)
		if fly:
			_fly_out("DIVING CATCH!")
		else:
			show_message("WHAT A STOP!", 1.0)
	else:
		f.catch_cooldown = 1.0

func _field_ball(f, fly: bool) -> void:
	var spd: float = ball.speed_now() / FT
	var err := 0.01
	if spd > 85.0 and not fly:
		err = 0.04
	err *= Ratings.error_mult(float(f.r["fielding"]))
	if rng.randf() < err:
		f.catch_cooldown = 0.8
		ball.deflect()
		error_this_play = true
		stat("errors")
		show_message("ERROR!", 0.9)
		return
	ball.hold(f)
	audio.play("glove", -2.0 if fly else -6.0)
	if fly:
		_fly_out()

func _fly_out(msg := "CAUGHT! OUT") -> void:
	if OS.get_cmdline_user_args().has("--debug"):
		print("   flyout by %s at %d ft, t=%.1f" % [POS_NAMES[ball.holder.role], ball.position.length() / FT, play_timer])
	stat("flyouts")
	show_message(msg, 1.2)
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
	if r.stealing:
		r.stealing = false
		r.steal_intent = false
		stat("sb")
		show_message("STOLEN BASE!", 1.0)
		audio.ump("ump_safe", -3.0)
	if r.on_base >= 4:
		_score_runner(r)
		return
	_decide_runner(r, _fly_danger())

func _runner_time_to(r, b: int) -> float:
	if b == r.on_base + 1:
		return (1.0 - r.seg_t) * BASE_DIST / r.run_speed + r.run_delay
	return r.seg_t * BASE_DIST / r.run_speed

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
	var rs: float = r.run_speed
	var run_t := (1.0 - float(r.seg_t)) * BASE_DIST / rs
	if r.goal == next and r.seg_t > 0.5:
		# committed: look one base further, so he can round this base without stopping
		var nn := next + 1
		r.keep_going = nn <= 4 and mode != RUN_HOLD and not (nn < 4 and _base_taken(nn, r)) \
			and _defense_time(base_pos(nn)) > run_t + BASE_DIST / rs + margin
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
		if h.hold_timer > (0.9 if special_play == "steal" else HOLD_AUTO_TIME) and not h.running_to_base:
			_cpu_fielder_play(h, true)   # no button pressed: he makes the best play himself
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
	var b := best_play(h, force_throw)
	if b >= 0:
		_play_on_base(h, b)

func best_play(h, force_throw: bool) -> int:
	# the base to go to: the runner we can beat by the most (lead runners first), else back to the infield
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
		return best_base
	# no out to be had: outfielders get the ball back to the infield
	if h.role >= 6 or force_throw:
		var lead := 1
		for r in runners:
			lead = maxi(lead, r.on_base + 1)
		return mini(lead, 4) if lead > 1 else 2
	return -1

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
	ball.throw_ball(h, rcv, to, Ratings.throw_speed_ft(float(h.r["arm"])) * FT)

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
	audio.ump("ump_out", -3.0)
	outs += 1
	outs_this_play += 1
	for q in runners:
		if q != r and q.on_base >= r.on_base:
			q.forced = false
	if r == batter_runner:
		batter_runner = null
	_remove_runner(r)
	if special_play == "steal":
		stat("cs")
		show_message("CAUGHT STEALING!", 1.2)
	elif special_play == "pickoff":
		stat("picked_off")
		show_message("PICKED OFF!", 1.2)
	elif outs_this_play >= 3:
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
	if special_play != "":
		after_pause = special_after
		pause_timer = 1.0
		special_play = ""
		for r in runners:
			r.forced = false
			r.retouch = false
			r.halfway = false
			r.stealing = false
			r.goal = r.on_base
			r.start_base = r.on_base
		for f in teams[fielding]:
			f.target = f.home_spot
			f.running_to_base = false
		return
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

func _stick() -> float:
	var v := _input_vector()
	if v.y < -0.4:
		return 1.0
	if v.y > 0.4:
		return -1.0
	return 0.0

func _on_a_pressed() -> void:
	if menu_open or game_over:
		return
	if phase == PRE_PITCH and human_pitching():
		if meter_active:
			_release_meter()
	elif phase == PITCHING and human_batting():
		_start_swing(_stick(), false, _press_clock())
	elif phase == LIVE and human_batting():
		run_mode = RUN_GO
		show_message("GO! GO! GO!", 0.7)
		_runner_decisions()

func _on_b_pressed() -> void:
	if menu_open or game_over:
		return
	if phase == PRE_PITCH and human_pitching():
		if meter_active:
			_release_meter()
	elif phase == PITCHING and human_batting() and not derby:
		_start_swing(0.0, true, _press_clock())
	elif phase == LIVE and human_batting():
		run_mode = RUN_HOLD
		show_message("HOLD UP!", 0.7)
		_runner_decisions()

func _on_pitch_pressed(k: int) -> void:
	if menu_open or phase != PRE_PITCH or not human_pitching() or meter_active:
		return
	var m := pitch_menu()
	if k >= 0 and k < m.size():
		_throw_pitch(m[k])

func _on_small_pressed(id: String) -> void:
	if menu_open or phase != PRE_PITCH:
		return
	if id == "steal" and human_batting():
		var c = _steal_candidate()
		if c != null:
			steal_on = not steal_on
			c.steal_intent = steal_on
			_set_leads()
			stat("steal_button")
	elif id.begins_with("pick") and human_pitching() and not meter_active:
		_pickoff(int(id.substr(4)))
	elif id == "relief" and human_pitching() and not meter_active and pitcher_idx[fielding] < 2:
		_change_pitcher()

func _on_base_pressed(b: int) -> void:
	if menu_open or phase != LIVE or not human_pitching() or ball.state != BallScript.HELD or not is_human(ball.holder):
		return
	stat("base_button")
	_play_on_base(ball.holder, b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J or event.keycode == KEY_SPACE:
			_on_a_pressed()
		elif event.keycode == KEY_K:
			_on_b_pressed()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_on_base_pressed((event.keycode - KEY_1 + 1) % 4)

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
	if phase == PRE_PITCH and human_pitching() and not meter_active:
		var to2 := Vector2(0.5, 0.3) - aim
		return to2.normalized() if to2.length() > 0.05 else Vector2.ZERO
	if phase == PITCHING and human_batting():
		return [Vector2.ZERO, Vector2.UP, Vector2.DOWN][_frame / 400 % 3]
	return Vector2.ZERO

func _humantest_presses() -> void:
	if phase == PRE_PITCH and human_batting() and _frame % 40 == 0 and _steal_candidate() != null and not steal_on and rng.randf() < 0.3:
		_on_small_pressed("steal")
	if phase == PRE_PITCH and human_pitching():
		if not meter_active and _frame % 50 == 0:
			var c = _steal_candidate()
			if c != null and c.on_base <= 2 and rng.randf() < 0.12:
				_on_small_pressed("pick%d" % c.on_base)
			elif pitcher_energy() < RELIEF_AT and pitcher_idx[fielding] < 2 and rng.randf() < 0.5:
				_on_small_pressed("relief")
			else:
				_on_pitch_pressed(rng.randi() % pitch_menu().size())
		elif meter_active and (absf(meter_pos) < 0.08 or meter_t > 1.8):
			_on_a_pressed()
	elif phase == PITCHING and human_batting() and not swung and pitch_clock >= pitch_dur - SWING_DELAY + ht_swing_err:
		if _in_zone(pitch_loc) or rng.randf() < 0.03:
			if rng.randf() < 0.08:
				_on_b_pressed()
			else:
				_on_a_pressed()
	elif phase == LIVE:
		if human_pitching() and ball.state == BallScript.HELD and is_human(ball.holder) and ball.holder.hold_timer > 0.5:
			var b := best_play(ball.holder, true)
			_on_base_pressed(b if rng.randf() < 0.7 else rng.randi() % 4)
		if human_batting() and _frame % 150 == 0:
			if rng.randf() < 0.5:
				_on_a_pressed()
			else:
				_on_b_pressed()

# ---------------- main loop ----------------

var _frame := 0

var _moment_shots := {}

func _debug_screenshots() -> void:
	# developer testing only: -- --moments saves one screenshot of each key moment to /tmp/baseball_<moment>.png
	if OS.get_cmdline_user_args().has("--moments"):
		var m := ""
		if phase == PITCHING and human_batting() and pitch_clock > pitch_dur * 0.55:
			m = "bat_ring"
		elif phase == PRE_PITCH and meter_active and meter_t > 0.35:
			m = "pitch_meter"
		elif phase == PRE_PITCH and human_pitching() and not meter_active and aim.length() > 0.3:
			m = "pitch_fan_runners" if not runners.is_empty() else "pitch_fan"
		elif phase == PITCHING and human_batting() and not runners.is_empty() and runners.any(func(r): return r.stealing):
			m = "steal"
		elif phase == LIVE and teams[fielding].any(func(f): return f.dive_t > 0.5):
			m = "dive"
		elif phase == LIVE and ball.state == BallScript.HELD and is_human(ball.holder) and ball.holder.hold_timer > 0.2:
			m = "throw_bases"
		elif phase == LIVE and ball.state == BallScript.LIVE and ball.can_fly_out and ball.path_bounce - ball.index_now() > 60 and play_timer > 1.0:
			m = "fly_marker"
		elif phase == LIVE and human_batting() and play_timer > 1.5 and runners.size() >= 2:
			m = "running"
		if m != "" and not _moment_shots.has(m):
			_moment_shots[m] = true
			get_viewport().get_texture().get_image().save_png("/tmp/baseball_%s.png" % m)
			print("MOMENT ", m)
			if _moment_shots.size() >= 9:
				get_tree().quit()
	if OS.get_cmdline_user_args().has("--shots") and _frame % 150 == 0 and _frame > 0:
		get_viewport().get_texture().get_image().save_png("/tmp/baseball_%04d.png" % _frame)
		if _frame >= 3000:
			get_tree().quit()

func _physics_process(delta: float) -> void:
	_frame += 1
	_debug_screenshots()
	_update_message(delta)
	marker.queue_redraw()
	if menu_open:
		_update_camera(delta)
		_update_hud()
		return
	exit_timer = maxf(0.0, exit_timer - delta)
	if hitstop_left > 0.0:
		# hit-stop: the game holds still for a moment on big contact
		hitstop_left -= delta
		_update_camera(delta)
		_update_hud()
		last_phys_usec = Time.get_ticks_usec()
		return
	zone_show = maxf(0.0, zone_show - delta)
	swing_text_timer = maxf(0.0, swing_text_timer - delta)
	var input := _input_vector()
	match phase:
		PRE_PITCH:
			if human_pitching():
				if meter_active:
					meter_t += delta
					meter_pos = -cos(meter_t * TAU / METER_PERIOD)
					if meter_t > METER_PERIOD * 2.0:
						meter_pos = 1.0
						_release_meter()   # too slow: it sails
				else:
					aim = (aim + input * 1.8 * delta).clamp(Vector2(-1.6, -1.6), Vector2(1.6, 1.6))
			else:
				pre_timer -= delta
				if not pickoff_tried and pre_timer < 0.5 and not derby:
					pickoff_tried = true
					var c = _steal_candidate()
					if c != null and rng.randf() < (0.35 if c.steal_intent else 0.04):
						_pickoff(c.on_base)
				if phase == PRE_PITCH and pre_timer <= 0.0:
					_throw_pitch(_cpu_pick_pitch())
		PITCHING:
			pitch_clock += delta
			ball.pitch_t = minf(1.0, pitch_clock / pitch_dur)
			if cpu_swing_at >= 0.0 and pitch_clock >= cpu_swing_at:
				cpu_swing_at = -1.0
				_start_swing(cpu_stick, false)
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
					"derby":
						_derby_result()
	if humantest and not game_over:
		_humantest_presses()
	ball.update(delta)
	for p in players:
		if p.mode != PlayerScript.OFF:
			p.update(delta, is_human(p), input)
	_update_camera(delta)
	_update_hud()
	last_phys_usec = Time.get_ticks_usec()

func _update_camera(delta: float) -> void:
	# at the plate: a close look from behind home at the batter and the mound. In play: pull back to frame the whole
	# play (the ball, where it will be caught, a throw and its target, every running runner) and ease there smoothly.
	# Points are sim positions; the framing happens on screen (View.to_screen), where the camera lives.
	var tgt := View.to_screen(Vector2(0, -34 * FT))
	var zm := 1.45 if View.angled() else 1.3
	if hr_called and phase == LIVE:
		tgt = View.to_screen(Vector2(0, -64 * FT))
		zm = 0.8 if View.angled() else 0.7
	elif cam_follow and (phase != LIVE or ball.position.length() > fence_radius(ball.position)):
		tgt = cam_last_pos   # after the play (or a ball in the seats): stay put until the next pitch
		zm = cam_last_zoom
	elif cam_follow:
		var bp := View.to_screen(ball.position, ball.z * View.ball_h())
		var lo := bp
		var hi := bp
		var pts: Array = [View.to_screen(ball.position)]
		if ball.state == BallScript.LIVE and chaser != null:
			pts.append(View.to_screen(chase_point))
			pts.append(View.to_screen(chaser.position))
		if ball.state == BallScript.THROWN:
			pts.append(View.to_screen(ball.throw_to))
		for r in runners:
			if not r.is_safe():
				pts.append(View.to_screen(r.position))
		for q in pts:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var margin := Vector2(70 * FT, 70 * FT * View.tilt() + 50.0)
		var view := get_viewport_rect().size
		var need: Vector2 = (hi - lo) + margin * 2.0
		zm = clampf(minf(view.x / need.x, (view.y - 60.0) / need.y), 0.5, 1.0)
		tgt = (lo + hi) / 2.0 + Vector2(0, -30.0 / zm)
		var top_y := -300.0 * FT * View.tilt()
		tgt = Vector2(clampf(tgt.x, -230.0 * FT, 230.0 * FT), clampf(tgt.y, top_y, 10.0 * FT))
		cam_last_pos = tgt
		cam_last_zoom = zm
	camera.position = camera.position.lerp(tgt, 1.0 - exp(-2.6 * delta))
	var zz := lerpf(camera.zoom.x / (1.0 + cam_punch), zm, 1.0 - exp(-1.8 * delta))
	cam_punch = maxf(0.0, cam_punch - delta * 0.35)
	camera.zoom = Vector2(zz, zz) * (1.0 + cam_punch)
	camera.offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * cam_shake
	cam_shake = maxf(0.0, cam_shake - delta * 18.0)

func _draw_marker() -> void:
	# where a fly ball will come down
	if phase != LIVE or ball.state != BallScript.LIVE or not ball.can_fly_out or ball.path_bounce < 0:
		return
	var i: int = ball.index_now()
	if i >= ball.path_bounce or ball.path_bounce - i < 20:
		return
	var p: Vector2 = ball.path_p[ball.path_bounce]
	var pulse := 0.5 + 0.5 * sin(play_timer * 9.0)
	var r := 7.0 * FT
	marker.draw_circle(p, r, Color(1, 0.9, 0.2, 0.16))
	marker.draw_arc(p, r * (0.75 + 0.25 * pulse), 0, TAU, 36, Color(1, 0.9, 0.2, 0.95), 4.0)
	marker.draw_line(p - Vector2(r * 0.45, 0), p + Vector2(r * 0.45, 0), Color(1, 0.9, 0.2, 0.9), 3.0)
	marker.draw_line(p - Vector2(0, r * 0.45), p + Vector2(0, r * 0.45), Color(1, 0.9, 0.2, 0.9), 3.0)

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
	if derby:
		score_label.text = "HOME RUNS  %d" % derby_hr
		inning_label.text = "HOME RUN DERBY"
		batter_label.text = "OUTS  %d / %d" % [derby_outs, DERBY_OUTS]
	else:
		score_label.text = "BLUE  %d   -   %d  RED" % [score[0], score[1]]
		inning_label.text = "%s %d   %s BATTING" % ["TOP" if top else "BOT", inning, TEAM_NAMES[batting]]
		batter_label.text = ""
	var a := "-"
	var b := "-"
	var bases := false
	var pitches := []
	var small := []
	if phase == PRE_PITCH or phase == PITCHING:
		if human_pitching():
			if phase == PRE_PITCH:
				if meter_active:
					a = "STOP"
					b = "STOP"
				else:
					for t in pitch_menu():
						pitches.append(Ratings.PITCH_NAMES[t])
					for base in [1, 2]:
						if base_occupied(base):
							small.append(["pick%d" % base, "PICK\n%dB" % base, false])
					if pitcher_energy() < RELIEF_AT and pitcher_idx[fielding] < 2:
						small.append(["relief", "NEW\nARM", true])
		elif human_batting():
			a = "SWING"
			b = "-" if derby else "BUNT"
			if phase == PRE_PITCH and _steal_candidate() != null and not derby:
				small.append(["steal", "STEAL", steal_on])
	elif phase == LIVE:
		if human_batting() and special_play == "":
			a = "GO!"
			b = "HOLD"
		elif ball.state == BallScript.HELD and is_human(ball.holder):
			bases = true
			controls.base_hint = best_play(ball.holder, true) % 4
	controls.a_text = a
	controls.b_text = b
	controls.show_bases = bases
	controls.pitch_names = pitches
	controls.small = small
