# Road Trip Baseball: Vision

The shared design doc for everyone working on the game, people and agents. If a design question isn't answered here,
ask the owner and record the answer in this file. Don't guess. Sister project of Road Trip Hoops: when this doc is
silent on how something works (menus, saves, settings, release), do it the way Hoops does.

## Pitch
An arcade-lite 9 vs 9 baseball game in pixel art. The Cornfield Kings from Road Trip Hoops trade the hoop for bats
and gloves, pile into The Biscuit again and drive through America's baseball towns, beating local teams city by
city, to reach a tournament at a ballpark in the Iowa cornfields. Played by touch on a tablet.

## Pillars
1. **Readable at a glance.** You always know where the ball is, where it will land, who you control and what to
   press. (The owner's first test: everything was hard to see.)
2. **Every pitch is a moment.** Timing-based hitting and pitching with clear feedback (EARLY / PERFECT / LATE,
   bat crack, glove pop, umpire calls), big homers and highlight catches.
3. **Fielding never gets in the way.** Fielders run and catch by themselves; you make the decision (where to throw).
4. **The trip is the reason to keep playing.** Each ballpark looks, sounds and plays differently, and your team grows.
5. **Touch first.** Joystick plus two buttons (plus the base buttons when throwing). No hidden inputs.

## Research summary (before the design questions)
- Hitting in successful games is timing + aim (Super Mega Baseball reticle, MLB The Show PCI) or timing first
  (MLB 9 Innings: timing decides direction and angle). The most common complaint is not being able to read the pitch.
- Fielding and base running are where arcade baseball games are criticized most (Mario Superstar Baseball). Mobile
  games mostly automate fielding movement; players like to keep the throw decision and the aggressive base running.
- Long-term hooks: team progression (Baseball 9, MLB 9 Innings), a charming cast (Backyard Baseball), create a team
  and play through saved progress (Baseball Stars).
- Difficulty: Super Mega Baseball's Ego slider (0-99, separable per skill) is loved but confusing at first.

## Decisions (owner, design questions round 1, after the starter build)
| Topic | Decision |
|---|---|
| Owner's test of the starter | Everything needs work: hard to see/read, batting feels bad, fielding feels bad, looks unfinished |
| Scope | Full Hoops-style game: road trip campaign, recruits, stat points, story, original art, music, menus, release |
| Tone | Arcade-lite like Hoops: real rules, exaggerated moments, fast pace, strong feedback |
| Team size | Full 9 vs 9 |
| Camera while pitching/batting | Keep top-down with the strike-zone panel |
| Camera in play | High overhead (zoomed out more than the starter); smooth, eases out to show the whole play, no sudden jumps |
| Readability | Bigger players and ball (bigger shadow, trail on hit balls); a landing marker where a fly ball will come down; a mini-map of the diamond (runners, fielders, ball); the smoother camera above |
| Batting | One tap: SWING at the right moment. Timing sets quality and direction (early = pull, late = opposite field). Holding the stick up or down while tapping adds loft or chops it down; no stick = the batter's natural swing |
| Zone panel when batting | Shows the incoming pitch with its break, plus a shrinking timing ring that hits "perfect" at the right moment; EARLY / PERFECT / LATE popup after each swing |
| Hitting difficulty | Forgiving on Easy/Normal, sharper on Hard; lots of balls in play |
| Pitching | Pick the pitch, aim the spot, then tap a sweeping timing meter: good timing = on target, bad = wild |
| Pitch types | 3-4 per pitcher from fastball, changeup, curveball, slider, each with its own rating; the break is visible in the panel |
| Fielding | Fielders run to the ball and catch automatically; you choose the throw |
| Throw input | Four base buttons (1B, 2B, 3B, HOME) appear in a small diamond near the thumb; tap one to throw there |
| Base running | Runners decide by themselves; GO sends everyone an extra base, HOLD stops them (made clearer than the starter) |
| Extra features | Diving and wall catches (robbing homers, a slow-mo moment); stealing and pickoffs; pitcher stamina with relievers from the bullpen; a Home Run Derby mode |
| Game length | 3 innings, extra innings if tied |
| Route | A new route through baseball towns (draft below), ending at a tournament in the Iowa cornfields (an original ballpark, not a real stadium) |
| City twists | Yes: field shape and weather (short porch, huge outfield, wind, thin air, rain, night game, sandlot obstacles). Noticeable but fair, the same for both teams, shown with a banner (as in Hoops) |
| Roster | Like Hoops: start with your 9, recruit one player per city you beat, stat points after wins (contact, power, speed, arm, fielding, pitching), set your lineup |
| Your team | The Hoops crew joins: Deuce, Jojo and Tank form a baseball team with new teammates (a direct sequel) |
| Art | Match Hoops: original pixel art made by scripts in tools/art, the same arcade look, redrawn for top-down baseball (batting, pitching, running, diving, sliding). A style sample for the owner first |
| Audio | Like Hoops: upbeat chiptune per city; bat crack, glove pop, crowd, umpire calls |
| Difficulty | Easy / Normal / Hard, as in Hoops: changes how sharp the CPU is (batting eye, pitch accuracy, fielding range) |
| Release | Same as Hoops: GitHub Pages as the test build; itch.io web + Android APK when ready, pay what you want |
| Process | Phases with tablet check-ins, like Hoops |

## Decisions after the Phase 1 check-in
| Topic | Decision |
|---|---|
| Timing (batting) | "Timing is pretty good" |
| Camera view | Switch to a 3/4 view (owner: "not loving top down"), replacing the earlier top-down choice. Camera raised behind home plate looking out to center field; batter and catcher in front, outfield at the top. Parallel tilt, no perspective narrowing |
| Zone panel | Keep the strike-zone panel (timing ring, pitch meter) in the 3/4 view |
| Players for now | Simple upright placeholder figures drawn in code (cap, team jersey, running legs, glove, bat); real pixel art in Phase 3 |
| Top-down | Kept only as a hidden test option (`--view flat`), like Hoops |
| 3/4 check | "The angle is better" |
| Phase 1 check-in | Play camera, base-button throwing with the 2.5 s auto-throw, and the pitch meter: all good as is. Easy was too easy, because of hitting: every level's swing window and PERFECT zone tightened (Easy 0.17 -> 0.145 s, Normal 0.135 -> 0.12 s, Hard 0.10 -> 0.095 s; PERFECT share 0.35/0.28/0.22 -> 0.28/0.24/0.2) |

## Draft route (open to change at the Phase 4 check-in)
Hometown (Indiana sandlot) -> St. Louis -> Kansas City -> Chicago -> Boston -> Denver (thin air) -> San Diego ->
Iowa cornfield tournament. Real city names; no real ballparks, teams, players, logos or brands.

## Phase plan
Each phase ends with a ZIP/web build the owner plays on the tablet and a short set of check-in questions.
1. **Feel and readability.** Bigger sprites and ball, high overhead smooth camera, landing marker, mini-map;
   one-tap batting with the timing ring and stick loft; pitch meter and visible break; auto fielding with base
   buttons; clearer GO/HOLD; Easy/Normal/Hard. Goal: a quick game that is fun and easy to follow.
2. **Baseball depth.** Player ratings, 3-4 pitch types per pitcher, stamina and the bullpen, diving and wall catches,
   stealing and pickoffs, Home Run Derby.
3. **Art and sound.** Style sample for approval, then players and animations, ballparks, chiptune music and sound
   effects; title, settings and pause screens.
4. **The road trip.** Cities with twists, local teams, recruits, stat points, story scenes with the Hoops crew,
   the Iowa finale, saving.
5. **Release.** How to Play pages, itch.io page and screenshots, Android APK.

## Open questions (ask at the right phase)
- The six new teammates beside Deuce, Jojo and Tank (names, looks, positions): Phase 3/4.
- Exact cities and twists: Phase 4.
- Whether Home Run Derby has its own unlocks: Phase 2.
