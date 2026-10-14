# Filter chip symbols

- [x] Confirm every proposed symbol in Apple's tvOS availability metadata.
- [x] Centralize symbols, remove checkmarks, preserve selected semantics and dimensions.
- [x] Verify symbol construction and equal selected/unselected layout widths on device.
- [x] Fix observed sorting label truncation by widening fixed controls.
- Final device suite and captures: artifacts/chip-symbol-acceptance.log / artifacts/screenshots.
- Combined app-icon + chip-style build receipt: artifacts/final-verification.json.

Physical touch-surface feel and app-icon parallax remain manual verification. Commit, no push.

# Reader and card layout revision — 2026-10-14

- [x] Read HANDOFF/README and fetch the existing device focus trace.
- [x] Fix focused cover/title spacing and fit two complete rows in all grid orientations.
- [x] Join reader pages at a common height; anchor pairing at the selected page; bottom-row Down dismisses controls; move page count right.
- [x] Add core and frame-based device regression coverage; update documentation.
- [x] Run core offline/live, generic build, and affected device tests in foreground.
- [ ] Commit, install normal signed app, then create the requested read-only Claude reviewer child.

CoreDevice discovery timed out inside the sandbox; succeeded with authorized host access.
