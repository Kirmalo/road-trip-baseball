extends Node
# Sound: effects, the crowd and the umpire. All sounds are made by tools/make_sfx.py (assets/sfx/).
#   audio.play("glove")            an effect (several can overlap)
#   audio.ump("ump_strike")        the umpire / PA (one at a time; a new call replaces the old one)
#   audio.organ("organ_sting")     the ballpark organ (one at a time)
#   audio.swell(0.6, 2.0)          the crowd murmur gets louder for a while (0..1)
# Test runs (any user argument) play no sound at all.

const NAMES := ["bat_perfect", "bat_good", "bat_weak", "foul_tick", "glove", "mitt", "whoosh", "bounce", "tap",
	"cheer", "roar", "groan", "organ_charge", "organ_sting", "organ_homer", "ump_strike", "ump_strike3", "ump_ball",
	"ump_ball4", "ump_out", "ump_safe", "ump_foul", "ump_playball", "pa_homerun"]
const POOL := 8
const CROWD_DB := -17.0        # the murmur at rest
const CROWD_MAX_DB := -6.0     # fully swelled

var muted := false
var streams := {}
var pool: Array = []
var next := 0
var voice: AudioStreamPlayer
var organ_p: AudioStreamPlayer
var crowd: AudioStreamPlayer
var swell_amt := 0.0
var swell_left := 0.0

func _ready() -> void:
	muted = not OS.get_cmdline_user_args().is_empty()
	if muted:
		return
	for n in NAMES:
		var s = load("res://assets/sfx/%s.wav" % n)
		if s != null:
			streams[n] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	organ_p = AudioStreamPlayer.new()
	add_child(organ_p)
	crowd = AudioStreamPlayer.new()
	var loop = load("res://assets/sfx/crowd_loop.ogg")
	if loop != null:
		loop.loop = true
		crowd.stream = loop
		crowd.volume_db = CROWD_DB
		add_child(crowd)
		crowd.play()

func play(n: String, db := 0.0, pitch := 1.0) -> void:
	if muted or not streams.has(n):
		return
	var p: AudioStreamPlayer = pool[next]
	next = (next + 1) % POOL
	p.stream = streams[n]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

func ump(n: String, db := 0.0) -> void:
	if muted or not streams.has(n):
		return
	voice.stream = streams[n]
	voice.volume_db = db
	voice.play()

func organ(n: String, db := -4.0) -> void:
	if muted or not streams.has(n):
		return
	organ_p.stream = streams[n]
	organ_p.volume_db = db
	organ_p.play()

func swell(amount: float, sec: float) -> void:
	# the crowd gets excited: amount 0..1 for sec seconds, then settles back
	if amount >= swell_amt or swell_left <= 0.0:
		swell_amt = clampf(amount, 0.0, 1.0)
		swell_left = sec

func _process(delta: float) -> void:
	if muted or crowd == null:
		return
	swell_left -= delta
	var target := swell_amt if swell_left > 0.0 else 0.0
	if swell_left <= 0.0:
		swell_amt = maxf(0.0, swell_amt - delta * 0.5)
	var want := lerpf(CROWD_DB, CROWD_MAX_DB, target)
	crowd.volume_db = lerpf(crowd.volume_db, want, minf(1.0, delta * 3.0))
