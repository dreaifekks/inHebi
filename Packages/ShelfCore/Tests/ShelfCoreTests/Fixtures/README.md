# Fixture provenance

Captured on 2026-10-14 JST through Apple Foundation URLSession with a Safari User-Agent. No login, cookies, or personal credentials used.

- `iwara-list.json`: `/videos?limit=2&sort=date&rating=all`
- `iwara-detail.json`: `/video/{first-list-item-id}`
- `iwara-streams.json`: detail `fileUrl`, SHA1 `X-Version` header
- `iwara-page-1.json`: `/videos?limit=24&sort=date&rating=all&page=1`
- `iwara-search.json`: `/search?type=videos&query=MMD&page=0`
- `wnacg-list.html`: `/albums-index-page-1.html`
- `wnacg-detail.html`: `/photos-index-aid-395652.html`
- `wnacg-gallery.html`: `/photos-gallery-aid-395652.html`
- `wnacg-search.html`: `/search/?q=original&f=_all&s=create_time_DESC&syn=yes&p=2`

Responses retain their real field/HTML/JS structure. Expiring URL `hash` and `verify` values are replaced with `REDACTED`. Fixture URLs must not be used for live playback; live tests acquire new URLs each run. No image/video binaries are committed.

## Hanime1 addition

Also captured through URLSession on 2026-10-14 JST:

- `hanime-list.html`: `/search?query=&genre=&sort=&year=&month=` (horizontal cards + actual filter options)
- `hanime-portrait.html`: `/search?genre=裏番&sort=最新上傳&page=1`
- `hanime-empty.html`: `/search?genre=3D動畫&sort=最新上傳&page=1` (invalid current genre, empty results)
- `hanime-detail.html`: `/watch?v=408185` (3DCG, 720/480/1080 source order)
- `hanime-two-streams.html`: `/watch?v=244` (Cosplay, 720/480)

Hanime1 snapshots remove script/style blocks, comments, CSRF meta/input fields and replace signed `secure` query values with `REDACTED`. Parser-relevant HTML structure and metadata remain from the real responses. No script evaluation or media files are needed for fixture tests.
