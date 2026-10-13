# Verification record — 2026-10-14 JST

Implementation complete. No subagent sessions, no simulator runtime installation, no device installation, no remote/push.

## Environment

- Xcode 27.0 (27A266a), tvOS Simulator SDK 27.0, deployment tvOS 18.0.
- `xcrun simctl list runtimes`: iOS 26.5, iOS 27.0, watchOS 27.0 only; no tvOS runtime.
- Apple Development certificate OU confirms team ALZ45VUZFN (matches local Developer ID team); configured for automatic signing. A second team exists; device signing not attempted.
- SwiftSoup 2.14.2 pinned in both SwiftPM and Xcode resolved files.

## Commands and outcomes

1. `swift test --package-path Packages/ShelfCore`
   - Earlier offline run: 10 tests, 2 opt-in live tests skipped, 0 failures. Subsequent new pagination fixture test is included in the full run below.
2. `SHELF_LIVE_TESTS=1 ./script/verify.sh`
   - Final run ended 02:51 JST.
   - 11 tests executed, 0 skipped, 0 failures: 8 parsing/layout tests, 1 auth request/refresh/logout test, 2 live tests.
   - iwara list: 24 results; detail parsed; Source/540/360/preview resolved; Source range request HTTP 206, 1,024 bytes; normal thumbnail 9,148 bytes; search 32 results.
   - wnacg list: 20 results; detail and gallery agree on 11 pages; first WebP HTTP 200, 496,576 bytes and ImageIO decode succeeds; categories 20; category page 2 returns 20; search 24 results.
   - `xcodebuild -project Shelf.xcodeproj -scheme Shelf -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build`: BUILD SUCCEEDED, arm64 + x86_64.
   - No Swift compiler warnings/errors. Xcode emits the harmless “Metadata extraction skipped, no AppIntents.framework dependency found” message.
3. Additional direct URLSession checks:
   - iwara search singular `type=video`: HTTP 500; plural `type=videos`: HTTP 200.
   - custom thumbnail original/thumbnail/large variants: HTTP 200 image/png.
   - guest lists: limit=2 count=3; limit=24 page=0 count=25; page=1 count=49. Guest pages work; count is not a reliable total.
4. Fixture scan: no unredacted hash/verify signed-link parameters, account login tokens or passwords. No media binaries retained. Repository contains only fake auth test credential strings.

## Unverified

- Real iwara credentials, account-specific content, server-side token expiration and Keychain persistence across a real tvOS launch.
- Live visual layout/focus/remote interaction, AVPlayer playback and codec support on Apple TV.
- Automatic provisioning, device signing/install and launch.

## Fixes found during implementation

- Throwing SwiftSoup selector in boolean guard needed outer `try`.
- Gallery document.writeln contains raw tab characters, not strict JSON; escape tabs before decoding the string.
- Search uses videos (plural); wnacg search paginator has numeric links without `.next`.
- Double-page reader stops at the final complete spread, avoiding an extra duplicate final page.
- Initially sandboxed Keychain query returned zero identities; authorized read of public certificate metadata found the correct team.

## Hanime1 addition

- Reused VideoBrowser, VideoDetail and system player. Added optional source categories/search-filter capability; existing iwara calls retain default category. Separate Hanime1 Tab; no auth added.
- Verified the current search form and sampled ten actual genres. All sampled players exposed MP4 source tags, including 480/720/1080. No script-only/HLS samples found.
- Added 5 fixture tests for form values, horizontal cards/ads/deduplication, portrait/empty results, detail/quality order and URL encoding/page translation; added live list/page2/category/search/detail/range/thumbnail test.
- Initial fixture run found a forced URL unwrap on non-search tag actions; replaced it with extraction of real tag/search link text. Form verification selectors corrected to actual data-value elements.
- `SHELF_LIVE_TESTS=1 ./script/verify.sh` at 02:58–02:59 JST: all 17 tests passed, no skips; generic tvOS Simulator build passed.
- Hanime1 live evidence: list 59, page 2 59 with different first ID, portrait category 41, filtered MMD search 59; detail qualities 1080p/720p/480p; best stream HTTP 206, 1,024 bytes; thumbnail 65,027 bytes. iwara and wnacg live tests also passed unchanged.
- After removing an unnecessary `try` warning, `./script/verify.sh` at 03:00 JST passed: 17 tests total, 3 opt-in live tests skipped, 0 failures; generic build succeeded, no Swift compiler warnings. Only the pre-existing AppIntents metadata-skip message remains.
- Hanime1 fixtures scanned: no unredacted secure URL parameters or CSRF fields; no downloaded media saved. Runtime TV UI/remote/playback remains unverified because this session has no tvOS runtime/device.

## Physical Apple TV validation — blocked on Xcode account

