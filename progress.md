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

- Device Apple TV test device, UDID ${SHELF_DEVICE_ID}, reachable/connected. Existing configured team ALZ45VUZFN retained (confirmed from Apple Development certificate OU in v1).
- Added ShelfUITests target, four remote-driven test paths, keepAlways named screenshot attachments, teardown termination, test-only muted AVPlayer clock/state observation and artifact export scripts.
- `xcodebuild ... -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing`: TEST BUILD SUCCEEDED. No Swift compiler warnings after removing actor-isolation warnings in test lifecycle. This compiles tests; it does not execute them.
- Initial signed device build and `./script/test-device.sh ${SHELF_DEVICE_ID}` both stopped before installation/test execution, exit 65.
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
- `xcrun devicectl device info apps --device ${SHELF_DEVICE_ID} --bundle-id com.dreaife.shelf` returned no app. No Shelf build is installed on the TV by this task.
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
- Normal signed installation succeeded after the UI fixes. Metadata verification found Xcode omitted an arbitrary INFOPLIST_KEY custom field; added an explicit Info.plist mapping for SHELF_COMMIT before final reinstallation. No runtime/UI code changed in this metadata-only follow-up.

## Redesign stage 1
- Added key-retaining Pager and explicit URLSession cancellation handling, JWT exp refresh and expired-session guest fallback with settings notice, source-owned album first page/Referer, and cancellable structured image loading with size-aware cache keys.
- Offline regression: 22 tests total, 3 opt-in live tests skipped, 0 failures. Includes return-with-same-key, filter change, cancelled pager retry, real URLSession consumer cancellation, token refresh without server 401, and 403 user-token guest fallback.
- Generic tvOS Simulator SDK application build passed. Removed device identifiers/names from tracked documentation.

## Redesign stage 2
- Added iwara statistics/resolution/date/rating/author/embed metadata and validated author, related and tag browsing; list custom covers use large, detail uses original.
- Added Hanime1 list metadata, detail category/views/date/feedback, typed tag links, creator and related card rows; added wnacg parent/child categories, page counts/date/tags/preview thumbnails and tag pagination.
- Fixture + actual live suite: 25 tests, 0 skipped, 0 failures. Actual expired iwara user token falls back to a usable guest list. All newly requested endpoints were reachable; author and tag result content was checked, not just status code.
- Probe image samples: iwara large 654x490; wnacg cover 300x400. Generic tvOS build passed.

## Redesign stage 3
- Implemented fixed horizontal browsing strips, four/five column image-only focus cards, automatic pagination, separate search screens, retained focus/scroll, persisted filters and direct Play/Pause actions.
- Implemented rich fixed video headers, actionable description/tags/authors and media rails; rich album details/previews; bounded reader progress, thumbnail jumping, remembered spreads/direction; actual end-of-item dismissal and external player metadata.
- Layout values and decode caps are centralized in Shelf/Layout.swift. Test preferences are isolated from normal user preferences.
- Generic tvOS application build and build-for-testing both passed. Device behavior validation follows; optional borderless/searchScopes are exposed only by a Debug test probe route, not normal product navigation.

## Redesign device findings
- Device asleep initially; XCUIRemote Home before app launch wakes it. No simulator runtime was installed.
- Verified 4-column layout: image 404x227.5pt, complete cell ~349.5pt; eight complete cells fit the first screen. Retained 48 loaded items through detail pop and Tab changes with unchanged request count, original focused ID and frame; automatic next-page loading passed.
- Native safeAreaInset did not contract with hidden Tab bar and focused-header behavior disturbed scrolling. Replaced it with an independent fixed header above the vertical ScrollView. Native Menu returns to the Tab bar; FocusState handoff makes Down target the strip.
- Native conditional bordered/borderedProminent style swaps lost chip focus. Keep one native prominent style and distinguish selected with cyan plus checkmark; explicit FocusState horizontal routing keeps the scrolling chip strip traversable without loading.
- Sheets visually focused the correct row; XCTest must inspect the focused row's descendant button rather than the button's hasFocus alone. Current selection reopening passed.
- Native .card image-only labels and .borderless image-plus-title were both probed on device; borderless floats the image. Product retains the specified .card image-only composition.
- Native searchable and searchScopes render on pushed pages, but native searchable did not submit via remote Down or Return on this device. Product uses a TextField only on the search subpage; actual MMD submit -> results passed. searchScopes remains Debug probe only.
- Actual iwara and Hanime1 playback advanced with muted=true; Menu exit stopped AVPlayer. Seeking to the final second exercised the real end-of-item notification and returned to detail. AVKit Info shows title/artwork; artist also supplied as description for visibility.
- Reader jump 3 -> 5, continued turn to 6, double pages 6-7, and reverse direction all passed. SwiftUI fullScreenCover return produced unreliable focus; reader switched to a full-screen navigation destination with hidden Tab bar, now under validation.
- Source metadata snapshot correction: Hanime duplicated responsive playlist headings; use first heading. Detail titles keep their vertical layout, descriptions explicitly align left.


## Redesign acceptance evidence

