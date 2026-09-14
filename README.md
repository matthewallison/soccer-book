# Soccer Development Handbook

A practical player-development and team-coaching handbook for a U13–U14 girls' ECNL Regional League team, built around intelligent, technical, courageous soccer. The framework applies across U13–U16.

Version 1.0 · September 2026. Laws, safety policies, league structures, and media sources in this handbook change; check them each season.

The central goal is not to create players who memorize instructions. It is to develop players who can **scan, communicate, make intentional decisions, solve problems, compete, reflect, lead, and adapt**.

## Core team mantras

Players say the mantras out loud, together: the practice mantra is the first thing at every practice, and the game mantra is the first thing in every game warm-up.

| Moment | Mantra |
|---|---|
| Practice | **SCAN. TALK. INTENTION. FASTER.** |
| Games | **CALM MIND. FAST SOCCER.** |
| After mistakes | **RESPOND. REFLECT. LEARN. NEXT PLAY.** |
| Pressure moments | **WANT THE MOMENT.** |

## The middle gear

The handbook also emphasizes **possession at multiple scales**. Players should be able to combine in tight spaces, but also recognize when pressure has been escaped and the field has opened.

**SMALL SPACE: COMBINE. BIG SPACE: EXPLOIT.**

We want to eliminate the common youth pattern of **short passing under pressure → continued short passing after escape → panic clearance**.

We want to replace it with:

**Combine → escape → expand → exploit space with intention.**

The full explanation and training progression are in §7 of the [Coaching Game Model & Development Manual](docs/coaching-game-model.md).

## How to use this handbook

### Players

- Know the four mantras by memory. Learn the bold principles in the [High-Level Player Sheet](docs/player-philosophy.md) over time, and use it as a quick reference.
- Read [Team Culture, Courage, Leadership & Self-Coaching](docs/team-culture-and-leadership.md) for the ideas behind the sheet.
- Learn the team's shared words, body shape, and movement habits in [Communication & Movement Fundamentals](docs/communication-and-movement.md).
- Before each match, review the [position card](docs/positions/) for your role and picture its moments.
- Study your games with the [Film Review Guide](docs/film-review-guide.md), and choose short sessions from the [Home Development Menu](docs/home-development.md).
- If something hurts, tell a parent and your coach, and read [Injuries, Recovery, and Return to Play](docs/injuries-and-return-to-play.md).

### Coaches

- Teach from the [Coaching Game Model & Development Manual](docs/coaching-game-model.md), which holds the tactical detail and the development system.
- Check the environment against [What Good Coaching Looks Like](docs/good-coaching-signs.md).
- Plan and follow up with the templates: [Weekend Role Sheet](docs/templates/weekend-role-sheet.md), [Game Reflection](docs/templates/game-reflection.md), and [Development Plan](docs/templates/development-plan.md).
- When a player is hurt, follow [Injuries, Recovery, and Return to Play](docs/injuries-and-return-to-play.md): respect medical restrictions, keep her connected, and never reward a hidden injury.

### Parents

- Start with [Parent Partnership](docs/parent-partnership.md): the sideline, after the game, helping at home, health signals, communication and safeguarding, and team film.
- Use [What Good Coaching Looks Like](docs/good-coaching-signs.md) to see whether the team is learning, not just winning.
- After a meaningful injury, read [Injuries, Recovery, and Return to Play](docs/injuries-and-return-to-play.md) for what to share with the coach and how the return works.

## Documents

- [High-Level Player Sheet](docs/player-philosophy.md) — the four mantras to memorize and the principles to learn over time.
- [Team Culture, Courage, Leadership & Self-Coaching](docs/team-culture-and-leadership.md) — wanting the moment, penalty kicks, mistake culture, leadership, self-coaching, asking for opportunities, and peer support.
- [Injuries, Recovery, and Return to Play](docs/injuries-and-return-to-play.md) — what toughness really means, staying connected while injured, and returning progressively and confidently once cleared.
- [Communication & Movement Fundamentals](docs/communication-and-movement.md) — shared vocabulary, changing the size of the game, body shape, movement timing, and defensive posture.
- [Film Review Guide](docs/film-review-guide.md) — how players can study their own games and higher-level soccer, with a simple game tally and one question for each position.
- [Home Development Menu](docs/home-development.md) — short optional technical, athletic, and mental development ideas, plus rest and recovery basics.
- [Position Cards](docs/positions/) — pregame preparation and visualization cards for each role: purpose, mindset, moments to picture, relationships, and a fallback when unsure.
- [Coaching Game Model & Development Manual](docs/coaching-game-model.md) — coaching philosophy, tactical framework, training methodology, the development system, and safety and safeguarding.
- [What Good Coaching Looks Like](docs/good-coaching-signs.md) — the freeze test, the signs of a well-coached team and a good development environment, and questions a player can ask herself.
- [Parent Partnership](docs/parent-partnership.md) — how families support a player-first environment, from the sideline and home support to health signals, communication, safeguarding, and team film.
- [Weekend Role Sheet](docs/templates/weekend-role-sheet.md) — printable form for each player's primary and secondary roles, restart jobs, and one focus, shared about 48 hours before a match.
- [Game Reflection](docs/templates/game-reflection.md) — printable form for a player's game tally and three-part self-review.
- [Development Plan](docs/templates/development-plan.md) — printable form for a player's strength, development priority, and check-in notes.
- [Sources and Further Reading](docs/further-reading.md) — the federation, academy, research, health, and safeguarding sources behind the handbook, plus where to watch games.

## Position cards

- [Goalkeeper (#1)](docs/positions/goalkeeper.md)
- [Outside Back (#2 / #3)](docs/positions/outside-back.md)
- [Center Back (#4 / #5)](docs/positions/center-back.md)
- [Defensive Midfielder / Pivot (#6 / #8)](docs/positions/defensive-midfield.md)
- [Winger (#7 / #11)](docs/positions/winger.md)
- [Striker (#9)](docs/positions/striker.md)
- [Attacking Midfielder (#10)](docs/positions/attacking-midfield.md)

## Printing and website

- [Print files](print/) — `print/build.sh` builds `soccer-development-handbook.pdf` in the repository root (pass a path to write it elsewhere). It requires pandoc, XeLaTeX with a full TeX Live installation, TeX Gyre Pagella, and the Lato .ttf files in `/usr/share/fonts/truetype/lato/` (for example, the fonts-lato package).
- [Website files](.github/workflows/) — `mkdocs.yml` builds the site with MkDocs Material; `.github/workflows/pages.yml` publishes it to GitHub Pages on every push to `main`. Preview locally with `pip install -r requirements.txt && mkdocs serve`.

## Roles and privacy

Position numbers follow the common U.S. 1–11 numbering; the right side takes the lower number. 
**Shareable documents use roles and positions only, never player names.** Each player receives only her own Weekend Role Sheet row, in person or through the team app with parents included, and development feedback happens face to face at the field, in view of others.

## Philosophy

Winning matters, and players should want to win.

**Winning is not the primary measure of development, but competing to win is part of development.**

The system itself should keep improving: attached to sound principles, not to one method, with training, roles, and constraints evolving as players develop. The principles were checked against federation, academy, and research sources (see [Sources and Further Reading](docs/further-reading.md)) but are not an official program of any of them.

## Website and license

Read it online at <https://matthewallison.github.io/soccer-book/>. Shared under [CC BY-NC 4.0](LICENSE): clubs, coaches, and families may copy, adapt, print, and share it for any non-commercial purpose, but it may not be sold. Appropriate attribution is required, and adaptations should indicate that changes were made; see [LICENSE](LICENSE) for the full terms.
