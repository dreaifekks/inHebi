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
- [x] Fix focused cover/title spacing. The later coordinator correction removes the two-complete-rows constraint and restores full-width covers.
- [x] Join reader pages at a common height; anchor pairing at the selected page; bottom-row Down dismisses controls; move page count right.
- [x] Add core and frame-based device regression coverage; update documentation.
- [x] Run core offline/live, generic build, and affected device tests in foreground.
- [x] Commit, install normal signed app, then create the requested read-only Claude reviewer child.

CoreDevice discovery timed out inside the sandbox; succeeded with authorized host access.

# Full-width grid correction — 2026-10-14

- [x] Fetch current device focus trace; preserve the reader implementation.
- [x] Restore full column width and original cover ratios; retain 32pt focus clearance.
- [x] Validate offline tests, verify.sh, and affected device grid tests; record actual focused frames.
- Release handoff: new commit and normal signed build 17; receipt artifacts/grid-restore-install.log. No further reviewer requested.

# Reader and AVKit panel interaction — 2026-10-14

- [x] Read current handoff, fetch user device focus trace, check parallel-test occupancy.
- [x] Capture native player key behavior and attempt late-page thumbnail reproduction before fixes (page 17 passed; no claim of reproduction).
- [x] Implement reader directional entry/edge dismissal and current-page visibility-driven focus; burst acceptance pending below.
- [x] Keep native AVKit controls, apply only supported changes, document verified limitations.
- [x] Run offline, verify.sh, and affected device tests without overlapping another session (10 distinct final passes).
- Release handoff: new commit and normal signed build 18, then requested read-only Claude child review; forward its result unchanged and wait for coordinator decisions.

Scope excludes identifiers, display name, Info.plist and project generator naming, which another worktree owns.


# inHebi integration delivery — 2026-10-14

- [x] Read both versions of README/HANDOFF; merge both feature branches as a separate merge commit.
- [x] Add closing-direction quiet window, current-page Up focus, and Menu-while-playing regression coverage.
- [x] Rename internal project/targets/module/types/scripts in a separate commit; preserve models, identifiers and Top Shelf assets.
- [x] Finish offline/live tests, generic compile, full device suite, targeted failure fixes and real CloudKit export.
- Normal signed installation and requested Claude read-only review are the remaining delivery actions after the acceptance commit; use artifacts/final-install.log for the actual installed build.
