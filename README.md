# Shelf

自用 tvOS 原生应用：iwara / Hanime1 视频、wnacg 漫画。SwiftUI + AVKit + URLSession；无 WebView、后端、下载、历史或同步。最低 tvOS 18；ShelfCore 支持 macOS 15 / tvOS 18。唯一外部依赖是 SwiftSoup（锁定文件当前解析为 2.14.2）。

## 打开与验证

打开 `Shelf.xcodeproj`，选择 **Shelf** scheme。工程已提交，无需 XcodeGen/Tuist。添加 App Swift 文件后可运行 `python3 script/generate-project.py` 重新生成工程；生成器会覆盖 pbxproj，团队配置也应同步修改生成器。

```sh
cd /Users/gakeiakira/code/tv-shelf
swift test --package-path Packages/ShelfCore
SHELF_LIVE_TESTS=1 swift test --package-path Packages/ShelfCore
./script/verify.sh
# 或一次运行联网测试 + generic 编译：
SHELF_LIVE_TESTS=1 ./script/verify.sh
```

验证脚本使用：

```sh
xcodebuild -project Shelf.xcodeproj -scheme Shelf \
  -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Generic 编译不需要 tvOS 模拟器运行时。本次未下载运行时、未安装到真机；构建产物在 `DerivedData/Build/Products/Debug-appletvsimulator/Shelf.app`。`DerivedData` 和 SwiftPM `.build` 均不入 git，可按需删除释放磁盘。

## 签名与 Apple TV 安装

- Bundle ID：`com.dreaife.shelf`；自动签名；默认团队 **ALZ45VUZFN**，来自本机 Apple Development 公钥证书的 OU 字段，且与本机 Developer ID 团队一致。本机另有一个开发团队；若要使用其他团队，在 Shelf target → Signing & Capabilities 中选择。
- 在 Xcode → Settings → Apple Accounts 登录开发者账号，确认目标团队和自动签名可用。
- Apple TV 和 Mac 接入同一网络。在 Apple TV 的“设置 → 遥控器与设备 → 遥控 App 与设备”进入配对界面。
- Xcode 27 使用 **Xcode → Open Developer Tool → Device Hub**（或运行目标菜单里的 Manage Devices），添加并配对 Apple TV，输入电视显示的配对码。按 Xcode/设备提示完成开发准备。
- 将运行目标选为该 Apple TV，点击 Run。Xcode 注册设备并生成开发 provisioning profile；以后签名/profile 过期时重新构建安装。

官方说明：[运行到设备](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[Device Hub 配对](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)。本项目尚未进行设备配对、开发签名或真机运行验证。

## 使用

顶部 Tab 为 iwara、Hanime1、漫画、设置。大卡片使用系统 tvOS `.card` 焦点效果；筛选、搜索按钮和“加载下一页”均可用遥控器操作。

- 视频：排序/分级筛选，提交搜索词，进入详情选择清晰度（默认最高），系统播放器播放。iwara 搜索采用站点搜索排序，排序/分级控件暂不可用；Hanime1 搜索可叠加分类和排序，无需登录。
- 登录：设置页输入 iwara 邮箱、密码。只将 user token 存入 Keychain，access token 保留内存；密码提交完成或离开页面时清空。退出会删除本机 token。账号权限、真实登录结果仍需用户验证。
- 漫画：最新/分类/搜索 → 相册 → 开始阅读。单页按屏幕高度等比适配；向左下一页、向右上一页。选择键、上下键或播放/暂停键显示选项，可开双页（右边是前页）、重试图片或关闭。Menu/返回键先收起选项，再退出阅读。页码常驻；只在内存预加载后续页面，不落盘做离线缓存。

## 数据源接口与易变位置

核心代码在 `Packages/ShelfCore/Sources/ShelfCore/`；`VideoSource` 和 `AlbumSource` 分开，UI 依赖协议，后续第二个视频源可直接实现 `VideoSource`。

**iwara — `IwaraSource.swift`**

- URLSession + Safari User-Agent（`HTTPClient.swift`）；不要用 curl 的 Cloudflare 403 推断 App 请求失败。
- `/videos?limit=24&page=0&sort=date&rating=all`；sort 为 date/trending/popularity/views/likes，rating 为 all/general/ecchi。
- `count` 不一定是总量：实测 limit=2 得 count=3，limit=24 page=0 得 25，page=1 得 49。使用它判断后续页，不能推断游客只能看三条；游客已实测获取多页。
- 搜索实际是 **`/search?type=videos&query=...&page=0`**，复数 videos；单数 video 实测返回 500。搜索返回 page/count/limit/results，当前每页 32 条。
- `/video/{id}` 返回详情；`fileUrl` 请求带 `X-Version = SHA1("{fileId}_{expires}_{salt}")`。salt 在 **`IwaraSource.versionSalt`**，当前 `mSvL05GfEmeEmsEYfGCnVpEjYgTJraJN`，依据 [yt-dlp 当前 extractor](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/iwara.py) 并通过联网测试验证（2026-10-14）。
- 清晰度 Source 优先，数字分辨率降序，preview 最后；补齐 `//` 的 https 协议。进入详情和开始播放时重新取签名 URL，避免长时间停留后用旧链接。
- 普通缩略图 `https://i.iwara.tv/image/thumbnail/{file.id}/thumbnail-NN.jpg`；自定义缩略图 `/image/original/{customThumbnail.id}/{customThumbnail.name}`，均实测 200。
- `POST /user/login` `{email,password}` → user token；`POST /user/token` + Bearer user token → accessToken。访问 API 带 access token，50 分钟更新或遇 401 更新重试一次；user token 过期需重新登录。不支持外站嵌入视频，详情会显示无可播放文件。

