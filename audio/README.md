# Player Audio Edition

The player chapters and position cards, rewritten for listening. One transcript file per track in `transcript/`; each becomes one audio file (and one chapter marker in a combined audiobook).

Finished MP3s go in `docs/audio/`, named like their transcripts (`09-goalkeeper.mp3`), so they publish with the website. Add a player for each new track to `docs/audio/index.md`.

## Tracks

| # | Transcript | Source |
|---|---|---|
| 00 | `00-introduction.md` | `docs/index.md` (player parts) |
| 01 | `01-player-sheet.md` | `docs/player-philosophy.md` |
| 02 | `02-team-culture.md` | `docs/team-culture-and-leadership.md` |
| 02b | `02b-dont-disappear.md` | `docs/dont-disappear.md` |
| 03 | `03-injuries-and-return-to-play.md` | `docs/injuries-and-return-to-play.md` |
| 04 | `04-communication-and-movement.md` | `docs/communication-and-movement.md` |
| 05 | `05-how-we-play.md` | New: game model and coaching literacy from `docs/coaching-game-model.md` and `docs/good-coaching-signs.md` |
| 06 | `06-film-review.md` | `docs/film-review-guide.md` |
| 07 | `07-home-development.md` | `docs/home-development.md` |
| 08 | `08-position-cards.md` | `docs/positions/index.md` |
| 09–15 | `09-goalkeeper.md` … `15-attacking-midfielder.md` | `docs/positions/*.md` |
| 16 | `16-closing.md` | `docs/coaching-game-model.md` §45 |

When a `docs/` chapter changes, update its track. An inserted track takes a letter suffix (`02b`) so existing MP3 filenames and web addresses don't change.

## Publishing a new or revised track

1. Prepare the listening transcript and generate the track.
2. Listen to the finished track before publishing, then put the MP3 in `docs/audio/` and add its player to `docs/audio/index.md`.
3. In the same commit, replace any text-only or "not yet included" note for that chapter on the audio page and update audio availability in the root README. Keep PDF and EPUB notes until those formats have also been updated.
4. If publishing an updated EPUB too, rebuild it from the transcripts, inspect it, and update its availability separately. Run `mkdocs build --strict` to check the website links before publishing.