- Device dreaifeのApple TV, UDID <Apple TV 设备标识>, reachable/connected. Existing configured team ALZ45VUZFN retained (confirmed from Apple Development certificate OU in v1).
- Added ShelfUITests target, four remote-driven test paths, keepAlways named screenshot attachments, teardown termination, test-only muted AVPlayer clock/state observation and artifact export scripts.
- `xcodebuild ... -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing`: TEST BUILD SUCCEEDED. No Swift compiler warnings after removing actor-isolation warnings in test lifecycle. This compiles tests; it does not execute them.
- Initial signed device build and `./script/test-device.sh <Apple TV 设备标识>` both stopped before installation/test execution, exit 65.
- Logs: artifacts/device-signing-build.log and artifacts/device-ui-test.log. xcresult: artifacts/device-ui-20261014-030544.xcresult.
- Complete signing errors (no bypass attempted):

```
No Accounts: Add a new account in Accounts settings. (in target 'ShelfUITests' from project 'Shelf')
No profiles for 'com.dreaife.shelf.uitests.xctrunner' were found: Xcode couldn't find any tvOS App Development provisioning profiles matching 'com.dreaife.shelf.uitests.xctrunner'. (in target 'ShelfUITests' from project 'Shelf')
No Accounts: Add a new account in Accounts settings. (in target 'Shelf' from project 'Shelf')
No profiles for 'com.dreaife.shelf' were found: Xcode couldn't find any tvOS App Development provisioning profiles matching 'com.dreaife.shelf'. (in target 'Shelf' from project 'Shelf')
Testing cancelled because the build failed.
```

- User action requested: sign into the ALZ45VUZFN developer account in Xcode → Settings → Apple Accounts. Certificate/private-key presence alone does not provide portal account access for profile creation.
- All actual TV paths, exported screenshots/visual review and normal signed installation remain pending. No runtime downloaded. UI navigation assumptions are not yet verified on TV.
- `xcresulttool export attachments` succeeded with an empty manifest; artifacts/screenshots/index.json is `[]`, so no screenshots are claimed or visually reviewed.
- `xcrun devicectl device info apps --device <Apple TV 设备标识> --bundle-id com.dreaife.shelf` returned no app. No Shelf build is installed on the TV by this task.
- Prepared code is committed separately; device execution, visual fixes if any, and final signed installation must resume after account login.

## Device validation resumed with API-key provisioning

- User authorized App Store Connect API-key use exclusively for this project's signing and device registration. Script consumes SHELF_AUTH_KEY_PATH, SHELF_AUTH_KEY_ID and SHELF_AUTH_KEY_ISSUER from the environment; no key contents or identifiers are stored in tracked files.
- Device build products now use artifacts/DerivedDataDevice. Starting with the iwara detail test to establish actual focus hierarchy before running all paths.

## Final TV test and visual verification

- `./script/test-device.sh DEVICE_UDID` with API-key environment: **4 tests passed, 0 failures**, 95.253 seconds on AppleTV14,1 / tvOS 27. Result: artifacts/device-ui-20261014-031854.xcresult; log: artifacts/device-fixes-run.log.
- Paths: tabs/settings; iwara list -> detail; Hanime1 list -> detail -> actual muted AVPlayer playback; wnacg list -> album -> page 1 -> page 3 -> spread -> exit.
- Actual playback evidence: AVPlayer playing, muted=true, time 1.0 -> 3.5 seconds. Playback is terminated after the short sample. Every test terminates the app in teardown.
- All 12 exported named screenshots were individually inspected after fixes:
  - 01-home-iwara, 02-hanime-list, 03-comic-list: content and covers loaded, focused card outline/scale visible. Current filters readable. Card titles occupy two lines; longer titles retain intentional ellipsis, full titles visible in details.
  - 04-settings: email focus visible, labels/description readable, no overlap.
  - 05-iwara-detail, 06-hanime-detail: full tested titles now on-screen with cover, author/duration, quality and Play; long description independently scrolls.
  - 07-hanime-playing: actual video frame and player clock shown; test-only overlay confirms muted state.
  - 08-album-detail: full tested title, page count, cover and Read visible.
  - 09-reader-single, 10-reader-page-three: image fits full screen height with side letterboxing; page indicator advances.
  - 11-reader-spread: right image matches page three screenshot, left image is next page; both height-fit, no overlap.
  - 12-hanime-categories: native scrollable option list has full labels and visible focus/checkmark.
- Fixed the observed layout/focus defects and reran all four affected paths successfully. No remaining blocking visual defect in these screenshots. Real iwara account login still requires the user.
- Normal development installation is performed from the committed code by script/install-device.sh; it embeds ShelfCommit and build number. Its receipt/log and final metadata are under ignored artifacts/, so no credential identifiers or screenshot files enter git.
