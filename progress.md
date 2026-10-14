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

## Filter chip symbols
- Added one shared FilterSymbols map for all current source labels and comic leaf categories, plus explicit generic tag for new categories. Shared that source file with the UI-test target; no copied symbol-name table in test code.
- Apple-owned /System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist lists every chosen symbol at tvOS 13, 14, 14.2 or 15; no suggested symbol needed replacement. Exact audit: artifacts/chip-symbol-availability.json. The physical test device runs tvOS 27; no tvOS 18 runtime was downloaded.
- Replaced the chip checkmark with an always-present 26pt medium symbol and 12pt title spacing. Kept 29pt labels, 60pt buttons, 80pt strip and the existing focus guides. Selected trait and cyan unfocused selection remain. Added matching sorting/rating symbols; search remains magnifyingglass.
- First targeted device run passed all 30 UIImage symbol lookups, selected/unselected unfocused width equality, all-category single-step Left/Right, and filter/search tests. Screenshot review found Hanime1's fixed sorting label truncated after adding its symbol; expanded the fixed control area from 420 to 470pt before final regression.
- Final regression log: artifacts/chip-symbol-acceptance.log; simulator build: artifacts/chip-symbol-simulator.log. Captures include each three-chip segment so every Hanime1/comic symbol can be visually reviewed. Final receipt: artifacts/final-verification.json. App icon/Top Shelf assets are retained unchanged and delivered together in the final installed build.

- Final device acceptance: **9 tests / 0 failures / 470.114s**, result artifacts/device-ui-20261014-163305.xcresult. Covers all symbol lookups and stable widths, complete Left/Right traversal and end visibility, debounce, direct Up/Down entry, loading timing, normal preferences, Menu/three-page pagination and the existing branded home icon. Generic simulator SDK build passed.
- Inspected the final main strips, all 3 Hanime1 segments, all 6 comic segments, both ends, normal-launch selected states and home icon screenshot. All proposed symbols are legible; Chinese/Japanese/English book glyphs render correctly. Fixed sorting text is now complete. Selected cyan remains obvious outside the strip; no checkmark remains on chips and focused/end labels are not truncated. Segment screenshots taken during switching intentionally show the loading indicator.
# Reader/card revision — 2026-10-14

Read README and HANDOFF completely; worktree initially clean at b27311c. Retrieved the device focus trace before code changes. No screenshots opened. Device discovery required host CoreDevice access after a sandbox initialization timeout. This revision excludes favorites/history features, iCloud, naming and bundle ID changes.

- `swift test --package-path Packages/ShelfCore`: 31 discovered, 28 passed / 3 live tests skipped / 0 failures (artifacts/reader-core-offline.log). Initial sandbox attempt could not write Clang's module cache; host-access run succeeded.
- `SHELF_LIVE_TESTS=1 ./script/verify.sh`: 31 passed / 0 failures, then generic tvOS Simulator build succeeded (artifacts/reader-verify.log).
- No tvOS simulator runtime installed (checked through simctl); no runtime downloaded.
- Device acceptance running only eight affected grid/reader/focus tests. API-key values and device identifier are filtered before textual logs are written.
- First affected device run: 7 passed / 1 failed in 513s (artifacts/device-ui-20261014-174632.xcresult). All grid, spread geometry, jump/resume/direction and existing focus regressions passed. The new bottom-row test stopped at an empty button identifier before pressing Down; added explicit identifiers to all six bottom-row buttons and an assertion of the exact focused button before each Down.
- Bottom-row retest passed 1/1, zero failures (artifacts/device-ui-20261014-175617.xcresult and artifacts/reader-bottom-row-retest.log). Verified Down from each of next/previous/spread/retry/resume/close dismisses without changing the page; canvas then advances normally. Final affected-test coverage: 8 distinct passing tests, zero unresolved failures.
- Device process check after teardown: Shelf is not running. No video playback exercised and no raw screenshots opened.
- Final `./script/verify.sh` after the button identifier change passed: offline 28 passed / 3 skipped, generic tvOS Simulator build succeeded (artifacts/reader-final-verify.log). `git diff --check` passed.
- Normal signed release handoff is build 16, using the newer local AuthKey and the README signing environment variables. Install receipt: artifacts/reader-install.log. Read-only Claude cross-review is the next step after commit/install; its conclusion will be forwarded unchanged to the coordinator.
# Full-width grid correction — 2026-10-14

Starting from 7fe24be/build 16 with a clean worktree. Reviewer reported no blockers; coordinator requested restoring full-size grid covers and withdrew the two-complete-rows constraint. Reader implementation stays unchanged. Current device focus trace fetched before edits. Core/verify and affected grid device tests will be recorded below; a new commit and normal signed installation are required, without another reviewer.

