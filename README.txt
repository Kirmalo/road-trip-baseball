ROAD TRIP BASEBALL - arcade baseball (Godot 4)

OPEN IT ON THE TABLET
1. Extract this zip (keep the RoadTripBaseball folder together).
2. Open Godot, tap Import, and pick the project.godot file inside RoadTripBaseball.
3. Open the project and press the Play button (top right). The first open takes a moment while Godot imports the images.

PLAY IN A BROWSER
https://kirmalo.github.io/road-trip-baseball/  (works on the tablet's browser too; tap and drag like the app)

HOW TO PLAY
Pick EASY, NORMAL or HARD at the start (the choice is remembered; you can change it after every game), or tap
HOME RUN DERBY: hit as many homers as you can before 10 outs (any swing that isn't a homer is an out).
During each at-bat two cards at the bottom show the batter (CON = contact, POW = power, SPD = speed) and the
pitcher (VEL = velocity, CTL = control, ARM = how much he has left, plus his pitch count).
You are BLUE, the road team, so you bat first (the top of each inning). RED bats in the bottom.
The joystick is on the left half of the screen, the buttons on the right. The map in the top-left corner shows
the whole field: runners (big dots), fielders, the ball, the count and the outs.

BATTING
- The panel on the right is the strike zone as the catcher sees it. A ring closes in on the pitch:
  tap SWING when the ring touches the ball. You see EARLY, PERFECT! or LATE after each swing.
  Early pulls the ball to left field (too early = foul), late pushes it to right field.
- Hold the stick UP while you swing to lift the ball (fly balls, home runs), DOWN to chop it on the ground.
  Leave the stick alone for the batter's natural swing.
- Pitches off the plate are much harder to hit: let them go for balls. Four balls is a walk.
- BUNT: a soft roller. Easier to make contact, but a foul bunt with two strikes is a strikeout.
- STEAL (small button, before the pitch, when a runner has an empty base ahead): he takes a big lead and runs on
  the pitch. Fast runners make it; slow ones get thrown out. A big lead can also get him picked off.
- Once the ball is in play: GO sends your runners for an extra base, HOLD keeps them where they are.
  Otherwise the runners decide for themselves (green arrow = running, red = going back). With two outs they run
  on anything.

PITCHING
- Steer the red crosshair where you want the pitch, then tap one of your pitcher's pitches: FAST (fastball),
  CHANGE (slow, drops, fools hitters into swinging early), CURVE (big late drop), SLIDER (late sideways break).
  Each pitcher throws 2-4 of them. A meter starts sweeping: tap STOP in the green and the pitch goes where you
  aimed; outside the green it can go wild. Good control means a bigger green zone.
- Pitchers tire (the ARM bar on his card): slower pitches, a smaller green zone, harder contact. When he is
  tired a NEW ARM button brings in a reliever (each team has two).
- PICK 1B / PICK 2B (small buttons, before the pitch): throw over to pick off a runner. Runners who are about to
  steal take big leads; that's when it works.

FIELDING
- Fielders run and catch by themselves. A yellow target on the ground shows where a fly ball will come down.
  Good fielders dive for balls just out of reach, and an outfielder at the wall can rob a home run.
- When your fielder has the ball, four base buttons appear: tap 1B, 2B, 3B or HOME to throw there. The green
  one is the best play; if you don't tap, he makes that play himself after a moment.
  A fielder who throws to a base he is standing next to just runs over and steps on it.
- Fly balls caught before they bounce are outs, and runners have to go back to their base.

RULES
3 innings, 3 outs, 4 balls a walk, 3 strikes an out (fouls count as strikes until two). Extra innings if tied.

EASY THINGS TO CHANGE (scripts/main.gd, at the top)
- INNINGS: innings per game
- RUN_SPEED, FIELD_SPEED, THROW_SPEED: how fast runners, fielders and throws are
- scripts/difficulty.gd: everything EASY / NORMAL / HARD changes (your timing window, the pitch meter's green zone,
  how sharp the CPU bats, pitches and fields)
Hit power is in _resolve_contact() in main.gd. CPU pitching and swinging are in _cpu_pitch_target() and
_plan_cpu_swing().

FILES
- main.gd: rules, count, innings, pitching and hitting, fielding and base running decisions, camera, your controls
- difficulty.gd: the EASY / NORMAL / HARD values and the saved level
- ratings.gd: player ratings, the teams' players and pitchers, and what each rating does
- player.gd: moves a fielder, the batter or a base runner
- ball.gd: pitches, batted ball flight (bounces, the wall, home runs), throws
- field.gd: draws the ballpark
- hud.gd: the mini-map, the strike zone panel (timing ring, pitch meter) and hints
- touch_controls.gd: joystick, buttons and the base buttons

Art: Kenney Sports Pack (www.kenney.nl), CC0.
