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

## Research round 2 (after Phase 2)
| Topic | Decision |
|---|---|
| Deep research | Owner asked for deep research on what makes baseball games fun before going deeper; report in `docs/research/what-makes-baseball-games-fun.md`. Owner approved folding its prioritized recommendations into the phase plan (below). Caveat: the research came from search-result summaries, since full pages could not be fetched in that session |

## Phase 3 progress notes
| Topic | Decision |
|---|---|
| Sound source | All sounds synthesized by `tools/make_sfx.py` (like Hoops' swish, bounce and whistle), so no third-party licenses: bat cracks in three qualities, glove and mitt pops, whoosh, crowd loop, cheer, roar, groan, organ stings, and umpire / PA calls voiced with espeak-ng and given a stadium echo. To check with the owner on the tablet: whether the voices and organ are good enough or should be replaced by CC0 / CC-BY recordings |
| Partisan crowd | The crowd is a home crowd: it cheers RED's runs and groans at BLUE's (fits the road trip, and the research's point that partisan personality is remembered). Home runs, diving catches and robbed homers get a roar either way |
| PERFECT | Always hard contact (at least about 68 mph plus the batter's power, a line-drive-to-fly launch angle); randomness goes into direction. An EXIT VELO readout shows after every contact |
| Hit feel | Hit-stop about 5 frames on PERFECT and 2 on good contact, a small camera punch, and a shake on PERFECT and home runs |
| Duel and CPU (P5-P9) | Power swing: hold SWING and release (tap = normal swing, unchanged). Missed meter = usually a flat hanging pitch over the middle, else wild; aiming at corners shrinks the green zone. CPU pitches and bats to the count (strikes when behind, chase pitches with two strikes, takes 3-0, sits on the fastball in hitter's counts, protects with two strikes), throws the odd mistake (more when tired, more on Easy), steals only in sensible situations (third only with one out, not into likely walks, not in blowouts). Forced runners take only a few steps on catchable flies. Tap A or B to skip pauses, slow motion and home run trots. The fielder with the ball gets a white ring |
| Touch timing | Swings are timed from the real tap moment, with a fixed 30 ms allowance for touch delay (TOUCH_LATENCY); a calibration setting can come with the settings screen |

## Phase 2 plan answers
| Topic | Decision |
|---|---|
| Picking a pitch | A button per pitch: FAST / CHANGE are replaced by 2-4 round buttons in a fan (the pitcher's pitches); tap one, then stop the meter |
| Stealing | A small STEAL button before the pitch when a runner can steal; the lead runner goes on the pitch |
| Pickoffs | Small 1B / 2B buttons beside the pitch buttons for occupied bases; runners with big leads (about to steal) can be picked off. The CPU throws over too |
| Ratings | Small cards during each at-bat: batter CONTACT / POWER / SPEED, pitcher VELOCITY / CONTROL and a stamina bar; ratings really change play |
| Home Run Derby | A HOME RUN DERBY button on the start / after-game panel; 10 outs, any swing that isn't a homer is an out; best score remembered (team default, no unlocks) |
| Relievers | A NEW ARM button appears when your pitcher is tired (team default); the CPU changes its own pitcher. Fatigue sized for 3-inning games |

## Draft route (open to change at the Phase 4 check-in)
Hometown (Indiana sandlot) -> St. Louis -> Kansas City -> Chicago -> Boston -> Denver (thin air) -> San Diego ->
Iowa cornfield tournament. Real city names; no real ballparks, teams, players, logos or brands.

## Phase plan
Each phase ends with a ZIP/web build the owner plays on the tablet and a short set of check-in questions.
The research report `docs/research/what-makes-baseball-games-fun.md` (owner-approved to shape this plan) found the
controls already match what the best-loved baseball games do; the biggest gains now are feel, fairness and
personality. Its priorities (P1-P17) are folded in below.

1. **Feel and readability** (done). Bigger sprites and ball, smooth camera, landing marker, mini-map; one-tap
   batting with the timing ring and stick loft; pitch meter and visible break; auto fielding with base buttons;
   clearer GO/HOLD; Easy/Normal/Hard; then the 3/4 view.
2. **Baseball depth** (done). Player ratings and cards, 3-4 pitch types per pitcher, stamina and the bullpen, diving
   and wall catches, stealing and pickoffs, Home Run Derby.
3. **Feel, fairness, art and sound.** Starts with the research's top priorities, in this order:
   - Sound pass (P1): bat crack scaled by contact quality, glove pop, umpire calls (strike, out, safe), a crowd that
     swells on deep flies and roars on homers, a short organ or chiptune sting between innings.
   - Contact juice scaled to quality (P2): PERFECT gets a few frames of hit-stop, a crisp crack, a small camera pulse
     and the trail; GOOD gets less; weak or foul contact only a dull thud.
   - PERFECT means hard contact (P3): randomness goes into direction, not contact quality; a short exit-speed
     readout after contact.
   - Fair touch timing (P4): judge taps on the touch event's time, add a small latency offset (or a calibration
     setting); labels always consistent with the result.
   - Fix CPU failure modes before adding features (P5): runners always tag up and get back on fly balls, never
     overrun a bag by themselves, CPU steals only in sensible counts; highlight the fielder holding the ball.
   - Deeper duel without new buttons (P6): count-aware CPU pitching and batting (take 3-0, protect with two strikes,
     chase pitches with two strikes), aiming at a corner tightens the meter band, a missed meter gives a visible
     hanging pitch over the plate, breaks happen late. (Also the answer to "Easy was too easy".)
   - Optional power swing (P7): tap = contact, hold and release = power with a narrower PERFECT window.
   - Cut dead time (P9): tap to skip celebrations and slow motion, quick transitions.
   Then: art style sample for approval, players and animations, ballparks, chiptune music; title, settings and
   pause screens with first-game one-line hints (P8).
4. **The road trip.** 8 cities, 3 real games each, the boss game after the first two, one short skippable scene on
   arrival and one after the boss, no quests between games (P10). Fixed, capped stat points per win, one recruit
   from the city after the boss, a bonus for a city goal or a big win; upgrades visibly change the cards (P11).
   Bosses with one learnable habit and a visible tell, the final boss mixing them (P12). One twist per ballpark,
   explained in one line before the game, each bending one variable (P13). The Hoops crew with distinct looks and
   one-line personalities; their friendships become small chemistry bonuses (P14). Text-caption commentary from a
   home-town announcer who roots for the locals, many short lines with no repeats (P15). The Iowa finale, saving.
5. **Release.** Difficulty and accessibility pass (P16): Easy adds assists such as a pitch-type hint, Hard removes
   them; maybe separate batting and pitching levels; no always-on adaptive difficulty; every colour cue also has a
   shape or label; large text. How to Play pages, itch.io web build beside the Android APK, replay any city and a
   harder New Game Plus after the campaign (P17).

**Not to build** (research): a throw meter, manual fielder movement or per-runner control, currencies, card
packs, energy or timers, several gimmicks in one park, quests between games.

## Open questions (ask at the right phase)
- The six new teammates beside Deuce, Jojo and Tank (names, looks, positions): Phase 3/4.
- Exact cities and twists: Phase 4.
