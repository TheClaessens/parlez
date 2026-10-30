# Island redesign: show the Dictation working, and confirm how it ended

Status: resolved

## Problem Statement

The Island does its job, but it looks like a placeholder and tells me less than I need. While I talk it shows five white bars under the notch; while the Transcript is produced it shows the stock system spinner. I can't tell how long I've been talking, and the plain black pill below the notch doesn't look like part of the Mac. When a Dictation ends, the Island just disappears, whether the Transcript was pasted, I pressed Esc, or Voz heard nothing, so I have to look at the Caret to find out what happened. The automatic stop after 30 s of silence comes without warning. Error messages are a single red line that says what went wrong but not what to do about it, and "Finish Setup" looks as alarming as a real failure.

## Solution

The Island works beside the notch, the way an iPhone's Dynamic Island shows a live activity. While I dictate it stays the height of the notch:
- **Recording:** a pulsing red dot and the elapsed time sit on the left of the notch, and a live waveform sits on the right.
- **Transcribing:** the time freezes, the dot becomes a thin spinner, and the waveform settles into a shimmer that runs across it.

The Island's top corners curve into the screen edge like the notch's own, and the menu bar icon turns red while recording.

The Island only grows a row below the notch when it has something to say:
- every ending is confirmed: "Pasted · N words", "Cancelled · nothing pasted", "Nothing heard";
- in the last 10 s before an automatic stop, a countdown ring with "No speech · stopping in N s" (or "Time limit · stopping in N s");
- a problem shows an icon, the problem, and a second line with the fix.

"Finish Setup" is amber rather than red, and a press while busy shakes and says "Still transcribing". On a screen without a notch the same content sits in a floating pill under the menu bar.

The design canvas has a working prototype of every state: https://claude.ai/artifact/8cXLmDpr6Np15qAoYS9Jb8

## User Stories

### Working beside the notch

1. As a user, I want a pulsing red dot beside the notch while recording, so that I can see at a glance that Parlez is listening.
2. As a user, I want the elapsed time of the Recording beside the notch, so that I know how long I've been talking.
3. As a user, I want a live waveform beside the notch driven by my voice, so that I know the microphone is actually hearing me.
4. As a user, I want the Island to stay the height of the notch while recording and transcribing, so that it doesn't cover the top of the window I'm dictating into.
5. As a user, I want the Island's top corners to curve into the screen edge like the notch's own, so that it looks like part of the Mac rather than something stuck on top.
6. As a user, I want the Island to keep its shape when recording turns into transcribing, so that nothing jumps when I stop.
7. As a user, I want a spinner and a shimmering waveform while the Transcript is being produced, so that I know it's working.
8. As a user, I want the elapsed time to freeze when I stop, so that I can see how long the Recording was while it is transcribed.
9. As a user, I want the menu bar icon to turn red while recording, so that I have a second cue when I glance at the menu bar.
10. As a user with no notch on the current screen, I want the same dot, time and waveform in a floating pill at the top centre, so that the feedback is the same everywhere.
11. As a user, I want the Island to spring smoothly between its sizes, so that changes read as one continuous object.
12. As a user, I want the Island to keep never taking focus or mouse input, so that dictating never disturbs the app I'm typing in.

### Every ending is confirmed

13. As a user, I want a short "Pasted" confirmation with a green check when the Transcript lands, so that I know it worked without looking at the Caret.
14. As a user, I want the confirmation to show how many words were pasted, so that I can tell at a glance whether the whole Transcript arrived.
15. As a user, I want a short "Cancelled · nothing pasted" confirmation when I press Esc, so that I know the cancel took.
16. As a user, I want a short "Nothing heard" confirmation when the Transcript is empty, so that I know why nothing was pasted.
17. As a user, I want an accidental tap (a Recording under 0.3 s) to stay silent, so that a double-tap still does nothing visible.
18. As a user, I want each confirmation to last about 1.5 s and then collapse into the notch, so that it gets out of my way quickly.
19. As a user, I want starting a new Dictation to clear any confirmation at once, so that a fast second Dictation isn't held up.

### Messages that say what to do

20. As a user, I want every error to show an icon, the problem, and a second line with what to do, so that I can fix it without guessing.
21. As a user, when the microphone doesn't start, I want to be told where to grant microphone access, so that I can fix it straight away.
22. As a user, when transcription fails, I want to be told that nothing was pasted and to try again, so that I know where I stand.
23. As a user, when the paste fails, I want to be told the Transcript is on my clipboard and to press ⌘V, so that I don't lose my words.
24. As a user, when I press the Dictation shortcut before Setup is complete, I want an amber "Finish Setup to dictate" with where to go, so that it reads as a step left rather than a failure.
25. As a user, when I press the Dictation shortcut while transcribing, I want the shake plus "Still transcribing", so that I understand why nothing happened.
26. As a user, I want error and Setup messages to stay up for about 3 s, so that I have time to read two lines.
27. As a user, I want errors, warnings and confirmations to differ in their icon as well as their colour, so that I can tell them apart without relying on colour.

### Countdown before an automatic stop