See [Publishing updated editions](../README.md#publishing-updated-editions) for the PDF, EPUB, and audio release steps.

## Narration: ElevenLabs

- **Model:** Eleven v3. ElevenLabs recommends it for audiobooks, and it supports the audio tags below. It does **not** support SSML `<break>` tags.
- **Voice:** Amelia, a young Australian female voice described as "enthusiastic and expressive". Third-party listings give its ID as `ZF6FPAbjXT4488VcRRnw`; confirm it in the Voice Library.
- **Stability:** start with Natural. If tags are ignored, try Creative, which follows tags more closely but can hallucinate. Avoid Robust, which largely ignores tags.
- **Speed:** start at 1.0. The allowed range is 0.7–1.2.
- **Length:** v3 takes up to 5,000 characters per request, and Studio allows 5,000 per paragraph. Position cards (about 3,500 characters) fit in one request. Chapters run 11,000–20,000 characters and need three to five chunks, split at blank lines. The whole edition is about 153,000 characters, more than one month of Creator-plan credits (121,000).
- **Title line:** strip the leading `# ` before pasting a single track into Text to Speech.
- **Studio import:** run `./build-epub.sh` (needs pandoc). It builds `soccer-handbook-player-audio.epub`, with one Heading 1 per track, so Studio makes one chapter per track. Rebuild it after editing any transcript.

### Audio tags used

Tags go in square brackets inline with the text. They are meant to direct the delivery, not be spoken. The transcripts use only three:

| Tag | Use |
|---|---|
| `[pause]` | Before a say-along line, or after a signpost like "Let's try one now." |
| `[long pause]` | Thinking time: after a question, a quiz prompt, or a moment to picture |
| `[slows down]` | Before a mantra, cue list, or visualization, so the listener can say it along or picture it |

Blank lines between paragraphs add a natural beat, and commas and periods do the fine pacing.

### Test before generating everything

1. Generate `09-goalkeeper.md` first. It uses every device: say-along mantra, visualization pauses, a recall question and cues.
2. Listen for:
   - tags being read aloud (v3 sometimes does this when a tag doesn't suit the voice);
   - `[long pause]` being long enough to actually think;
   - `[slows down]` carrying over into the next line.
3. If long pauses are too short, split the audio at those points and insert silence with ffmpeg, rather than stacking tags.
4. If v3 isn't working out, strip the tags for Multilingual v2 with `sed -E 's/ ?\[[a-z ]+\]//g'`, then add `<break time="2s" />` where thinking pauses are needed (3 seconds maximum).

Words to check for pronunciation: Cruyff, rondo, futsal, Nordic, ACL, FIFA Eleven Plus, half-space. Fix them with a pronunciation dictionary, or in v3 with inline IPA between slashes.

## Engagement devices

- **Narration pattern.** A coach talking to one player: conversational setup, a concrete second-person example, explanation, then the headline principle as a landing point ("Remember: …"), with callbacks like "Different picture, same idea."
- **Say-along mantras.** Each of the four mantras is introduced as "Say the practice mantra with me", then a pause, then the words slowly. The mantras are named practice, game, next-play (Respond. Reflect. Learn. Next play.) and pressure (Want the moment.). Other say-alongs are kept few: position-card cues, the penalty routine, protect-slow-show-wait-win, the counterpress jobs, and "When in doubt, sit out."
- **Think-and-pause questions.** Questions tie ideas to the listener's own last game or practice, with a long pause before the narration continues.
- **Questions, not quizzes.** A few reflective questions with a long pause, and occasional quick recall (a communication call, the "when you're unsure" fallback on each card).
- **Guided rehearsals.** A penalty kick (track 02), the five mistake questions on a real mistake (02), a film review from memory (06), a mental rep (07), and a shoulder check "right now" (04).
- **Bookends.** The introduction asks for one thing to improve this season; the closing brings it back. The home menu asks the listener to pick two or three items at the start and asks again at the end.
- **Position cards.** "Close your eyes", a long pause after each moment to picture, a recall question before the "when you're unsure" fallback, say-along cues, and the film question to take into the match.

## Writing conventions

- No tables, links, symbols, or cross-references. Numbers and abbreviations are written as spoken: "the nine", "under-fourteen", "one-on-one", "nine, eight, eight".
- Mantras are in sentence case, not capitals. Capitals add emphasis in v3 and can come out shouted.
- Short signpost sentences ("Pressing together.") stand in for subheadings.
- Chapters that talk about "her" (the injured player, the player on the ball) are addressed to "you" where the listener is that player.

## Added from the coach and parent chapters

Coaching Game Model:

- **Track 02:** avoiding pressure is normal; rushed kicks miss more; "one kick, one lesson"; "Where's my spot?"; penalties are a skill, not a lottery (§28). Risk is contextual: brave versus careless (§27). "What did you see?" is an invitation (§43). "One position you can play, not the only one" (§29).
- **Track 03:** concussion signs and "When in doubt, sit out"; concussion return steps (§37). Heading safety: most concussions come from player contact, so make an early call and a committed jump, and never use elbows (§37).
- **Track 04:** what to look for when scanning, and "one look before receiving" (§34). "The pass tells the receiver which way to turn"; receiving under pressure is a skill (§34). Delay defending: protect, slow, show, wait, win (§21).
- **Track 05 (new):** how good coaching works and how training creates habits and gaps (§1, §40–41, §43, `good-coaching-signs.md`), four moments and relationships (§4–5, §16), building from the back (§18–19), team identity (§1), middle gear (§7–8), make a defender choose (§9), deception (§10), third player (§11), five lanes and weak side (§14–15), create advantages (§42), losing the ball and rest defense (§5, §20), pressing together and second balls (§23), restarts (§24), game state (§25).
- **Track 07:** growth and maturation (§36); the injury-prevention warm-up cuts ACL injuries roughly in half (§36).
- **Track 16:** team identity (§45).

Parent Partnership:

- **Track 07:** fueling, and missed periods as a health signal.

## Left out

- Printable templates, sources, and links.
- League and streaming search tips. They go stale and don't work aloud; the film track points to the written handbook instead.
- Coach-only and parent-only material: session-planning detail, coach safeguarding logistics, and sideline and after-game guidance for parents. (Track 05 does explain, for players, how good practice works.)