- Core final offline command: `swift test --package-path Packages/ShelfCore` — 26 tests, 3 opt-in live tests skipped, zero failures (`artifacts/redesign-offline-final.log`).
- Core final live command: `SHELF_LIVE_TESTS=1 swift test --package-path Packages/ShelfCore` — 26 tests, zero skipped, zero failures (`artifacts/redesign-live-final.log`). Hanime1 and iwara signed video URLs returned 206; wnacg first page image returned 200 and decoded. New metadata/hierarchy/previews use real saved fixtures.
- Corrections to stage 2 above: iwara related worked for the old sample, but repeated requests for current newest videos returned HTTP 500. Removed that source capability; author and tag matching remain validated. This is an endpoint limitation, not a hidden fallback.
- All five review fixes are covered: Pager key and cancellation regressions; user-token 403 -> guest and expiration notification; expired JWT refresh despite HTTP 200; AlbumSource owns start page and Referer; URLSession consumer cancellation reaches URLProtocol.stopLoading.
- Main device acceptance completed 11 tests with zero failures, then screenshot review tightened search assertions to scope results to the pushed search page (underlying list no longer counts). Actual keyboard Search completion now passes. Reader toolbar thumbnail height and full-width focus section were corrected so a thumbnail near the left edge can reach the lower buttons.
- Screenshot review also found the root browser's visible Tab preference overriding the reader's hidden preference. Reader activity now controls the root preference, keeping the navigation-based reader full-screen while preserving card focus on return. Final verification follows below.

### UX spec section 14

| Item | Actual device result / adopted implementation |
| --- | --- |
| 1. top safeAreaInset | Did not contract/scroll as required with tvOS Tab behavior. Use a fixed sibling header above ScrollView; 80pt accommodates native buttons. First screen contains eight complete landscape cells. |
| 2. Menu -> Tab -> Down | Native Menu reaches Tab. Explicit FocusState handoff makes Down enter the fixed strip. |
| 3. default focus | Sheet selected row and async-loaded Play/Read focus pass. Tests inspect native row-container focus where applicable. |
| 4. card/borderless | Both rendered on device. borderless floats image; production keeps card on image-only label, text outside. |
| 5. Play/Pause on card | Delivered on video and album cards; starts actual player/reader. |
| 6. return focus | Native restoration alone was insufficient across Tab/full-screen reader returns. Retain key/items, numeric scroll offset and card ID; explicitly restore. Reader uses a navigation destination; video modal returns focus to Play/card. |
| 7. search | searchable/searchScopes render, but searchable keyboard did not submit reliably. Product uses TextField on a dedicated search page and the native keyboard completion button. Scopes remain test-probe-only. |
| 8. data endpoints/images | iwara author/tag work; related disabled for repeated 500 on current videos. wnacg tag pagination is albums-index-page-N-tag-TAG.html and page 2 works. iwara large sample 654x490, wnacg thumbnail 300x400; five comic columns retained after inspection. |

### Deliberate scope and visual limits

- Landscape image 344x194 -> 404x227.5pt: about 38% larger area; image/cell height share about 53% -> 65%. Four columns and two complete rows. Portrait lists remain five columns.
- Rich video details include available author/date/duration/resolution/statistics/rating, expandable description, tags, creator rail; Hanime1 also related rail. Album details include category/date/pages/tags, first-page preview strip and Continue page action.
- Long card titles retain the specified two-line ellipsis, long detail titles up to three lines. No overlapping controls in reviewed screens. Source thumbnails can be soft, especially enlarged wnacg detail cover; no artificial upscaling is attempted.
- Unselected P2 remains omitted: playback resume, search history, product searchScopes, subscriptions/rankings, file size, additional comment details, reader page-number auto-fade and specialized long-strip reader. The user specifically requested live validation of author/tag endpoints, so working tag navigation is enabled.
- Existing Keychain login was preserved and restored; no real password was entered by the agent. Playback verification remains muted and brief. Every test terminates the app, including failures.


## Redesign final run and screenshot sign-off

- Final complete device command: `./script/test-device.sh "$SHELF_DEVICE_ID"` (API signing values supplied via environment) — **11 tests, 0 failures, 375.039 seconds**. Log: `artifacts/redesign-device-final.log`; result: `artifacts/device-ui-20261014-063102.xcresult`.
- Added only a screenshot attachment for the open reader toolbar and reran the affected reader path — **1 test, 0 failures, 56.554 seconds**, log `artifacts/redesign-reader-toolbar-capture.log`. No app source changed after the complete run.
- Latest generic Simulator SDK build: **BUILD SUCCEEDED**, `artifacts/redesign-simulator-final.log`. No simulator runtime was downloaded. Core final results remain 26 tests, zero failures with live mode enabled.
- All **30 named final PNGs**, 01 through 30, were opened and inspected individually after export. All real content screens contain loaded covers/pages. Landscape first screens show two complete rows; image-only card focus, selected strip checkmarks, default Play/Read focus and current sheet selection are visible. There are no unintended overlapping labels or controls; the documented two/three-line truncation remains for unusually long source titles.
- Screenshots 06/07/09 confirm the same scrolled card and content before detail, after return and after a Tab round-trip; assertions additionally verify item count/request count and frame within 4pt. 08 shows Menu -> Tab -> Down strip focus.
- 10/14 show actual iwara/Hanime1 video frames and muted advancing clocks; 15 shows end-of-item return; 27 shows native title/author/artwork. Menu exits assert inactive player and stable stopped clock.
- 17/18 show full-height single-page fit; 19 right-opening spread places page 6 on the right (matches 18); 29/30 left-opening spread places page 2 on the left (matches 29). No Tab bar remains over the reader. 26 shows loaded jump thumbnails, current page focus and the lower toolbar without the previous excessive gap.
- 20 confirms the saved-page Read label; 21 the direction setting; 22-24 the optional native component probes; 25 is the actual pushed search result grid; 28 is the five-column portrait layout.
- Remaining user verification: fresh password login, normal audio output, and living-room viewing comfort. Existing Keychain login was not removed; UI preferences were isolated.
- Post-commit normal installation uses `script/install-device.sh`. The exact committed revision, signed bundle metadata and device installation receipt are verified into ignored `artifacts/final-verification.json`, avoiding a self-referential commit or tracked device identifiers.