- `swift test --package-path Packages/ShelfCore`: 28 passed / 3 live tests skipped / 0 failures (artifacts/grid-restore-core-offline.log).
- `./script/verify.sh`: offline 28 passed / 3 skipped / 0 failures and generic tvOS Simulator build succeeded (artifacts/grid-restore-verify.log).
- Running only five affected device tests: focused cover ratios/title clearance, Hanime portrait size, media grid filters/search, single-update strip entry, directional grid rows. No reader or playback tests rerun.
- Final device result: 5 passed / 0 failed in 332.2s, artifacts/grid-restore-device.log. First/second-row focused frames: landscape 444x249.48–250.02pt with 20.74–20.76pt title clearance; Hanime1 346.67x520pt with 12pt; comic 349.98–350.01x466.5–467pt with 12pt. Original ratios, full column widths and unfocused left-edge alignment all passed.
- `git diff --exit-code 7fe24be -- Shelf/ReaderView.swift Shelf/RemoteImage.swift Packages/ShelfCore` confirmed no reader/core changes. No raw images opened. New-commit signed installation handoff: build 17, receipt artifacts/grid-restore-install.log; no further reviewer requested.
# Reader/player panel interaction — 2026-10-14

Base f13d27b/build 17; identifiers and project naming excluded for parallel rename/iCloud work. Retrieved device focus trace first. Every device launch uses pgrep occupancy checks and waits 30 seconds while another test is running.

- Baseline: player native directions and late-page reader focus 2/2 passed (artifacts/panel-baseline.log). The reported reader fallback did not reproduce on this run; the test focused page 17.
- Added native transport visibility instrumentation and DEBUG probe auto-pause at approximately 3 media seconds. No AVKit private hierarchy inspection in production code or replacement UI.
- Reader change: directional entry focus, top/bottom edge dismissal, current-page focus on visibility callback after scroll, 350ms same-opening-direction quiet period extended by repeats. Targeted device validation in progress.
- Initial ./script/verify.sh passed offline 28 / 3 live skipped and generic build (artifacts/panel-verify.log).
- Investigation runs exposed two invalid probe assumptions: Audio focus is transient when the three-second playback cap pauses the player, and Info may be visible while the transport delegate reports false. Assertions now distinguish panels and record immediate playback state.
- Async sleep injection could deliver nominal 100ms events hundreds of milliseconds late; the burst test now injects explicit event times (100ms, 200ms) through the real edge handler, with actual button navigation around it. Fixed the grace-window update to extend rather than shorten the initial one-second window. Physical swipe remains manual verification.
- Removing PlayerScreen's outer onExitCommand was verified on device: first Menu stays in AVKit instead of immediately dismissing the player; native control layers then close and delegate dismissal exits. Video same-direction closure is unavailable through supported AVKit API.
- Final standalone offline test and ./script/verify.sh passed (artifacts/panel-core-offline.log, artifacts/panel-final-verify.log): 28 passed / 3 live skipped / 0 failed, generic build succeeded. Final nine affected device tests are running in artifacts/panel-acceptance.log.
- Final code also passed ./script/verify.sh in artifacts/panel-release-verify.log after strengthening the simulated burst through 1100ms. The existing NoBlockComments style warning in PlayerView's unchanged optional-artwork catch block was not modified.
- Main affected acceptance: 8/9 passed (artifacts/device-ui-20261014-184950.xcresult). The remaining legacy test expected one Menu to immediately exit; updated it to pause after a few seconds, close native layers, and verify playback stops.
- Follow-up: both video sources passed (Hanime 48.474s, iwara 38.967s; artifacts/panel-release-retest.log). Two new reader checks stopped because a test helper read its original card identifier after leaving the list; capture moved before navigation.
- Final reader retest: 2/2 passed, zero failures (artifacts/device-ui-20261014-190256.xcresult; artifacts/panel-reader-final.log): late page / resumed page focus 61.319s; direction and burst behavior 49.284s. Visible focused thumbnails at pages 17, 23 and resumed 21 had x≈864.98, width≈190.05, height=253pt.
- Final distinct coverage: 10 tests passed, zero unresolved failures. Includes both video sources, playback end, native Info/directions, bottom-row buttons, jump/resume/spread, late/resumed-page focus, directional/burst controls, and LTR direction. No raw image viewed, no naming/identifier/project-generator/iCloud files changed. Release handoff is new-commit build 18; normal signed receipt artifacts/panel-install.log. Claude read-only review follows installation.

## inHebi identity and CloudKit library — 2026-10-14