28. As a user, I want the waveform to drop to still dots while I'm silent, so that I can see the microphone isn't hearing speech.
29. As a user, I want a countdown ring with "No speech · stopping in N s" in the last 10 s before the silence stop, so that the automatic stop is never a surprise.
30. As a user, I want the countdown to disappear as soon as I speak again, so that thinking pauses don't leave a warning up.
31. As a user, I want a "Time limit · stopping in N s" countdown in the last 10 s before the 10-minute stop, so that a long Dictation doesn't end without warning.
32. As a user, I want an automatic stop to still transcribe and paste what I said, with the same "Pasted" confirmation, so that I don't lose anything.

## Implementation Decisions

- **Dictation core** stays the one place that decides what happened; the Island only renders it and owns every word of copy, colour and duration. Its interface changes as follows:
  - **Signal kinds** become: `busy`, `setupUnfinished`, `pasted(words)`, `cancelled`, `nothingHeard`, and `error` carrying one of a fixed set of reasons: microphone didn't start, couldn't transcribe, paste failed. The free-text error message goes away; the Island maps each reason to a title and a fix line.
  - `pasted(words)` is raised after a successful insert; words is the number of whitespace-separated words in the Transcript. A failed paste raises the paste-failed error instead, never both.
  - `cancelled` is raised when Esc cancels a recording. Throwing a recording away because Setup became incomplete raises nothing new; a Recording under 0.3 s raises nothing.
  - `nothingHeard` is raised when the Transcript is empty or whitespace.
  - **`recordingStartedAt`**: the instant the current Recording started, readable while recording, nil otherwise. The Island freezes its displayed time itself when the state leaves recording.
  - **`automaticStop`**: while recording, the earliest pending automatic stop, as an instant plus a reason (`silence` or `lengthLimit`); nil otherwise. The silence stop is pending only while the current run of silence lasts. The Island shows the countdown when the instant is 10 s away or less. The core's own stop rule uses the same values, so the countdown and the actual stop cannot disagree.
- **IslandLayout**: the panel's frame stays fixed at the Island's largest size, so the panel never resizes mid-animation. Starting sizes, in points, tuned by eye:
  - beside the notch: the Island reaches 85 pt past each side of the notch while working; a message row is 36 pt below the notch, a two-line row 52 pt; a two-line row widens the Island a further 13 pt each side; the curved top corners need 7 pt outside each side. The frame is therefore the notch width plus 210 pt by the notch height plus 52 pt.
  - floating: a 167 × 36 pt pill while working; a message or countdown widens it to 312 pt and adds its row (36 or 52 pt) below the working row, as under the notch, or is the whole pill once the Dictation has ended. The frame fits the working row plus a two-line row, with room for the ±6 pt busy shake: 324 × 88 pt, 6 pt below the menu bar.
- **Island view**: the compact working shape, waveform, shimmer, countdown ring and message rows are drawn in the Island view, driven only by the core's state, level, signal, `recordingStartedAt` and `automaticStop`. The waveform is driven by the live level, with per-bar variation so it doesn't move as one block. The existing level gain constant and its hand-tuning note carry over. Durations: confirmations and the busy message about 1.5 s, error and Setup messages about 3 s.
- **Colours**: the Island stays true black. Recording red, confirmation green and warning amber are the macOS system red, green and yellow. Secondary text is white at about 60 %.
- **Menu bar icon**: the app tints the menu bar icon red while the state is recording.
- No new ADR: nothing here changes a recorded decision.

## Testing Decisions

- Test external behaviour only: what a Dictation does and signals in response to events, never how the core stores it.
- **Dictation core**, alongside the existing Dictation tests, with the same fake Microphone, Transcriber, Inserter and clock:
  - a successful Dictation raises `pasted` with the right word count;
  - Esc raises `cancelled`; an empty Transcript raises `nothingHeard`; an accidental tap raises nothing;
  - each failure raises its error reason (the three existing error assertions change from text to reasons);
  - `recordingStartedAt` is set while recording and cleared after;
  - `automaticStop` reports the length limit while there is sound, switches to the silence stop when silence starts, goes back when sound returns, is nil outside recording, and the automatic stop happens at the instant it reported.
- **IslandLayout**, alongside the existing layout tests: the two existing cases get the new frames (on the 14" example: 430 × 90 pt at the top centre; on the external display: 324 × 88 pt, 6 pt below the menu bar).
- **By hand**, on the README checklist: everything the Island draws, its animations, the menu bar icon, and both screen types. These are thin renderings of tested values.

## Out of Scope

- Clicking the Island (it keeps ignoring mouse input), so no "Open Settings" button on an error.
- Showing the Transcript's text on the Island.
- Sounds on start, stop or confirmation.
- A history of Transcripts.
- A waveform that scrolls with history; the bars react to the current level only.
- Changing the silence threshold, the 30 s silence limit or the 10-minute limit.
- Light-mode Islands or user-chosen colours.

## Further Notes

- This supersedes Parlez spec stories 21 to 24 (level meter, spinner, shake and red message), keeping their intent.
- "Nothing heard" was not on the design canvas; it closes the one ending that otherwise collapses without a word.
- Copy for the fix lines: microphone didn't start → "System Settings › Privacy › Microphone"; couldn't transcribe → "Nothing was pasted. Try that Dictation again."; paste failed → "The Transcript is on your clipboard: press ⌘V"; Setup unfinished → "Open Parlez from the menu bar".
