# Shelf v1
- [x] Verify APIs and capture fixtures
- [x] Implement ShelfCore models, sources, auth and tests
- [x] Build native tvOS UI and Xcode project
- [x] Run final fixture/live tests and generic tvOS build
- [x] README and final review
- [x] Local commit (no push)

Constraints honored: no simulator download or device installation; no credentials in repo; no subagents.

# Hanime1 addition
- [x] Inspect forms, card layouts and player variants with URLSession
- [x] Add source, shared browser filters and separate Tab
- [x] Fixture + live tests, generic build, README and local commit

# Apple TV device validation
- [ ] Confirm automatic signing and register paired TV
- [x] Add remote-driven XCUITest target and test-only muted playback progress
- [ ] Run device tests, export and inspect all named screenshots
- [ ] Fix observed issues and rerun affected tests
- [ ] Commit and leave normal signed app installed (no push)

Device phase blocked: Xcode has no logged-in Apple Accounts and no tvOS provisioning profiles. Await account login before any install/test/screenshot claim.
