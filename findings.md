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
