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
