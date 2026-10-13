# Shelf

自用 tvOS 原生应用：iwara / Hanime1 视频、wnacg 漫画。SwiftUI + AVKit + URLSession；无 WebView、后端、下载、播放历史或收藏同步；本地保存筛选偏好与最近 50 本的阅读页码。最低 tvOS 18；ShelfCore 支持 macOS 15 / tvOS 18。唯一外部依赖是 SwiftSoup（锁定文件当前解析为 2.14.2）。

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
  -derivedDataPath artifacts/DerivedDataSimulator CODE_SIGNING_ALLOWED=NO build
```

Generic 编译不需要 tvOS 模拟器运行时。未下载模拟器运行时；构建产物在 `artifacts/DerivedDataSimulator/Build/Products/Debug-appletvsimulator/Shelf.app`。`DerivedData` 和 SwiftPM `.build` 均不入 git，可按需删除释放磁盘。

## 签名与 Apple TV 安装

- Bundle ID：`com.dreaife.shelf`；自动签名；默认团队 **ALZ45VUZFN**，来自本机 Apple Development 公钥证书的 OU 字段，且与本机 Developer ID 团队一致。本机另有一个开发团队；若要使用其他团队，在 Shelf target → Signing & Capabilities 中选择。
- 在 Xcode → Settings → Apple Accounts 登录开发者账号，确认目标团队和自动签名可用。
- Apple TV 和 Mac 接入同一网络。在 Apple TV 的“设置 → 遥控器与设备 → 遥控 App 与设备”进入配对界面。
- Xcode 27 使用 **Xcode → Open Developer Tool → Device Hub**（或运行目标菜单里的 Manage Devices），添加并配对 Apple TV，输入电视显示的配对码。按 Xcode/设备提示完成开发准备。
- 将运行目标选为该 Apple TV，点击 Run。Xcode 注册设备并生成开发 provisioning profile；以后签名/profile 过期时重新构建安装。

官方说明：[运行到设备](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[Device Hub 配对](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)。已使用自动 provisioning 在 Apple TV 4K 第三代 / tvOS 27 上完成真机 UI 测试。

## 使用

顶部 Tab 为 iwara、Hanime1、漫画、设置。横版四列、竖版五列，只有封面参与系统 `.card` 焦点放大，文字在外；靠近底部自动加载下一页。列数、间距、字体和解码上限集中在 `Shelf/Layout.swift`。

- iwara：横条切排序，右侧分级按钮循环全部/一般/成人；Hanime1：横条切分类，右侧面板切排序。左右移动只换焦点，Select 才请求。筛选记忆在本机。
- 漫画：父类在横条，子类在右侧面板；相同“漢化”等子类不再混成扁平列表。
- 搜索：右端放大镜进入独立搜索页，选择输入框后用原生键盘的 `search` 完成键提交，不逐字请求；Hanime1 带入当前分类。搜索不改原列表状态。
- 卡片 Select 进详情，播放/暂停键直接播放或阅读。进入详情默认聚焦播放/继续阅读；作者、标签、同作者/相关卡片和相册页预览可操作。
- 视频详情显示日期、时长、分辨率、播放/喜欢/评论或好评、分级/分类；简介是可展开的按钮。系统播放器带标题/作者/封面，结束返回来源页面，退出即停止。
- 登录：仅 user token 存 Keychain，access token 留内存并按 JWT exp 刷新。换 token 返回 401/403 时清理过期会话，退回游客并在设置提示。密码提交后或离开设置清空。
- 阅读：按屏幕适配完整页面；默认左键下一页，设置可改方向，双页左右顺序跟随。Select/上下/播放暂停打开缩略图跳页与工具栏，Menu 先收工具栏再退出。双页模式和页码记忆在本机；详情显示“从第 N 页继续”。没有离线图片缓存。
- 返回详情/列表或切 Tab 保留分页内容；列表额外记录滚动偏移和焦点卡片。UI 测试使用独立偏好存储，不覆盖正常使用偏好。

## 数据源接口与易变位置

核心代码在 `Packages/ShelfCore/Sources/ShelfCore/`；`VideoSource` 和 `AlbumSource` 分开，UI 依赖协议，后续第二个视频源可直接实现 `VideoSource`。

**iwara — `IwaraSource.swift`**

- URLSession + Safari User-Agent（`HTTPClient.swift`）；不要用 curl 的 Cloudflare 403 推断 App 请求失败。
- `/videos?limit=24&page=0&sort=date&rating=all`；sort 为 date/trending/popularity/views/likes，rating 为 all/general/ecchi。
- `count` 不一定是总量：实测 limit=2 得 count=3，limit=24 page=0 得 25，page=1 得 49。使用它判断后续页，不能推断游客只能看三条；游客已实测获取多页。
- 搜索实际是 **`/search?type=videos&query=...&page=0`**，复数 videos；单数 video 实测返回 500。搜索返回 page/count/limit/results，当前每页 32 条。
- `/video/{id}` 返回详情；`fileUrl` 请求带 `X-Version = SHA1("{fileId}_{expires}_{salt}")`。salt 在 **`IwaraSource.versionSalt`**，当前 `mSvL05GfEmeEmsEYfGCnVpEjYgTJraJN`，依据 [yt-dlp 当前 extractor](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/iwara.py) 并通过联网测试验证（2026-10-14）。
- 清晰度 Source 优先，数字分辨率降序，preview 最后；补齐 `//` 的 https 协议。进入详情和开始播放时重新取签名 URL，避免长时间停留后用旧链接。
- 普通缩略图 `https://i.iwara.tv/image/thumbnail/{file.id}/thumbnail-NN.jpg`；自定义封面列表使用 `/image/large/{customThumbnail.id}/{customThumbnail.name}`，详情使用 original；均实测 200。
- `POST /user/login` `{email,password}` → user token；`POST /user/token` + Bearer user token → accessToken。访问 API 带 access token，读取 JWT `exp` 并提前 60 秒刷新；换 token 返回 401/403 时退回游客并提示重新登录。不支持外站嵌入视频，详情会显示无可播放文件。

