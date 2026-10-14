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

## Filter interaction follow-up: baseline device reproduction
- Original app code 2dc3bf3, only an XCTest probe added. Cold launch starts on the system iwara Tab; one Down focused a video card instead of the strip. Switching back from Hanime1 then Down also focused a card.
- Hanime1 single Right presses: 裏番, 泡麵番, 3DCG, 2D動畫, AI生成, MMD, Cosplay, 新番預告, then system Tabs. Motion Anime and 2.5D were skipped. The container's onMoveCommand incremented the already-moved focused value, while scrollTo centered on every focus update.
- Pagination probe loaded 48 -> 120 items with repeated Down; the reported stall was not reproduced in this key-only run. Existing loading relied solely on lazy card onAppear callbacks. New implementation will use scroll geometry and focused-near-end demand, re-evaluated after appending each page.
- Baseline log: artifacts/filter-baseline.log. XCUIRemote cannot simulate Siri Remote touch-surface acceleration.


### Filter implementation and verified checkpoints
- Replaced duplicate browser focus state machines with BrowseList. Removed saved-card default-focus preference, nil-focus heuristics, resetFocus loops and per-focus scrollTo centering. Native NavigationStack now retains detail-return focus/position without those competing restorations.
- A plain SwiftUI entry still skipped the strip on device; broad focusSection/defaultFocus experiments also diverted Down into fixed controls. Final code uses one narrow UIKit public focus notification observer for actual Tab -> content Down, deferred until SwiftUI receives the native update and limited to the currently visible list. Normal chip-to-chip movement is native. Only first-row Up and fixed-region boundaries have explicit targets.
- Every Hanime1 chip and flattened comic category was traversed with exactly one Right/Left per step, including complete end-chip bounds. Returning from fixed controls via Tab -> Down preserves the selected end chip. Device tests testFilterEntryAndSingleStepNavigation and testListReturnTabRetentionAndPagination passed together (74.119s and 30.453s), log artifacts/filter-entry-settled.log.
- Continuous Down reached at least three pages and Menu returned to top without another request. Rapid 100ms injected focus changes issued one request for the final chip. Actual XCUIRemote calls are spaced about 0.45-0.5s and cannot exercise sub-400ms input; the injected integration test is explicitly separate from native key routing.
- Offline core suite: 28 tests, 3 live skips, zero failures. Live suite: 28 tests, zero skips/failures; logs artifacts/filter-offline.log and artifacts/filter-live.log. One earlier UI run hit a real iwara HTTP 522 at launch; it was displayed as an error, not silently retried or treated as a focus defect.
- No detail, player, reader or settings implementation changed in this round. Full regression, final screenshots and installation follow below.


### Filter follow-up final acceptance

