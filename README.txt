ROAD TRIP BASEBALL - arcade baseball (Godot 4)

OPEN IT ON THE TABLET
1. Extract this zip (keep the RoadTripBaseball folder together).
2. Open Godot, tap Import, and pick the project.godot file inside RoadTripBaseball.
3. Open the project and press the Play button (top right). The first open takes a moment while Godot imports the images.

PLAY IN A BROWSER
https://kirmalo.github.io/road-trip-baseball/  (works on the tablet's browser too; tap and drag like the app)

HOW TO PLAY
You are BLUE, the road team, so you bat first (the top of each inning). RED bats in the bottom.
Drag anywhere on the left half of the screen to steer.

BATTING
- The panel on the right is the strike zone as the catcher sees it. Steer the yellow circle over the pitch as it comes in.
- SWING: tap it as the ball reaches the plate. Too early pulls the ball foul to the left, too late pushes it foul
  to the right. Catching the ball in the middle of the circle hits it hard. If the ball is low in your circle you
  swing over it and hit a ground ball; if it is high in your circle you get under it and hit a fly ball.
- BUNT: a soft roller. Easier to make contact, but a foul bunt with two strikes is a strikeout.
- Once the ball is in play: GO sends your runners for an extra base, HOLD keeps them where they are.
  Otherwise the runners decide for themselves. With two outs they run on anything.

PITCHING
- Steer the red crosshair where you want the pitch, then tap FAST (fastball) or CHANGE (slower changeup that
  fools hitters into swinging early). Pitches don't always go exactly where you aim. Corners are hard to hit,
  but miss the zone four times and it's a walk.

FIELDING
- Your fielder has the yellow ring. He runs to the ball by himself; steer him if you want to take over.
- With the ball: push the stick toward a base and tap THROW. Tap THROW without pushing to make the best play.
  Running onto the base with the ball gets a force out, and touching a runner off the base tags him out.
- Fly balls caught before they bounce are outs, and runners have to go back to their base.

RULES
3 innings, 3 outs, 4 balls a walk, 3 strikes an out (fouls count as strikes until two). Extra innings if tied.

EASY THINGS TO CHANGE (scripts/main.gd, at the top)
- INNINGS: innings per game
- RUN_SPEED, FIELD_SPEED, THROW_SPEED: how fast runners, fielders and throws are
- TIMING_WINDOW and CONTACT_R: how forgiving hitting is
Hit power is in _resolve_contact() in main.gd. CPU pitching and swinging are in _cpu_pitch_target() and
_plan_cpu_swing().

FILES
- main.gd: rules, count, innings, pitching and hitting, fielding and base running decisions, HUD, your controls
- player.gd: moves a fielder, the batter or a base runner
- ball.gd: pitches, batted ball flight (bounces, the wall, home runs), throws
- field.gd: draws the ballpark
- hud.gd: the base/out diamond and the strike zone panel
- touch_controls.gd: joystick and buttons

Art: Kenney Sports Pack (www.kenney.nl), CC0.