- Based on master f13d27b. Public identity rename is an independent commit; internal project/target/scheme/ShelfCore names and Top Shelf assets remain intact. No old TV application was removed.
- Added cross-platform SwiftData SavedMediaItem/FavoriteFolder models, optional inverse many-to-many relationships, explicit private CloudKit container, history/page persistence, default/multiple favorites, metadata refresh and duplicate-import reconciliation. iOS 18 added to package platforms.
- Added detail favorite controls, folder picker/editor, My tab with existing 400 ms chip selection and source-specific grids, context-menu removal, folder management, account status and DEBUG CloudKit event logging. Reader/player edits are limited integration points for the parallel branch.
- Core: 37 discovered, 34 passed, 3 live tests skipped, 0 failures, including 6 new library tests. verify.sh generic tvOS build passed. All 26 UI tests (23 existing + 3 new) compiled with build-for-testing; no tvOS runtime is installed.
- Automatic provisioning attempted using the newer Downloads AuthKey and matching parameters from a prior successful install command. Apple returned Authentication failed; the cached wildcard tvOS profile lacks Push Notifications/iCloud/container entitlements. Stopped provisioning as requested. No new signed build installed, no TV UI tests executed (0 pass / 0 fail / 26 pending), no CloudKit export confirmed. Instructions to restore credentials and, if needed, create/link the container are in README.
- No screenshots were opened, no account credentials entered, no device identifier recorded here. The prior installed app remains unchanged.

## Library review fixes — 2026-10-14

- Based on 17f4fd7; new commit only. ChipStrip now reuses, reorders, relabels and removes buttons from the current options. Deleted selection returns to the first History chip; pending dwell tasks restart when option IDs change, and removed native focus targets recover to the selected chip. Existing 400 ms dwell, selection-independent geometry and entry guides remain in place. Folder management keeps its title as a value and does not read a deleted model.
- Video routes/playback carry list presentation metadata. Portrait covers survive landscape detail refreshes, and stored fillCover follows the same iwara letterboxing rule as the browse grid. Library detail presentation is owned by a stable value at the page level, independent of the originating row.
- Duplicate retention uses createdAt then recordID for media and default folders, with newest metadata merged separately. Removing the final folder/history reference deletes the item. Page turns mutate the main context without save(); ReaderView onDisappear flushes once.
- Comic quick-open uses the list/stored metadata and only fetches pages. Folder picker reads membership through a key-filtered item query. The filled star now means default-folder membership; its label includes folder count. Removed VideoBrowser's unused AppModel environment.
- Validation completed in foreground: swift test and verify.sh each reported 43 tests, 40 passed / 3 live skipped / 0 failed (12 library tests, 6 added this round). Generic tvOS build passed. build-for-testing passed for all 29 UI tests (3 added this round plus expanded star-state coverage). Shared-filter regression tests compiled; native focus/keyboard behavior was not executed.
- Per coordinator instruction: no device tests, no installation, no signing retry, no new reviewer. CloudKit container loading behavior remains unchanged; real synchronization is still unverified until signing is restored.

## Signed device and CloudKit acceptance — 2026-10-14

- Signing restored with the already signed-in Xcode account after unsetting all three SHELF_AUTH_KEY variables. App/profile entitlements verified for com.dreaife.inhebi, private container iCloud.com.dreaife.inhebi, Development environment and development APNs. Bash 3.2 empty-array expansion in both device scripts fixed by retaining provisioning flags in the nonempty signing argument array. API key authentication remains disabled operationally.
- Complete 29-case run: 23 passed / 6 failed. Follow-up evidence and fixes: native Select long-press recognizer with mutually exclusive short action; full-width focus section for sparse My grids; explicit accessibility container boundary; restoring History focus after folder-manager dismissal. Test helpers now distinguish local library chips from network metrics, query the actual context-menu element type, navigate to the newly installed Home icon, and wait for tab focus before Down.
- Targeted results: inhebi-six-rerun-2.log passed Home icon, comic history/resume, detail persistence after removing favorites, and Hanime portrait; inhebi-two-rerun.log passed favorites/folders; inhebi-folder-final.log passed rename/delete and History re-entry. All 29 unique standard cases now have passing results, 0 unresolved failures. Initial and intermediate failed runs are retained as evidence.
- Normal launch without test arguments succeeded with the real persistent container, then exited. Explicit TEST_RUNNER_INHEBI_CLOUD_TEST=1 dedicated test passed 1/1 using --ui-cloud-library, while ordinary UI tests remain in-memory. Account status: 已登录 iCloud. Favorite added and cancelled; newly created empty default folder deleted; cleanup export confirmed.
- Sanitized cleanup event: 2026-10-14T10:53:00.220 kind=code cloudkit kind=export completed=true success=true error=none. Full trace: artifacts/inhebi-cloudkit-focus.txt. All tests mute playback and terminate the application; no screenshots were opened.
- Normal install runs after commit; receipt: artifacts/inhebi-normal-install.log. No push, amend, rebase or merge of master 97403c2; coordinator retains ownership of combining the reader/player branch.
