# Retouche runs on Apple's on-device model

Parlez's original spec ruled out any rewriting of the Transcript. We now add Retouche, an optional step that applies the speaker's self-corrections, and run it on Apple's on-device Foundation Models: Parlez is a Mac app, the model ships with macOS 26 and later at no cost and with nothing to download, and the text never leaves the Mac. This is a decision under test, not a settled one: if Retouche doesn't perform well enough in daily use, another model may replace it.

## Considered options

- **Apple's on-device model (chosen).** The prototype (branch `prototype/edit-spike`, see its `VERDICT.md`) applied 5 of 6 self-corrections exactly, in English, Dutch and mixed, and left clean text alone. It sometimes acts on the content (a dictated "write an email…" became an email), so a Retouched Transcript that adds line breaks, or fewer than 90 % of whose words appear in the Transcript, is discarded for the Transcript. It can also cut more than it should, which no check catches.
- **A cloud model (Claude, Apple's Private Cloud Compute).** Better edits, but the text leaves the Mac, which breaks the reason Parlez exists. Private Cloud Compute also failed from an unbundled tool.
- **Desert Ant Labs' Uhm.** Detects fillers from the audio only; it does not handle self-corrections.

## Consequences

- Retouche needs macOS 26 and Apple Intelligence. Parlez keeps macOS 15 as its minimum; where Retouche is unavailable, Dictations insert the plain Transcript.
- It adds about 35–40 ms per word after transcribing, and a Transcript longer than the model's context window (~1,700 words) is not retouched.
