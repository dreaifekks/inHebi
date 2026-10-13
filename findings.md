# Findings
- Xcode 27.0 / tvOS 27 SDK present; no valid code signing identity returned.
- yt-dlp master iwara.py inspected 2026-10-14: X-Version SHA1 salt mSvL05GfEmeEmsEYfGCnVpEjYgTJraJN; login then access-token exchange.
- Nowledge thread search tv-shelf iwara wnacg returned no prior threads.
- Live API discovery: iwara search requires `type=videos` (plural), singular returns HTTP 500. Search returns 32 items/page and its own pagination envelope; omit list-only sort/rating controls during search.
- wnacg search pagination uses `p=N`, numeric paginator links (no `.next`); category page `/albums-index-page-2-cate-1.html` is HTTP 200.
- wnacg gallery JS includes literal tab characters inside document.writeln strings; normalize those before JSON string decoding. Filter final `/themes/.../shoucang.jpg` promotion.
- wnacg detail cover can start with `////`; normalize to https://.
- Initial fixture test found JS tab decoding error and was corrected; initial core compile found Swift throwing boolean expression needing outer `try` and was corrected.
- Guest count correction: limit=2 returned count=3, limit=24 page=0 count=25, page=1 count=49. Guests can retrieve multiple pages; do not infer a three-video limit. Count behaves as a pagination lower bound.
- Custom thumbnail `/image/original/{id}/{name}` confirmed HTTP 200 (also thumbnail and large variants).
- First generic tvOS Simulator build passed for arm64 and x86_64; first live suite passed 9/9 tests, media HTTP 206, comic image HTTP 200.
- Sandboxed security initially showed zero identities; authorized read outside sandbox found three valid identities. Team choice pending identity-type inspection.
- simctl confirms only iOS/watchOS runtimes; no tvOS runtime.
- Final signature choice: ALZ45VUZFN from certificate OU, not the Apple Development common-name identifier. Final suite: 11/11 passed; generic build passed.

## Hanime1 (2026-10-14)
- Canonical domain https://hanimeone.me; use Safari UA + URLSession, no login or signature calculation.
- Live genre data-values: 全部, 裏番, 泡麵番, Motion Anime, 3DCG, 2.5D, 2D動畫, AI生成, MMD, Cosplay, 新番預告. `3D動畫` and `同人作品` produce empty results as genres.
- Live sort values: 最新上市, 最新上傳, 本日排行, 本週排行, 本月排行, 觀看次數, 讚好比例, 時長最長, 他們在看.
- Pagination: page=1 based; next link rel=next. query/genre/sort can be combined. Tags use repeated tags[]; year/month are also form controls, outside requested v1 UI.
- Horizontal cards use .horizontal-card/.title/.duration; portrait cards use .home-rows-videos-title. Ad cards link off-site; only watch links with images are collected and IDs deduplicated.
- Ten actual genres each sampled one watch page (plus supplied 408316): all contain video#player source MP4s; 480/720/1080 variants, often 720 then 480 then 1080. No m3u8 or script-only stream observed in this sample. No speculative JS stream fallback added.

## Real Apple TV UI findings
- API-key automatic provisioning succeeded for app and UI runner using the existing ALZ45VUZFN team; the key is only referenced through environment-supplied command arguments.
- First iwara detail path passed on AppleTV14,1. Screenshot showed the header partially scrolled off-screen when focusing Play with a long description; header is now fixed, description independently scrolls.
- Initial Hanime1 playback passed: AVPlayer reported playing, muted=true, clock advanced 0.5 -> 3.0 seconds; test terminated playback after screenshot.
- Initial tabs/settings passed. Screenshots showed many-option tvOS default Pickers squeezing genre/category labels into ellipses. Replaced browse filters with native List selection sheets. Increased card title space to two lines.
- Initial comic single-page and page-three screenshots showed height-fit rendering. Toolbar selection failed because the full-screen focusable canvas intercepted horizontal movement; canvas is now non-focusable while controls are visible.

## Redesign final corrections
- Root Tab visibility must follow reader activity, otherwise the browser's visible preference overrides the pushed reader. The reader uses NavigationStack for reliable return focus.
- API discovery from stage 2 was not universally stable: iwara related returned repeated HTTP 500 for current newest videos, so the feature is disabled. Author and tag browsing remain verified.
- Native keyboard submission must target its actual completion button. UI tests now require results inside search.screen and zero results while merely typing, preventing underlying-list false positives.
- Final verification details, native alternatives and scope exceptions are recorded in progress.md; all generated media, test results and screenshots remain ignored under artifacts/.
