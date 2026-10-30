# 08: Release zip and README

**What to build:** Friends can download Parlez from GitHub Releases and run it without building anything. The build script gains a release mode that produces a zip of the signed app. The README explains what Parlez is, how to install from a release including the one-time "Open Anyway" step in Privacy & Security, how to build from source, and the hand-check checklist from the spec's Testing Decisions. It credits "Powered by Desert Ant Labs" and links the Voz license. The project gets an MIT `LICENSE`. Spec user stories 44–47.

**Blocked by:** 05, 06, 07

**Status:** ready-for-agent

- [ ] Release mode produces a versioned zip of `Parlez.app` that unpacks to a working app.
- [x] The README covers install from a release (with "Open Anyway"), build from source, manual updates, the hand-check checklist, the Desert Ant Labs credit and the Voz license link.
- [x] An MIT `LICENSE` file is present.
