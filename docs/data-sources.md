# 数据源接口与易变位置

三个站点都没有公开 API 文档，下面是实测得到的接口和解析位置。站点改版时先看这里列出的常量和选择器。

核心代码在 `Packages/InHebiCore/Sources/InHebiCore/`；`VideoSource` 和 `AlbumSource` 分开，UI 依赖协议，后续第二个视频源可直接实现 `VideoSource`。

调试站点接口请用 Swift URLSession 脚本。curl 和 Python 的请求可能被 Cloudflare 拦下返回 403，不能据此推断 App 内的请求失败。

## iwara — `IwaraSource.swift`

- URLSession + Safari User-Agent（`HTTPClient.swift`）；不要用 curl 的 Cloudflare 403 推断 App 请求失败。
- `/videos?limit=24&page=0&sort=date&rating=all`；sort 为 date/trending/popularity/views/likes，rating 为 all/general/ecchi。
- `count` 不一定是总量：实测 limit=2 得 count=3，limit=24 page=0 得 25，page=1 得 49。使用它判断后续页，不能推断游客只能看三条；游客已实测获取多页。
- 搜索实际是 **`/search?type=videos&query=...&page=0`**，复数 videos；单数 video 实测返回 500。搜索返回 page/count/limit/results，当前每页 32 条。
- `/video/{id}` 返回详情；`fileUrl` 请求带 `X-Version = SHA1("{fileId}_{expires}_{salt}")`。salt 在 **`IwaraSource.versionSalt`**，当前 `mSvL05GfEmeEmsEYfGCnVpEjYgTJraJN`，依据 [yt-dlp 当前 extractor](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/iwara.py) 并通过联网测试验证（2026-10-14）。
- 清晰度 Source 优先，数字分辨率降序，preview 最后；补齐 `//` 的 https 协议。进入详情和开始播放时重新取签名 URL，避免长时间停留后用旧链接。
- 普通缩略图 `https://i.iwara.tv/image/thumbnail/{file.id}/thumbnail-NN.jpg`；自定义封面列表使用 `/image/large/{customThumbnail.id}/{customThumbnail.name}`，详情使用 original；均实测 200。
- `POST /user/login` `{email,password}` → user token；`POST /user/token` + Bearer user token → accessToken。访问 API 带 access token，读取 JWT `exp` 并提前 60 秒刷新；换 token 返回 401/403 时退回游客并提示重新登录。不支持外站嵌入视频，详情会显示无可播放文件。
- `/videos?user=...`、`/videos?tags=...` 已验证返回作者/标签匹配的结果。`/video/{id}/related` 旧样例可用，但最新视频重复返回 500，目前不启用 iwara 相关栏。

## Hanime1 — `Hanime1Source.swift`

- 唯一站点域名常量为 **`Hanime1Source.base` = `https://hanimeone.me`**；不使用被 Cloudflare 拦截的旧域名 hanime1.me。URLSession + Safari UA，直接解析 HTML，无需登录或客户端签名计算。
- 列表与关键词搜索统一 `/search?query=...&genre=...&sort=...&year=&month=&page=1`。站点从第 1 页开始，核心协议从第 0 页开始；解析 `rel=next`，加载下一页时保留分类、排序与关键词。
- 实测分类表单值为：裏番、泡麵番、Motion Anime、3DCG、2.5D、2D動畫、AI生成、MMD、Cosplay、新番預告，以及全部。`3D動畫`、`同人作品` 不是当前 genre 值。
- 排序值为：最新上市、最新上傳、本日排行、本週排行、本月排行、觀看次數、讚好比例、時長最長、他們在看。代码选项有真实表单 fixture 测试核对。
- 标签参数确实是重复 `tags[]`；年份、月份也存在。浏览条暴露分类、排序；详情标签链接按 query 或 tags[] 推入结果页。
- 横版卡片 `.horizontal-card`，竖版 `.home-rows-videos-title`；只收集包含封面的 `/watch?v=` 链接，排除广告并按 ID 去重。封面方向作为模型数据交给共用卡片。
- `/watch?v={id}`：标题 `#shareBtn-title`、作者 `#video-artist-name`、简介 `.video-caption-text`、时长 `og:video:duration`、标签 `.single-video-tag` 中的搜索链接；不把投票操作当标签。
- 从 `video#player source[src]` 提取播放地址，按 `size` 数字降序，默认最高。十个实际分类各抽查一页均为 MP4 source；存在 480/720/1080p，页面经常按 720、480、1080 排列。未在这些样例发现 m3u8 或 script-only 播放地址，不实现未经验证的 JS 地址提取。标准 source 的 URL 交给 AVPlayer。
- MP4 与封面包含有时效的 `secure` 参数，由站点返回；不计算签名、不保存到仓库。共用详情页在开始播放时重新请求详情，刷新直链。实际视频 Range 请求无需 Referer 即返回 206。
- `.video-description-panel` 解析观看/日期，`#video-like-btn` 解析好评；`#playlist-scroll` 和 `#related-tabcontent` 提供同作者和相关卡片。响应式重复标题仅取首个标题节点。

## wnacg — `WnacgSource.swift`

- 最新 `/albums-index-page-{n}.html`；分类 `/albums-index-page-{n}-cate-{id}.html`，父类/子类从 `#album_tabs` 与 `.drop_dwon` 分层解析。
- 搜索 `/search/?q=...&f=_all&s=create_time_DESC&syn=yes&p={n}`，分页通过数字链接判断，不能只看 `.next`。
- 详情 `/photos-index-aid-{id}.html`；整本图像 `/photos-gallery-aid-{id}.html`。
- 图集是 `document.writeln` 包裹的 JS 字符串；只解析，不执行 JS。处理真实制表符和转义引号，从 imglist 提取页面，排除末尾 `/themes/.../shoucang.jpg` 收藏提示图。封面偶有 `////` 前缀，统一为 https。
- 图片带相册 Referer，通过 ImageIO 原生解码 WebP。站点图片签名有时效，每次开始阅读重新获取；阅读中链接过期可返回详情重新打开。
- 标签列表 `/albums-index-page-{n}-tag-{tag}.html` 已验证含第二页；相册详情解析分类、日期、标签及第一页的页面缩略图。起始页与 Referer 由 `AlbumSource` 提供，通用 UI 不拼站点域名。

## Fixtures

真实 JSON/HTML fixtures 在 `Packages/InHebiCore/Tests/InHebiCoreTests/Fixtures/`，记录了采集路径；签名 hash/verify 已脱敏。联网测试每次重新获取地址，不使用旧 fixture 链接。
