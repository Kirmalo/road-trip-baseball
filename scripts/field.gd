extends Node2D
# Draws the ballpark. Home plate is at (0, 0) and the field opens upward (negative y). Sizes are feet times FT.

var game
const View = preload("res://scripts/view.gd")

const GRASS := Color(0.22, 0.52, 0.2)
const GRASS_LIGHT := Color(0.26, 0.58, 0.24)
const DIRT := Color(0.71, 0.52, 0.33)
const LINE := Color(1, 1, 1, 0.95)
const WALL := Color(0.1, 0.24, 0.16)

func _dir(a: float) -> Vector2:
	# a = 0 points at center field, positive toward right field
	return Vector2(sin(a), -cos(a))

func _draw() -> void:
	var FT: float = game.FT

	# stands and crowd
	draw_rect(Rect2(-900 * FT, -800 * FT, 1800 * FT, 1000 * FT), Color(0.15, 0.16, 0.21))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 1800:
		var d := _dir(r.randf_range(-PI, PI))
		var rad: float = game.fence_radius(d * 100.0) + r.randf_range(6.0, 80.0) * FT
		draw_circle(d * rad, r.randf_range(2.5, 4.5), Color.from_hsv(r.randf(), 0.35, 0.6, 0.7))

	# playing surface out to the walls
	var outline := PackedVector2Array()
	for i in 360:
		var d := _dir(-PI + TAU * i / 360.0)
		outline.append(d * game.fence_radius(d * 100.0))
	draw_colored_polygon(outline, GRASS)

	# mowing stripes in fair territory
	for k in range(0, 14, 2):
		var rad := (40.0 + k * 20.0) * FT
		draw_arc(Vector2.ZERO, rad, -3.0 * PI / 4.0, -PI / 4.0, 64, GRASS_LIGHT, 18.0 * FT)

	# warning track and wall
	var track := PackedVector2Array()
	var wall := PackedVector2Array()
	for i in 91:
		var d := _dir(deg_to_rad(-45.0 + i))
		var fr: float = game.fence_radius(d * 100.0)
		track.append(d * (fr - 7.0 * FT))
		wall.append(d * fr)
	draw_polyline(track, DIRT, 14.0 * FT)
	# the wall: a strip standing up from the warning track (up is -y / tilt in this squashed frame)
	var up := Vector2(0, -game.FENCE_H * View.ball_h() / View.tilt())
	if View.angled():
		for i in wall.size() - 1:
			draw_colored_polygon(PackedVector2Array([wall[i], wall[i + 1], wall[i + 1] + up, wall[i] + up]), WALL)
		var top := PackedVector2Array()
		for q in wall:
			top.append(q + up)
		draw_polyline(top, Color(0.85, 0.75, 0.2), 0.6 * FT)
	else:
		draw_polyline(wall, WALL, 2.5 * FT)
	var font := ThemeDB.fallback_font
	for a in [-45.0, -22.0, 0.0, 22.0, 45.0]:
		var d := _dir(deg_to_rad(a))
		var fr: float = game.fence_radius(d * 100.0)
		var txt := str(int(round(fr / FT)))
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var at := d * fr + up * 0.55 if View.angled() else d * (fr + 14.0 * FT)
		draw_set_transform(at, 0, View.upright())
		draw_string(font, Vector2(-w / 2, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.9))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for s in [-1.0, 1.0]:
		var d := _dir(s * PI / 4.0)
		var pole: Vector2 = d * game.fence_radius(d * 100.0)
		if View.angled():
			draw_set_transform(pole, 0, View.upright())
			draw_line(Vector2.ZERO, Vector2(0, -90), Color(1, 0.85, 0.1), 5.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		else:
			draw_circle(pole, 1.5 * FT, Color(1, 0.85, 0.1))

	# infield dirt: the arc 95 ft from the mound, between the foul lines
	var mound := Vector2(0, -60.5 * FT)
	var dirt := PackedVector2Array([Vector2(0, 2.0 * FT)])
	for i in 181:
		var th := deg_to_rad(-90.0 + i)
		var q := mound + _dir(th) * 95.0 * FT
		if absf(atan2(q.x, -q.y)) <= PI / 4.0 + 0.06:
			dirt.append(q)
	draw_colored_polygon(dirt, DIRT)
	draw_circle(Vector2.ZERO, 13.0 * FT, DIRT)

	# infield grass
	var center := Vector2(0, -63.64 * FT)
	var grass := PackedVector2Array()
	for b in 4:
		grass.append(center + (game.base_pos(b) - center) * 0.8)
	draw_colored_polygon(grass, GRASS_LIGHT)
	draw_circle(mound, 9.0 * FT, DIRT)
	draw_rect(Rect2(mound + Vector2(-1.0, -0.25) * FT, Vector2(2.0, 0.5) * FT), Color.WHITE)

	# foul lines and batter's boxes
	for s in [-1.0, 1.0]:
		var d := _dir(s * PI / 4.0)
		draw_line(Vector2.ZERO, d * game.fence_radius(d * 100.0), LINE, 0.5 * FT)
		draw_rect(Rect2(Vector2(s * 1.6 - (4.0 if s < 0 else 0.0), -3.0) * FT, Vector2(4.0, 6.0) * FT), LINE, false, 0.35 * FT)

	# bases
	for b in [1, 2, 3]:
		var p: Vector2 = game.base_pos(b)
		draw_set_transform(p, PI / 4.0, Vector2.ONE)
		draw_rect(Rect2(Vector2(-1.5, -1.5) * FT, Vector2(3.0, 3.0) * FT), Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var plate := PackedVector2Array([Vector2(-0.71, -0.9), Vector2(0.71, -0.9), Vector2(0.71, -0.2), Vector2(0, 0.5), Vector2(-0.71, -0.2)])
	for i in plate.size():
		plate[i] = plate[i] * FT
	draw_colored_polygon(plate, Color.WHITE)