- `/videos?user=...`、`/videos?tags=...` 已验证返回作者/标签匹配的结果。`/video/{id}/related` 旧样例可用，但最新视频重复返回 500，本轮不启用 iwara 相关栏。

**Hanime1 — `Hanime1Source.swift`**

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

**wnacg — `WnacgSource.swift`**

- 最新 `/albums-index-page-{n}.html`；分类 `/albums-index-page-{n}-cate-{id}.html`，父类/子类从 `#album_tabs` 与 `.drop_dwon` 分层解析。
- 搜索 `/search/?q=...&f=_all&s=create_time_DESC&syn=yes&p={n}`，分页通过数字链接判断，不能只看 `.next`。
- 详情 `/photos-index-aid-{id}.html`；整本图像 `/photos-gallery-aid-{id}.html`。
- 图集是 `document.writeln` 包裹的 JS 字符串；只解析，不执行 JS。处理真实制表符和转义引号，从 imglist 提取页面，排除末尾 `/themes/.../shoucang.jpg` 收藏提示图。封面偶有 `////` 前缀，统一为 https。
- 图片带相册 Referer，通过 ImageIO 原生解码 WebP。站点图片签名有时效，每次开始阅读重新获取；阅读中链接过期可返回详情重新打开。

- 标签列表 `/albums-index-page-{n}-tag-{tag}.html` 已验证含第二页；相册详情解析分类、日期、标签及第一页的页面缩略图。起始页与 Referer 由 `AlbumSource` 提供，通用 UI 不拼站点域名。

真实 JSON/HTML fixtures 在 `Packages/ShelfCore/Tests/ShelfCoreTests/Fixtures/`，记录了采集路径；签名 hash/verify 已脱敏。联网测试每次重新获取地址，不使用旧 fixture 链接。

## 验证边界

核心离线与联网测试包括真实 fixtures、分页重入/取消、JWT 到期和无效 user token 回游客、三站列表/详情/媒体请求。真机覆盖布局、焦点、搜索实际提交、两源静音播放与停止、播放结束、阅读跳页/续读/方向。已有 Keychain 会话恢复正常；新输入真实账号的登录流程及有声输出仍由用户确认。

未做播放续播、搜索历史、正式 searchScopes、关注、排行榜、文件大小/额外评论详情等未选 P2。没有定制 App Icon/Top Shelf 素材。

## Apple TV UI 测试

`ShelfUITests` target 使用 `XCUIRemote.shared` 操作真实遥控器焦点，覆盖返回保留/分页、筛选/搜索、横竖网格、两个源播放/停止、播放结束/信息面板、阅读跳页续读与双向排列。选取实时列表首项，不绑定视频或相册 ID。测试结束（包括失败）退出 App。

```sh
./script/test-device.sh "$SHELF_DEVICE_ID"
# 只重跑受影响路径，例如：
./script/test-device.sh "$SHELF_DEVICE_ID" -only-testing:ShelfUITests/ShelfUITests/testReaderJumpResumeAndSpread
```

签名可使用 Xcode Apple Accounts，或设置 `SHELF_AUTH_KEY_PATH`、`SHELF_AUTH_KEY_ID`、`SHELF_AUTH_KEY_ISSUER` 三个环境变量使用 App Store Connect API 密钥。密钥只按本机路径引用，不复制内容；不要把真实标识写入仓库。脚本启用自动 provisioning/设备注册，真机 DerivedData 在 `artifacts/DerivedDataDevice`。结果保存到 `artifacts/device-ui-*.xcresult`；截图导出到 `artifacts/screenshots/`，含英文页面名及 `index.json`。`artifacts/` 已忽略。也可单独运行 `python3 script/export-screenshots.py RESULT.xcresult`。

Debug App 同时带 `--ui-testing --mute-playback` 启动参数时静音，显示供测试读取的实际 AVPlayer 状态和播放时间；正常启动不静音、不显示测试状态。Release 不启用测试参数。

真机测试完成、截图检查和提交之后，使用相同签名环境变量构建并留下正常签名 App：

```sh
./script/install-device.sh "$SHELF_DEVICE_ID"
```

安装脚本在 Info.plist 写入 `ShelfCommit`，build number 为 git commit 数量，便于核对版本；安装后不自动播放。

2026-10-14 改版验收：最终完整 11 项真机测试通过，另补跑阅读器路径保留展开工具栏截图；30 张命名截图已逐张检查。离线与联网核心测试、generic tvOS 编译均通过。最终结果与截图审阅记录见 `progress.md`，截图在 `artifacts/screenshots/`。

已验证的原生行为差异：筛选条采用独立固定头部，避开 safeAreaInset 在 tvOS 的焦点滚动影响；芯片保持同一种原生按钮样式并用颜色/勾号选中；搜索使用子页 TextField，因 searchable 的原生键盘未触发期望的提交；阅读器使用隐藏 Tab 的导航页，避开全屏模态返回焦点问题。条高 80pt 容纳实际约 66pt 的系统按钮与焦点效果，首屏仍完整两行。
