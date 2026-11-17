extends RefCounted
# EASY / NORMAL / HARD. The level makes the CPU sharper or softer and your timing windows tighter or wider.
# The choice is saved in user://settings.cfg (test runs never save it).

enum { EASY, NORMAL, HARD }
const NAMES := ["EASY", "NORMAL", "HARD"]

# value per level: [EASY, NORMAL, HARD]
const VALUES := {
	"swing_window": [0.145, 0.12, 0.095],    # your swing: seconds early/late that still make contact
	                                         # (Phase 1 check-in: Easy hitting too easy, was 0.17 / 0.135 / 0.10)
	"perfect_frac": [0.28, 0.24, 0.2],       # the share of that window that counts as PERFECT (was 0.35 / 0.28 / 0.22)
	"meter_green": [0.24, 0.17, 0.11],       # your pitch meter: half width of the green zone (0..1 bar)
	"cpu_zone_swing": [0.6, 0.66, 0.72],     # CPU batter: chance to swing at a strike
	"cpu_chase": [0.36, 0.28, 0.2],          # ... and at a pitch just off the plate
	"cpu_timing_sd": [0.11, 0.09, 0.075],   # ... how far off its timing is (seconds)
	"cpu_strikes": [0.6, 0.52, 0.48],        # CPU pitcher: share of pitches aimed inside the zone
	"cpu_scatter": [0.16, 0.11, 0.08],       # ... how far its pitches miss the target
	"cpu_react": [0.36, 0.28, 0.22],         # CPU fielders: reaction time (seconds) when you bat
}

const PATH := "user://settings.cfg"

static func value(level: int, key: String) -> float:
	return VALUES[key][clampi(level, 0, 2)]

static func load_level() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return NORMAL
	return clampi(int(cfg.get_value("game", "level", NORMAL)), 0, 2)

static func save_level(level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("game", "level", level)
	cfg.save(PATH)

static func from_args(args: PackedStringArray, fallback: int) -> int:
	for i in args.size():
		var a := args[i]
		var v := ""
		if a.begins_with("--difficulty="):
			v = a.substr(13)
		elif a == "--difficulty" and i + 1 < args.size():
			v = args[i + 1]
		if v != "":
			var k := NAMES.find(v.to_upper())
			if k >= 0:
				return k
	return fallback
