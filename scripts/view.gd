extends RefCounted
# View: how the 2D top-down simulation is drawn on screen. Use it through
#   const View = preload("res://scripts/view.gd")   (static functions only, never instanced).
#
# The simulation never changes: positions, velocities, heights (ball.z) and facing keep their top-down meaning.
# Everything on the field lives under one "world" node (main.gd) whose scale is (1, tilt()): that squashes the ground
# into the angled look for free (the field, shadows, rings, the landing marker). Things that stand up (players, the
# ball in the air, poles, the wall, text) undo the squash in their own _draw with upright() and draw in "screen-like"
# coordinates: x right, y down, height straight up. local(d, h) turns a ground offset plus a height into those.
#
# Modes:
#   ANGLED (default, owner's choice after Phase 1): the 3/4 view, the camera raised behind home plate looking out to
#          center field. Depth is squashed to TILT; heights stay upright.
#   FLAT   the old top-down look (test flag --view flat).

const FLAT := 0
const ANGLED := 1
static var mode := ANGLED

const TILT := 0.55        # field depth on screen as a fraction of its true depth (1 = top-down)
const BALL_H := 0.5       # screen pixels per sim pixel of ball height in ANGLED (high flies stay on screen)
const BALL_H_FLAT := 0.35

static func angled() -> bool:
	return mode == ANGLED

static func tilt() -> float:
	return TILT if mode == ANGLED else 1.0

static func ball_h() -> float:
	return BALL_H if mode == ANGLED else BALL_H_FLAT

# a sim floor point p at screen height h (screen pixels) -> the main canvas (what the camera looks at)
static func to_screen(p: Vector2, h := 0.0) -> Vector2:
	return Vector2(p.x, p.y * tilt() - h)

# the inverse at h = 0
static func to_floor(s: Vector2) -> Vector2:
	return Vector2(s.x, s.y / tilt())

# a ground offset d (sim pixels) and a height h (screen pixels) -> screen-like coordinates, for drawing after upright()
static func local(d: Vector2, h := 0.0) -> Vector2:
	return Vector2(d.x, d.y * tilt() - h)

# the scale to pass to draw_set_transform so a node under the world draws in screen-like coordinates
static func upright() -> Vector2:
	return Vector2(1.0, 1.0 / tilt())

static func from_args(args: PackedStringArray) -> void:
	for i in args.size():
		var v := ""
		if args[i].begins_with("--view="):
			v = args[i].substr(7)
		elif args[i] == "--view" and i + 1 < args.size():
			v = args[i + 1]
		if v == "flat":
			mode = FLAT
		elif v == "angled":
			mode = ANGLED
