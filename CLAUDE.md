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
- `scripts/field.gd`: draws the park. `scripts/hud.gd`: base/out diamond and strike zone panel.
- `scripts/touch_controls.gd`: floating joystick on the left half, A and B buttons on the right (same as Hoops).
- `assets/`: Kenney Sports Pack sprites (CC0). Player sprites face right (+x).

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
```
After gameplay changes, run about 10 `--autoplay` games and check the stats look sane. Over a 3 inning CPU game,
typical totals are about 75-80 pitches, 30 balls in play, 15 hits, 8-9 runs (both teams), 3 strikeouts, a few
doubles, and the odd walk, triple, home run and error. Look at a screenshot after visual changes.

## Ideas not done yet
Sound effects, stolen bases and pickoffs, diving catches, pitcher fatigue, difficulty setting, curveball, title
menu, line score at the end, left-handed batters.