- Final full device run: `./script/test-device.sh "$SHELF_DEVICE_ID"` with API-key environment — **15 tests, zero failures, 567.474 seconds**. Log: `artifacts/filter-device-acceptance.log`; xcresult: `artifacts/device-ui-20261014-123518.xcresult`.
- Strict pagination evidence: focus reached zero-based index 69 (third page's last row), with 120 items loaded. No extra buttons were used while descending. Menu then returned to offset 0 and the selected Views chip without changing request/item counts.
- Exact chip coverage: Hanime1 11; comics 21 (Latest plus all 20 parent/child category options). Every single Right and Left was checked, including end-chip bounds and fixed-control boundaries. The same selected end chip was reached from system Tab with one Down.
- Native remote calls and synthetic focus injection are separate tests. The 100ms focus burst went across three chips, committed only Views, and added exactly one network request. Core tests separately prove cancellation of the running old request and rejection of a cancellation-ignoring late response.
- Full regression includes both source playback clocks advancing while muted, Menu stopping playback, real end-of-item return, player metadata, search submission, reader jump/resume/spreads and direction. Each test terminates the app. Existing account remains logged in.
- A test helper previously read a transient empty focus during an animation. It now waits for the single key's exact expected target, without sending a compensating key. The final entire suite above passed after that correction.
- Restoring transient chip state uncovered a search regression: Hanime1 search now explicitly receives its source category (and keeps the prior default-search-sort behavior). `testHanimeSearchKeepsCategory` verifies real MMD results under MMD; it passed in the full run. No detail/player/reader/settings implementation changed.
- Latest generic build: **BUILD SUCCEEDED**, log `artifacts/filter-simulator-final.log`. Offline/live core results remain **28 total tests, zero failures** (offline skips the 3 opt-in live cases). No runtime download.
- All 39 named screenshots were individually inspected across the final-code verification runs; final strip/pagination/search captures were reopened after the last export. End chips are fully visible, selected state remains clear outside the strip, parent-qualified comic labels are readable, fixed controls stay clear, and there is no new overlap. Original source entries without thumbnail URLs still display the existing placeholder; no missing-image fallback was added.
- Particularly relevant captures: 01/02/03 (main strips), 06/07 (detail return), 08/09 (Menu/Tab reentry), 34/35 (strip ends), 36/37 (third page and Menu to top), 38 (debounced focus), 39/40 (selected end-chip reentry), 41 (flattened comic labels), 42 (category-scoped search). Baseline-only captures 31-33 are under artifacts/baseline-screenshots rather than the final screenshots directory.
- Remaining manual verification is Siri Remote touch-surface acceleration and the subjective 0.4-second dwell/wider-chip feel. Key tests and injected focus updates do not establish real swipe feel.
- Final committed bundle installation and version/signature/process checks are recorded in ignored artifacts/final-verification.json after committing this source. No credential or device identifiers are tracked.

## Three-row focus regression: normal-launch reproduction
- The original build-10 app behavior was reproduced with `app.launchArguments = []`, real standard UserDefaults and existing Keychain. All three sources could enter loaded cards with Down, but strip Up failed. The previous tests used Menu to reach the top Tab and did not assert this third upward step.
- Actual preference values copied from this app's container: iwara.rating=all and iwara.sort=date. No invalid category selection exists; chip selection is transient and logs report valid=true. Both installed and test apps use Debug; TestMode changes only test preferences/probes/overlays.
- Right to a new chip followed immediately by Down reproduced the reverse transition on all three sources during the 0.4s debounce/load-clear window. Baseline log: artifacts/vertical-trace-baseline.log; saved native trace: artifacts/vertical-baseline-trace.txt.
- Evidence: at 04:16:52.640 the comic grid had count=0/loading=true; at 04:16:52.654 native direction=down went from filter.chips to UITabBarButton. The old TabFocusEntry check was false for that transition (no mistaken ancestry), then true for the subsequent real Tab Down, which sent focus back to the chip. At 04:15:32.382 native-failed direction=up occurred while on the iwara chip.
- Native frames explain the result: SwiftUI's horizontal HostingScrollView/PlatformGroupContainer covered y=0..242 although the visible chips were around y=164; the system Tab sits y=46..114. Padding and clipping alone did not correct this native focus rectangle.
- Replaced only the chip scrolling content with bounded UIKit UIScrollView/UIStackView/UIButton geometry. The system TabView, grid, details, player and reader remain. Removed all list onMoveCommand handlers and the global TabFocusEntry focus-mutating observer. Root list focus state now observes UIKit chip focus separately from SwiftUI control/card FocusState.
- Production focus requests are limited to cross-row entry into the selected chip and explicit Menu-to-top. Entry classification uses actual previous view ancestry (system Tab or browse.grid), not focusHeading or direction keys. An asynchronous entry correction is abandoned if its original landing button no longer has focus. DEBUG global notifications only record diagnostics.
- Normal and test-preference three-source full Up/Down paths passed targeted runs; Menu interop and controlled timing verification subsequently passed the full acceptance run below. A prior row-query timeout was caused by reading every loaded button individually; the test now queries hasFocus on the device, with no extra corrective key presses.

### Input-independent focus verification
- Menu transfer now requests an update through an environment containing the current item: the strip itself when a chip is focused, otherwise the containing root. The preference survives until UIKit confirms it. No direction/heading is used to choose a target.
- The corrected native transfer passed all 11 Hanime1 and 21 comic chips in both directions, including selected end-chip entry and complete visibility. The 100ms integration burst produced one request only for the final chip.
- In the final full-run timing case, all three sources passed new-chip Down before the 400ms dwell, Down during deliberately held real-network loading, immediate loaded Down, and consecutive Down calls. Saved trace: artifacts/vertical-timing-final-trace.txt. Injection request to native Down was 259ms (iwara), 245ms (Hanime1), and 238ms (comics); each native before-view was the new chip. This is a timing probe, not physical swipe simulation.
- Normal launch with no arguments and standard preferences passed all three sources' top/strip/grid round trips, scroll, detail return, and category change in 114.981s. The trace reports testMode=false, prefs=standard, loggedIn=true, and no invalid selection. Saved trace: artifacts/vertical-normal-final-trace.txt.
- One strict timing assertion initially read the old focused element before the second Menu animation completed; native trace proved the requested Tab transition did occur. The assertion now waits for that same press's result, without a compensating key.
- Generic tvOS Simulator SDK build passed (artifacts/vertical-simulator-final.log); no runtime was installed. Core offline: 28 tests, 3 opt-in live skips, zero failures. Core live: 28 tests, zero failures in 11.603s (artifacts/vertical-offline.log / vertical-live.log).

### Three-row final acceptance
- Full real-device suite: **18 tests, zero failures, 859.225 seconds**. Command: `./script/test-device.sh "$SHELF_DEVICE_ID"` with signing environment. Log: artifacts/vertical-device-acceptance.log; result: artifacts/device-ui-20261014-141506.xcresult.
- All earlier playback/stop/end/metadata, search, reading/jump/resume/spread/direction, list retention, all-chip traversal, focus debounce, Menu and third-page traversal cases passed. Normal and test-preference directional suites both passed in this same run. Playback remained muted and each test terminated the app.
- All 45 named screenshots were reopened individually after this final export. Strip selected/focused colors are distinct; end chips are fully visible and parent-qualified comic labels readable; the normal and test-preference captures have the same three-row geometry. Two full landscape rows remain visible. No new text overlap was found; existing long-title ellipses and occasional source-cover placeholders remain unchanged. Baseline-only captures are archived outside the final screenshots directory.
- Remaining physical verification: Siri Remote finger swipes/acceleration. No production list focus decision uses onMoveCommand, directional presses or focusHeading; cross-row correction uses actual previous/next view ancestry, and normal Up/Down/Left/Right is native. The only other list transfer is explicit Menu-to-top. Sorting sheet initial focus and test-only synthetic focus injection are separate from directional navigation.
- Changes: BrowseList/Browsers/MediaGrid, new ChipStrip and FocusTrace, removed TabFocusEntry, UI tests, project registration, README and trace-fetch script. No details/player/reader/settings implementation or core source changed.
- Exact committed bundle installation, normal-launch trace revision, device version and stopped-process checks are recorded after commit in ignored artifacts/final-verification.json. No push.

## Direct native entry into the selected chip
- User's build-11 trace fetched first to artifacts/entry-before-trace.txt. At 05:56:07.485 Hanime1 Tab Down landed on chip.泡麵番; at 05:56:07.502 code requested strip-entry, and at 05:56:07.505 a second native update moved to chip. (All). This confirms visible post-entry correction, not a hypothesis about remote input.
- Added top/bottom 10pt UIFocusGuide regions pointing to the selected chip. Guide enablement depends solely on whether actual focus is inside the strip. Removed the whole asynchronous strip-entry correction and ancestry detection. Appearance, horizontal layout and button identities remain unchanged.
- Menu regression exposed the root controller reset's default first-item choice after correction removal. Registering the native strip as one SwiftUI `.strip` focus target resolves it directly. Removed the old focusRequest counter/parameter plumbing and root-controller reset; the only native synthetic focus function is for existing UI timing probes.
- Targeted all-category Left/Right test passed with guides (75.827s). New testSingleUpdateStripEntry passed on all three sources with non-first selected chips and both top/grid entry, asserting exactly one native update. Menu plus three-page traversal passed with registered strip target (37.333s).
- Full acceptance log: artifacts/entry-device-acceptance.log (original 18 cases plus new single-update case). Final committed bundle/version/signature receipt: artifacts/final-verification.json. Actual physical Siri Remote swipe feel remains user verification; production entry logic does not depend on press events or movement headings.
- Icon resources and artifacts/icon are outside this change and untouched.

## tvOS icon integration
- Read artifacts/icon/README.md and copied all 13 selected Concept-1 PNGs byte-for-byte into Shelf/Assets.xcassets/ShelfBrand.brandassets. Small contains 3 layers × 2 scales; Large contains 3 × 1; standard/wide Top Shelf each contains 2 scales. Background PNGs are RGB, foreground PNGs RGBA. Layer JSON order is Front/Media, Middle/Shelf, Back/Background.
- Updated the checked-in project generator and regenerated project to compile Assets.xcassets as resources and select ShelfBrand for Debug and Release. Generated Info.plist maps CFBundlePrimaryIcon to App Icon - Small, and TVTopShelfImage to both image sets. No artifact path is used at build time.
- Generic simulator and real-device asset compilation passed with no asset slot, size, alpha or other icon warnings. The existing unrelated AppIntents metadata-extraction-skipped warning remains.
- Real-device subset passed: testHomeScreenIcon, testMediaGridFiltersAndSearch, testNormalDirectionalRows, testSingleUpdateStripEntry: 4 tests / 0 failures / 245.481s (artifacts/icon-device-regression.log). After adding strict HomeBoard icon existence/visibility/focus assertions, the affected home test passed again in 8.897s (artifacts/icon-home-assertions.log). No playback was exercised.
- Inspected artifacts/screenshots/55-home-icon.png: the focused first-row Shelf icon and full Top Shelf banner both show the selected books/play-screen/shelf artwork with correct ordering, without clipping. The user's home-screen order was not modified. Physical parallax remains manual verification.
- Final committed build/signature/install and post-install home screenshot evidence are recorded in ignored artifacts/final-verification.json. Commit only, no push.
