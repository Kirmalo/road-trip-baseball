extends RefCounted
# Player ratings (0-100, 50 = average) and how they turn into play. Static only:
#   const Ratings = preload("res://scripts/ratings.gd")
# Every player has contact, power, speed, arm, fielding. Pitchers (the starter and two relievers per team) also have
# velocity, control, stamina and a set of pitches, each with its own rating.
# Teams are made here from role templates plus a fixed per-team shuffle, so a team is the same every game. The road
# trip (Phase 4) will replace this with real crews.

const FASTBALL := 0
const CHANGEUP := 1
const CURVE := 2
const SLIDER := 3
const PITCH_NAMES := ["FAST", "CHANGE", "CURVE", "SLIDER"]
const PITCH_LONG := ["FASTBALL", "CHANGEUP", "CURVEBALL", "SLIDER"]

# role templates: contact, power, speed, arm, fielding (P, C, 1B, 2B, SS, 3B, LF, CF, RF)
const TEMPLATES := [
	[30, 25, 40, 70, 55],
	[50, 58, 30, 75, 60],
	[56, 72, 38, 50, 50],
	[62, 40, 66, 55, 66],
	[56, 46, 70, 72, 72],
	[55, 64, 44, 72, 60],
	[58, 62, 58, 52, 52],
	[62, 50, 80, 64, 72],
	[54, 66, 54, 78, 56],
]

# batting order: CF, SS, RF, 1B, 3B, LF, C, 2B, P (roles)
const ORDER := [7, 4, 8, 2, 5, 6, 1, 3, 0]

static func make_team(team: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + team * 977
	var players := []
	for role in 9:
		var t: Array = TEMPLATES[role]
		players.append({
			"contact": _r(rng, t[0]), "power": _r(rng, t[1]), "speed": _r(rng, t[2]),
			"arm": _r(rng, t[3]), "fielding": _r(rng, t[4]), "number": [1, 2, 3, 4, 6, 5, 7, 8, 9][role] + team * 20,
		})
	var staff := [_pitcher(rng, true, 1 + team * 20), _pitcher(rng, false, 11 + team * 20), _pitcher(rng, false, 12 + team * 20)]
	return {"players": players, "staff": staff}

static func _r(rng: RandomNumberGenerator, base: int) -> int:
	return clampi(base + rng.randi_range(-9, 9), 20, 95)

static func _pitcher(rng: RandomNumberGenerator, starter: bool, number: int) -> Dictionary:
	var pitches := {FASTBALL: _r(rng, 60)}
	var extra := [CHANGEUP, CURVE, SLIDER]
	for i in range(extra.size() - 1, 0, -1):   # shuffle with the team's own rng, so it is the same every game
		var j := rng.randi_range(0, i)
		var tmp = extra[i]
		extra[i] = extra[j]
		extra[j] = tmp
	var n := 3 if starter else rng.randi_range(1, 2)
	for i in n:
		pitches[extra[i]] = _r(rng, 58)
	return {
		"velocity": _r(rng, 55 if starter else 62), "control": _r(rng, 58 if starter else 50),
		"stamina": _r(rng, 72) if starter else _r(rng, 38), "pitches": pitches, "number": number,
		"pitch_count": 0, "starter": starter,
	}

# ---- what the ratings do (all return multipliers or offsets around 50 = no change) ----

static func run_speed_ft(speed: float) -> float:       # feet per second on the bases
	return 24.0 + speed * 0.07                          # 50 -> 27.5

static func throw_speed_ft(arm: float) -> float:       # feet per second
	return 82.0 + arm * 0.4                             # 50 -> 102

static func contact_mult(contact: float) -> float:      # timing window
	return 0.85 + contact * 0.003                       # 50 -> 1.0

static func power_ft(power: float) -> float:            # added exit speed, feet per second
	return (power - 50.0) * 0.22

static func react_offset(fielding: float) -> float:     # seconds added to a fielder's reaction
	return (50.0 - fielding) * 0.003

static func error_mult(fielding: float) -> float:
	return 1.6 - fielding / 83.0                        # 50 -> 1.0

# pitcher fatigue: 1 = fresh, 0 = done. Sized for 3-inning games: a 70-stamina starter (about 45 pitches) tires
# in the third inning, a 38-stamina reliever after about 33
static func energy(p: Dictionary) -> float:
	return clampf(1.0 - float(p["pitch_count"]) / (20.0 + float(p["stamina"]) * 0.35), 0.0, 1.0)