**Hanime1 — `Hanime1Source.swift`**

- 唯一站点域名常量为 **`Hanime1Source.base` = `https://hanimeone.me`**；不使用被 Cloudflare 拦截的旧域名 hanime1.me。URLSession + Safari UA，直接解析 HTML，无需登录或客户端签名计算。
- 列表与关键词搜索统一 `/search?query=...&genre=...&sort=...&year=&month=&page=1`。站点从第 1 页开始，核心协议从第 0 页开始；解析 `rel=next`，加载下一页时保留分类、排序与关键词。
- 实测分类表单值为：裏番、泡麵番、Motion Anime、3DCG、2.5D、2D動畫、AI生成、MMD、Cosplay、新番預告，以及全部。`3D動畫`、`同人作品` 不是当前 genre 值。
- 排序值为：最新上市、最新上傳、本日排行、本週排行、本月排行、觀看次數、讚好比例、時長最長、他們在看。代码选项有真实表单 fixture 测试核对。
- 标签参数确实是重复 `tags[]`；年份、月份也存在。这次 UI 按需求只暴露分类、排序和关键词；详情展示标签。
- 横版卡片 `.horizontal-card`，竖版 `.home-rows-videos-title`；只收集包含封面的 `/watch?v=` 链接，排除广告并按 ID 去重。封面方向作为模型数据交给共用卡片。
- `/watch?v={id}`：标题 `#shareBtn-title`、作者 `#video-artist-name`、简介 `.video-caption-text`、时长 `og:video:duration`、标签 `.single-video-tag` 中的搜索链接；不把投票操作当标签。
- 从 `video#player source[src]` 提取播放地址，按 `size` 数字降序，默认最高。十个实际分类各抽查一页均为 MP4 source；存在 480/720/1080p，页面经常按 720、480、1080 排列。未在这些样例发现 m3u8 或 script-only 播放地址，不实现未经验证的 JS 地址提取。标准 source 的 URL 交给 AVPlayer。
- MP4 与封面包含有时效的 `secure` 参数，由站点返回；不计算签名、不保存到仓库。共用详情页在开始播放时重新请求详情，刷新直链。实际视频 Range 请求无需 Referer 即返回 206。

**wnacg — `WnacgSource.swift`**

- 最新 `/albums-index-page-{n}.html`；分类 `/albums-index-page-{n}-cate-{id}.html`，分类名/ID 从导航实时解析。
- 搜索 `/search/?q=...&f=_all&s=create_time_DESC&syn=yes&p={n}`，分页通过数字链接判断，不能只看 `.next`。
- 详情 `/photos-index-aid-{id}.html`；整本图像 `/photos-gallery-aid-{id}.html`。
- 图集是 `document.writeln` 包裹的 JS 字符串；只解析，不执行 JS。处理真实制表符和转义引号，从 imglist 提取页面，排除末尾 `/themes/.../shoucang.jpg` 收藏提示图。封面偶有 `////` 前缀，统一为 https。
- 图片带相册 Referer，通过 ImageIO 原生解码 WebP。站点图片签名有时效，每次开始阅读重新获取；阅读中链接过期可返回详情重新打开。

真实 JSON/HTML fixtures 在 `Packages/ShelfCore/Tests/ShelfCoreTests/Fixtures/`，记录了采集路径；签名 hash/verify 已脱敏。联网测试每次重新获取地址，不使用旧 fixture 链接。

## 验证边界

macOS 核心解析、分页、双页顺序、登录请求/刷新/退出的模拟传输测试，以及真实网络列表/详情/清晰度/视频字节范围/漫画首图和原生解码都可复现。没有用户账号，真实登录和权限内容未验证；没有 tvOS 运行时或配对设备，实际焦点流、画面布局、遥控器手感和 AVPlayer 解码播放须在 Apple TV 验收。现有工程未定制 App Icon/Top Shelf 素材。
