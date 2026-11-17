# Road Trip Baseball

Top-down arcade baseball game in Godot 4 (GDScript), played by touch on an Android tablet. A sister project of
Road Trip Hoops and built the same way.
The owner edits and plays it in the Godot Android editor, and gets updates by downloading the repo as a ZIP and
re-importing it. There is no Git on the tablet, so keep the project self-contained and runnable as is.

## Layout
- `project.godot`: 1280x720 landscape, stretch `canvas_items` + `expand`, GL Compatibility renderer, nearest filtering.
  The features version is "4.3" so older Android editors open it without a warning. Keep code compatible with Godot 4.3+.
- `main.tscn`: a single Node2D with `scripts/main.gd`. Everything else is built in code (no other scenes).
- `scripts/main.gd`: game manager. Innings, count, pitching/hitting, fielder assignments (chaser, base coverage),
  CPU fielder throws, runner decisions, outs (force, tag, doubled off), HUD, input routing.
- `scripts/player.gd`: one player in mode FIELDER, BATTER or RUNNER. Runners move along base paths
  (`on_base`, `seg_t` = 0..1 toward the next base, `goal`).
- `scripts/ball.gd`: states DEAD, HELD, PITCH, LIVE, THROWN. A batted ball's whole flight is simulated at contact
  into `path_p`/`path_z` (60 samples a second, bounces, walls, `path_hr`), so fielders can compute intercepts.
- `scripts/view.gd`: the projection (static, preloaded as `View`). ANGLED (default, owner's choice after Phase 1): the
  3/4 view from behind home plate; FLAT: the old top-down view (`--view flat`). The simulation stays 2D top-down: every
  field node is a child of `world` (main.gd), whose scale (1, `View.tilt()`) squashes the ground; upright things
  (players, the ball's height, the wall, poles, text) undo it with `draw_set_transform(..., View.upright())` and
  draw in screen-like coordinates (`View.local(ground_offset, height)`). The camera works in `View.to_screen()`
  coordinates. `world.y_sort_enabled` puts nearer players in front.
- Players in ANGLED are simple upright figures drawn in code (`_draw_figure` in player.gd) until the Phase 3 art;
  the Kenney sprites are only used in FLAT.
- `scripts/field.gd`: draws the park. `scripts/hud.gd`: mini-map (top-left, with count and outs), strike zone panel
  (pitch with break, timing ring, EARLY/PERFECT/LATE, aim and pitch meter) and the bottom hint line.
- `scripts/touch_controls.gd`: floating joystick on the left half, A and B buttons on the right (same as Hoops), and
  the four base buttons (`show_bases`, signal `base_pressed(b)`, b = 0 home .. 3) while your fielder holds the ball.
- `scripts/difficulty.gd`: EASY / NORMAL / HARD values (`Difficulty.value(level, key)`), the saved level in
  `user://settings.cfg` (never saved by test runs) and `--difficulty`. The level picker is `_open_menu()` in main.gd
  (at start and after each game; skipped when any user argument is given).
- Controls (Phase 1): batting is one tap (timing; stick up/down = loft/chop, `_start_swing`/`_resolve_contact`);
  pitching is aim + pitch button + meter (`_throw_pitch` -> `_release_meter` -> `_deliver_pitch`); fielding is fully
  automatic, your only fielding input is the throw (`_on_base_pressed`, auto `best_play()` after `HOLD_AUTO_TIME`).
- `assets/`: Kenney Sports Pack sprites (CC0). Player sprites face right (+x).
- `export_presets.cfg` + `tools/build_web.sh`: web export (no threads, so it runs on plain GitHub Pages).
  `tools/build_web.sh --publish` builds and pushes the result to the `gh-pages` branch.

## Conventions
- Units: `FT = 4` pixels per foot. Home plate is at (0, 0), the field opens toward -y, first base is +x.
  Speeds are feet per second times FT. Fence: 290 ft down the lines, 340 ft to center (`fence_radius()`).
- Strike zone coordinates (`pitch_loc`, `cursor`, `aim`): x and y in zone half-widths, y down; |x|,|y| <= 1 is a strike.
- Team 0 (BLUE, human) bats in the top of each inning. Fielding roles 0-8: P, C, 1B, 2B, SS, 3B, LF, CF, RF.
- GDScript: don't use `:=` when the right side is untyped (e.g. `game.something`, array elements, `min`/`max`/`clamp`);
  use an explicit type or `minf`/`maxf`. Otherwise the script fails to parse.
- Touch first: every feature must be usable with the joystick plus the two buttons. Keyboard (WASD, J, K) is for
  desktop testing only.

## Testing (no tablet needed)
Download a Godot 4 Linux editor binary from the GitHub releases, then:

```
godot --headless --path . --import
# full CPU vs CPU game, prints half-inning scores, final score and stats (add --debug for a play-by-play)
godot --headless --path . --fixed-fps 60 --quit-after 80000 -- --autoplay
# scripted human inputs, exercises swing/bunt/pitch/throw/GO/HOLD code paths
godot --headless --path . --fixed-fps 60 --quit-after 100000 -- --humantest
# screenshots to /tmp/baseball_*.png every 150 frames (needs xvfb)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -- --shots --humantest
# one screenshot per key moment (bat_ring, pitch_aim, pitch_meter, throw_bases, fly_marker, running) to
# /tmp/baseball_<moment>.png, quits after 5 (software rendering is slow: allow ~10 minutes)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -- --moments --humantest
```
`--difficulty easy|normal|hard` (or `--difficulty=hard`) sets the level for a test run (default NORMAL).
`--view flat|angled` (or `--view=flat`) picks the drawing mode (default angled); the simulation is the same in both.
Web build: put Godot 4.3 on PATH as `godot`, install the 4.3 web template (`web_nothreads_release.zip` from the
export templates .tpz) into `~/.local/share/godot/export_templates/4.3.stable/`, then `tools/build_web.sh`
(add `--publish` to update the live page). Serve `build/web/` locally to test it in a browser.

After gameplay changes, run about 10 `--autoplay` games and check the stats look sane. Over a 3 inning CPU game,
typical totals are about 75-80 pitches, 30 balls in play, 15 hits, 8-9 runs (both teams), 3 strikeouts, a few
doubles, and the odd walk, triple, home run and error. Look at a screenshot after visual changes.

## Design
The owner-approved design and the phase plan are in `docs/VISION.md`. Follow it; record new owner answers there.

## Ideas not done yet
Sound effects, stolen bases and pickoffs, diving catches, pitcher fatigue, difficulty setting, curveball, title
menu, line score at the end, left-handed batters.
