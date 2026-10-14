# inHebi

自用 tvOS 原生应用：iwara / Hanime1 视频、wnacg 漫画。当前状态、用户做过的决定和工作约定见 [docs/HANDOFF.md](docs/HANDOFF.md)。SwiftUI + AVKit + URLSession；无 WebView、后端或下载；SwiftData 保存观看历史、阅读页码和多收藏夹，通过 CloudKit 私有数据库同步。本地保存筛选偏好。最低 tvOS 18；InHebiCore 支持 iOS 18 / macOS 15 / tvOS 18。唯一外部依赖是 SwiftSoup（锁定文件当前解析为 2.14.2）。

## 打开与验证

打开 `inHebi.xcodeproj`，选择 **inHebi** scheme。工程已提交，无需 XcodeGen/Tuist。添加 App Swift 文件后可运行 `python3 script/generate-project.py` 重新生成工程；生成器会覆盖 pbxproj，团队配置也应同步修改生成器。

```sh
cd /Users/gakeiakira/code/tv-shelf
swift test --package-path Packages/InHebiCore
INHEBI_LIVE_TESTS=1 swift test --package-path Packages/InHebiCore
./script/verify.sh
# 或一次运行联网测试 + generic 编译：
INHEBI_LIVE_TESTS=1 ./script/verify.sh
```

验证脚本使用：

```sh
xcodebuild -project inHebi.xcodeproj -scheme inHebi \
  -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath artifacts/DerivedDataSimulator CODE_SIGNING_ALLOWED=NO build
```

Generic 编译不需要 tvOS 模拟器运行时。未下载模拟器运行时；构建产物在 `artifacts/DerivedDataSimulator/Build/Products/Debug-appletvsimulator/inHebi.app`。`DerivedData` 和 SwiftPM `.build` 均不入 git，可按需删除释放磁盘。

## 签名与 Apple TV 安装

- Bundle ID：`com.dreaife.inhebi`；自动签名；默认团队 **ALZ45VUZFN**，来自本机 Apple Development 公钥证书的 OU 字段，且与本机 Developer ID 团队一致。本机另有一个开发团队；若要使用其他团队，在 inHebi target → Signing & Capabilities 中选择。
- Xcode → Settings → Apple Accounts 已登录开发者账号，签名优先使用该账号（团队 ALZ45VUZFN）。运行脚本前先执行 `unset INHEBI_AUTH_KEY_PATH INHEBI_AUTH_KEY_ID INHEBI_AUTH_KEY_ISSUER`，保留 `-allowProvisioningUpdates`。
- Apple TV 和 Mac 接入同一网络。在 Apple TV 的“设置 → 遥控器与设备 → 遥控 App 与设备”进入配对界面。
- Xcode 27 使用 **Xcode → Open Developer Tool → Device Hub**（或运行目标菜单里的 Manage Devices），添加并配对 Apple TV，输入电视显示的配对码。按 Xcode/设备提示完成开发准备。
- 将运行目标选为该 Apple TV，点击 Run。Xcode 注册设备并生成开发 provisioning profile；以后签名/profile 过期时重新构建安装。

官方说明：[运行到设备](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[Device Hub 配对](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)。已使用自动 provisioning 在 Apple TV 4K 第三代 / tvOS 27 上完成真机 UI 测试。

## 使用

顶部 Tab 为 iwara、Hanime1、漫画、我的、设置。横版四列、竖版五列，只有封面参与系统 `.card` 焦点放大，文字在外；封面与标题间留 32pt，保留原生放大幅度。封面占满整列并与标题左缘对齐，横版为 16:9、Hanime1 竖版为 2:3、漫画为 3:4；不再按视口高度压缩封面，不要求首屏完整两行，允许竖版第二行仅部分露出；靠近底部自动加载下一页。列数、间距、字体和解码上限集中在 `inHebi/Layout.swift`。

- iwara：横条切排序，右侧分级按钮循环全部/一般/成人；Hanime1：横条切分类，右侧面板切排序。芯片聚焦停留 0.4 秒后切换内容，快速掠过不会请求。右侧按钮仍按下生效。iwara 默认趋势排第一；芯片选择仅在本次运行保留，排序面板/分级继续跨启动记忆。
- 漫画：最新、所有父类及子类按站点顺序平铺在横条；子类显示“大类·子类”，右侧只保留搜索。
- 搜索：右端放大镜进入独立搜索页，选择输入框后用原生键盘的 `search` 完成键提交，不逐字请求；Hanime1 带入当前分类。搜索不改原列表状态。
- 卡片 Select 进详情，播放/暂停键直接播放或阅读。进入详情默认聚焦播放/继续阅读；作者、标签、同作者/相关卡片和相册页预览可操作。
- 视频详情显示日期、时长、分辨率、播放/喜欢/评论或好评、分级/分类；简介是可展开的按钮。系统播放器带标题/作者/封面，结束返回来源页面，退出即停止。
- 登录：仅 user token 存 Keychain，access token 留内存并按 JWT exp 刷新。换 token 返回 401/403 时清理过期会话，退回游客并在设置提示。密码提交后或离开设置清空。
- 阅读：按屏幕适配完整页面；默认左键下一页，设置可改方向。双页以两张图片的实际宽高比适配同一高度，内侧边缘无缝相接、整体居中、不裁切。从缩略图跳到或从详情续读第 N 页时，配对始终为 N/N+1，不按奇偶重新对齐；默认 N 在右，改为从左往右时 N 在左。双页每次前进或后退两页，后退不早于第 1 页，末尾可只显示一页；记忆配对的起始页，预加载从当前可见页之后开始。
- 阅读面板：上键呼出并聚焦当前页缩略图（双页为起始页 N），缩略图条再按上收起；下键呼出并聚焦底部“继续阅读”，按钮行再按下收起，按上显式回到当前页缩略图。Select/播放暂停呼出时也聚焦当前页缩略图。先滚动到当前页，等该缩略图实际可见后再请求焦点，避免 LazyHStack 尚未创建目标。Menu 先收面板再退出，收起后左右翻页正常。
- 方向呼出后最初 1 秒忽略同方向的边缘关闭；随后连发事件使关闭等待至少 350ms 的同向静默期，且不会缩短初始窗口，用于避免一次滑动呼出又立即收起。方向收起后，同方向重开需等待 350ms 静默；连续事件会延长此窗口。快速再次点按也受这些窗口约束。页码以 22pt 小字显示在右下角；面板打开时预览页码保持右对齐、位于按钮行上方。双页模式记忆在本机，页码存进可同步的观看历史；详情显示“从第 N 页继续”。没有离线图片缓存。
- 详情返回保留内容、滚动位置和原卡片焦点。网格里 Menu 先回顶部并聚焦选中芯片，再按 Menu 回系统 Tab；从系统 Tab 按下一次进入选中芯片。Menu 和切 Tab 不重新请求已有列表。常规 UI 测试使用独立偏好存储和内存 ModelContainer，不覆盖正常偏好、历史或收藏，也不写入 iCloud。

## iCloud 历史与收藏

- 模型和读写接口在 `Packages/InHebiCore/Sources/InHebiCore/LibraryStore.swift`，不依赖 tvOS UI。`SavedMediaItem` 保存来源、站点 ID、标题、封面链接、卡片方向、最近观看时间及零基阅读页码；`FavoriteFolder` 保存稳定 ID、名称和创建时间，通过可选双向多对多关系关联条目。所有持久化属性有默认值或可选，没有唯一约束。默认收藏夹 ID 为 `default`，首次收藏时创建；导入完成后合并跨设备同时创建的重复条目/默认夹，按创建时间、再按不可变记录 ID 选择保留对象，最新元数据单独合并。
- 视频开始播放、打开漫画时写入历史，同一来源与 ID 只更新时间；翻页只更新内存对象，由 SwiftData 自动保存，退出阅读器时显式保存一次。历史/收藏携带列表的封面方向、封面链接与裁切规则；详情刷新仍更新标题，已存竖版不会被详情的横版播放器海报覆盖。清空历史同时清除续读页码，但保留收藏；没有历史且不属于任何收藏夹的条目随移除操作删除。
- 视频/漫画详情的星标短按切换默认收藏，长按打开带选中状态的收藏夹列表，可逐个切换或新建收藏夹；实心只表示属于默认收藏夹，短按一定切换星标状态；仅在其他收藏夹时为空心，按钮文字显示总收藏夹数量（如“收藏 · 2 个收藏夹”）。
- “我的”复用 0.4 秒聚焦切换的筛选条，历史在前、收藏夹在后。按来源分区，卡片保持原有列数/比例；Select 进入详情、播放/暂停直接打开。卡片长按菜单可从当前列表移除。右侧固定按钮清空历史或管理当前收藏夹（重命名/删除）；芯片标题、顺序和删除同步更新，删除当前收藏夹后回到“历史”。详情使用独立导航值，取消收藏移除原卡片时仍停留在详情。漫画快速打开直接复用当前列表元数据，只请求页面，不为写历史额外请求详情。
- 设置显示 iCloud 账号状态；未登录时保留本机数据。iCloud 容器为 `iCloud.com.dreaife.inhebi`，仅使用私有数据库。开发签名使用 **CloudKit Development** 环境。
- `script/generate-project.py` 同时生成 `inHebi/inHebi.entitlements`，保留 iCloud、推送和 `UIBackgroundModes = remote-notification` 配置；新 App ID 是 `com.dreaife.inhebi`，UI 测试是 `com.dreaife.inhebi.uitests`。内部工程、scheme、目录已统一为 inHebi，核心模块为 InHebiCore。
- DEBUG 的 `Library/Caches/inHebi/FocusTrace.txt` 包含 `cloudkit kind=import/export/setup completed=... success=... error=domain:code`，不记录云端条目内容。常规 UI 测试使用内存库，不能证明同步。专用 `testCloudKitExport` 仅在 `TEST_RUNNER_INHEBI_CLOUD_TEST=1` 时运行，通过 DEBUG 的 `--ui-cloud-library` 让这条用例使用真实 CloudKit 库；它检查 iCloud 状态、选择尚未加入默认收藏的条目、收藏后取消，并等待新增和清理的导出。若默认收藏夹为测试新建，也会删除空夹。取日志核对 `kind=export completed=true success=true`。
- 新应用全新安装，不迁移旧应用的数据或 Keychain。旧 `com.dreaife.shelf` 保留在电视上；新 iwara 登录由用户输入并确认。

### Xcode 账号自动签名

2026-10-14：清除三个 API 密钥环境变量后，Xcode 已登录账号自动 provisioning 成功。已核对签名产物和 profile 均包含 `com.dreaife.inhebi`、`iCloud.com.dreaife.inhebi`、CloudKit 和开发推送权限；无需手动创建或关联容器。旧 API 密钥方式同日返回 `Authentication failed`，暂不使用。

```sh
unset INHEBI_AUTH_KEY_PATH INHEBI_AUTH_KEY_ID INHEBI_AUTH_KEY_ISSUER
./script/test-device.sh "$INHEBI_DEVICE_ID"
# 测试通过并提交之后：
./script/install-device.sh "$INHEBI_DEVICE_ID"
# 专用真实 CloudKit 验收（保持当前安装版本号）：
TEST_RUNNER_INHEBI_CLOUD_TEST=1 ./script/test-device.sh "$INHEBI_DEVICE_ID" \
  -only-testing:inHebiUITests/InHebiUITests/testCloudKitExport \
  "CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD)" "INHEBI_COMMIT=$(git rev-parse --short HEAD)"
```

依据：[Apple SwiftData 同步要求](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)、[启用 App 能力](https://developer.apple.com/help/account/identifiers/enable-app-capabilities)。

### 2026-10-14 真机验收

常规 29 项全部取得通过结果：首轮 23 通过 / 6 失败，修正原生 Select 长按、稀疏列表焦点分区、管理窗口关闭后的焦点恢复及测试定位/输入时序后，定向重跑补齐。主屏 inHebi 图标可见且可聚焦，旧应用保留。正常启动真实 SwiftData/CloudKit 容器成功。

真实 CloudKit 专用用例 1/1 通过，设置显示“已登录 iCloud”；新增收藏后取消，测试新建的空默认夹也已删除。清理后的日志：`2026-10-14T10:53:00.220 kind=code cloudkit kind=export completed=true success=true error=none`。证据在 `artifacts/inhebi-cloudkit-focus.txt`，这里只确认 Apple TV 的真实导入/导出，不代替未来 Mac/iOS 双端同步验收。

### 原生播放器按键与边界

播放器继续使用 AVPlayerViewController；已移除外层 SwiftUI 的 Menu 直接退出处理，让 AVKit 先收原生面板/控制层，再通过公开 delegate 请求退出。真机 tvOS 27 实测：

| 输入 | 呼出/动作 | 再次同键及收起方式 |
| --- | --- | --- |
| 上 | 进度控制栏，初次焦点在 Audio 工具 | 再按上保留控制层；Menu 由 AVKit 逐层收起，再退出播放 |
| 下 | Info 内容面板，含 From Beginning | 再按下仍在 Info；Menu 先收 Info，再由系统处理控制栏和退出 |
| Select（触控板按下） | 暂停并显示进度控制栏 | 再按切换播放，不是面板开关；Menu 收层/退出 |
| 触控面轻触、指腹滑动 | XCTest 的 XCUIRemote 无此输入 API，未模拟 | 保留系统手势，需用实体遥控器确认；不把方向按钮测试当成滑动验证 |

系统进度栏和 Info 的显隐不是同一个状态。AVKit 未公开原生面板的同方向关闭指令；[Apple 明确要求不要在播放器显示期间切换 showsPlaybackControls](https://developer.apple.com/documentation/avkit/avplayerviewcontroller/showsplaybackcontrols)，而 `playbackControlsIncludeTransportBar` / `playbackControlsIncludeInfoViews` 只控制是否允许出现，不会立即收起。此轮没有用私有视图、模拟 Menu 事件或自制播放器强行实现视频同方向收起。

Debug 焦点记录增加阅读面板的呼出方向、当前页、可见缩略图赋焦及被忽略的边缘事件，以及 AVKit 公开控制栏显隐/退出回调。`--ui-test-controls-probe` 仅在 UI 测试模式限制媒体到约 3 秒后暂停，常规使用不受影响。阅读器连发测试注入 100/200/900/1100ms 的确定事件时间，验证初始窗口不会缩短且连续输入可延长窗口，不能代替实体 Siri Remote 滑动手感确认。

2026-10-14 面板交互验收（本分支 build 18）：离线 28 通过 / 3 联网跳过，`verify.sh` generic 编译通过，10 个受影响真机用例最终通过。较后页覆盖第 17 页、双页起始第 23 页及从第 21 页续读后首次呼出；基线第 17 页测试没有复现“回到第一页”，因此修订采用显式可见性赋焦，并保留实体操作验证边界。真机测试记录及失败后定向修正过程见 `progress.md`。

## 数据源接口与易变位置

核心代码在 `Packages/InHebiCore/Sources/InHebiCore/`；`VideoSource` 和 `AlbumSource` 分开，UI 依赖协议，后续第二个视频源可直接实现 `VideoSource`。

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

真实 JSON/HTML fixtures 在 `Packages/InHebiCore/Tests/InHebiCoreTests/Fixtures/`，记录了采集路径；签名 hash/verify 已脱敏。联网测试每次重新获取地址，不使用旧 fixture 链接。

## 验证边界

核心离线与联网测试包括真实 fixtures、分页重入/取消、JWT 到期和无效 user token 回游客、三站列表/详情/媒体请求。真机覆盖布局、焦点、搜索实际提交、两源静音播放与停止、播放结束、阅读跳页/续读/方向。已有 Keychain 会话恢复正常；新输入真实账号的登录流程及有声输出仍由用户确认。

未做播放续播、搜索历史、正式 searchScopes、关注、排行榜、文件大小/额外评论详情等未选 P2。应用图标和 Top Shelf 见文末“tvOS 品牌资源”。

## Apple TV UI 测试

`inHebiUITests` target 使用 `XCUIRemote.shared` 操作真实遥控器焦点，覆盖返回保留/分页、筛选/搜索、横竖网格、两个源播放/停止、播放结束/信息面板、阅读跳页续读与双向排列。选取实时列表首项，不绑定视频或相册 ID。测试结束（包括失败）退出 App。

`testFocusedGridTitlesAndAspectRatios` 使用元素 frame 验证横版、Hanime1 竖版、漫画的整列宽、原始宽高比、未聚焦时与标题左缘对齐，以及聚焦封面不与标题相交（首行和第二行分别检查）；不查看封面原图。`testReaderBottomRowDownClosesControls` 逐一检查底部六个按钮按下关闭面板及页码位置。阅读跳页/续读/方向用例同时验证奇偶起页、每次两页、加载后的双页图像 frame 同高无缝居中。

```sh
./script/test-device.sh "$INHEBI_DEVICE_ID"
# 只重跑受影响路径，例如：
./script/test-device.sh "$INHEBI_DEVICE_ID" -only-testing:inHebiUITests/InHebiUITests/testReaderJumpResumeAndSpread
```

签名优先使用已登录的 Xcode Apple Accounts。App Store Connect API 密钥在 2026-10-14 实测认证失败，暂不使用；运行脚本前清除 `INHEBI_AUTH_KEY_PATH`、`INHEBI_AUTH_KEY_ID`、`INHEBI_AUTH_KEY_ISSUER`。脚本仅在显式设置密钥路径时传 API 密钥参数，否则使用 Xcode 账号。密钥只按本机路径引用，不复制内容；不要把真实标识写入仓库。脚本启用自动 provisioning/设备注册，真机 DerivedData 在 `artifacts/DerivedDataDevice`。结果保存到 `artifacts/device-ui-*.xcresult`；截图导出到 `artifacts/screenshots/`，含英文页面名及 `index.json`。`artifacts/` 已忽略。也可单独运行 `python3 script/export-screenshots.py RESULT.xcresult`。

Debug App 同时带 `--ui-testing --mute-playback` 启动参数时静音，显示供测试读取的实际 AVPlayer 状态和播放时间；正常启动不静音、不显示测试状态。Release 不启用测试参数。

真机测试完成、截图检查和提交之后，使用相同签名环境变量构建并留下正常签名 App：

```sh
./script/install-device.sh "$INHEBI_DEVICE_ID"
```

安装脚本在 Info.plist 写入 `InHebiCommit`，build number 为 git commit 数量，便于核对版本；安装后不自动播放。

2026-10-14 最终验收：核心离线及联网测试通过（联网 28 项），真机完整 19 项通过，加分类图标后筛选条相关 9 项重跑通过，generic tvOS 编译通过。39 张命名截图已逐张检查，筛选条末尾、返回和分类搜索截图在最后导出后再次复核。结果见 `progress.md`，截图在 `artifacts/screenshots/`。

同日阅读器/卡片修订：新增 3 项 ReaderLayout 测试后，离线 28 通过 / 3 联网跳过，联网 31 通过；generic 编译通过。受影响真机 8 项均取得通过结果（首轮 7/8，新按钮测试定位修正后 1/1），未重跑无关播放用例。只读取 UI 元素 frame，没有打开封面截图；测试结束已确认旧应用进程退出。正常签名安装版本 build 16。

同日网格尺寸回调（build 17）：恢复整列宽及原始比例，保留 32pt 标题间距。离线 28 通过 / 3 联网跳过，`verify.sh` 和 generic 编译通过，受影响真机网格/焦点 5 项全部通过。两行分别聚焦检查，横版实测间隙约 20.75pt、Hanime1 竖版和漫画均 12pt；不以完整两行可见作为验收条件，阅读器保持不变。

已验证的原生行为差异：筛选条采用独立固定头部，避开 safeAreaInset 在 tvOS 的焦点滚动影响；芯片保持固定几何尺寸与同一种原生按钮样式并用青色填充表示选中；搜索使用子页 TextField，因 searchable 的原生键盘未触发期望的提交；阅读器使用隐藏 Tab 的导航页，避开全屏模态返回焦点问题。条高 80pt 容纳 60pt 的原生芯片按钮与焦点效果；网格不以首屏完整两行为尺寸约束。


## 筛选条交互修订

`inHebi/BrowseList.swift` 是视频/漫画共用的列表焦点与滚动容器。芯片条用 `inHebi/ChipStrip.swift` 中的 UIKit UIScrollView/UIStackView/UIButton，焦点矩形严格限制在 80pt 条内；按钮最小宽 220pt、间距 24pt，末端无渐变遮挡。保留系统 TabView，上下左右由原生焦点引擎按实际布局移动，列表不再使用 onMoveCommand 或 focusHeading 搬焦点。

筛选条上下各有一条 10pt 的 `UIFocusGuide`，直接指向当前选中芯片；进入条内后禁用两条引导，离开后启用，判断仅依据实际焦点所在视图，不依赖方向键或 focusHeading。跨行进入不再先聚焦错误芯片再纠正。Menu 通过已注册在 UIKit 芯片条上的 SwiftUI `.strip` 焦点目标返回；没有原来的根控制器重置或异步入条纠正。芯片内部左右仍由原生引擎移动，停留 400ms 后切分类，排序/搜索仍按下生效。引导不绘制内容，布局和按钮外观不变。参见 [Apple UIFocusGuide](https://developer.apple.com/documentation/uikit/uifocusguide)。

分页同时观察滚动位置和当前卡片是否接近末尾，每次追加后重新评估；网络请求由 Pager 持有，切换筛选时取消旧请求，滚动条件改变不会中途取消翻页请求。底部显示加载提示。核心测试覆盖取消和过期结果隔离。

真机测试逐次检查左右一个芯片、全部分类可达且末尾完整可见、四种状态下的顶部入口、三页连续加载和 Menu 回顶部。XCUIRemote 单次调用约 0.5 秒；另外用仅测试模式的 `--ui-fast-focus` 注入 100ms 焦点变化，验证真实视图防抖到真实请求的链路。这个注入测试不能代表 Siri Remote 触控面滑动手感。

## DEBUG 焦点记录

Debug 构建无论正常启动还是 UI 测试，都会把最近 500 行焦点记录保存到应用容器 `Library/Caches/inHebi/FocusTrace.txt`。记录 UTC 时间、原生方向、前后视图及层级、逻辑元素标识、SwiftUI FocusState、当前分类、条目数和加载状态；代码主动请求焦点会单独标记原因。文件异步写入，不联网、不改变界面、不记录密码或 token；Release 不记录。

遇到问题后停止继续操作，尽快在已配对 Mac 上取回：

```sh
./script/fetch-focus-trace.sh "$INHEBI_DEVICE_ID"
# 等价命令：
xcrun devicectl device copy from --device "$INHEBI_DEVICE_ID" \
  --domain-type appDataContainer --domain-identifier com.dreaife.inhebi \
  --source Library/Caches/inHebi/FocusTrace.txt \
  --destination artifacts/FocusTrace.txt
```

同时说明当时的数据源、是否刚切分类，以及最后几次是点按还是滑动。日志跨启动保留尾部，但后续操作会覆盖旧行；tvOS 缓存也可能被系统清理。

单次入条回归 `testSingleUpdateStripEntry` 在三个源选中非首项，分别从顶栏和网格左侧进入，断言原生焦点更新计数只增加 1；计数仅 UI 测试模式可见。

## tvOS 品牌资源

`inHebi/Assets.xcassets/InHebiBrand.brandassets` 包含主屏 Small（400×240 / 800×480）、App Store Large（1280×768）两个三层 image stack，以及普通/宽版 Top Shelf 的 1x/2x。图层从后到前为 Back（背景）、Middle（架板）、Front（书与播放屏）；imagestack JSON 按 Front、Middle、Back 登记。13 张 PNG 原样保留尺寸、透明边缘和不透明背景，均已纳入 git，构建不依赖 artifacts。

App Icons Source 为 `InHebiBrand`，在 `script/generate-project.py` 中维护，重新生成工程不会丢失资源或配置。`testHomeScreenIcon` 在退出应用后检查系统主屏上的 inHebi 图标存在、可见且已聚焦，并保留截图。真机主屏已显示新图标和静态 Top Shelf；真实遥控器的三层视差手感需人工确认。

## 筛选条符号

`inHebi/FilterSymbols.swift` 集中维护分类/排序到 SF Symbol 的映射、固定按钮符号和图标尺寸。漫画平铺标签按最后一个 `·` 后的子类名映射；未知分类使用 `tag`。当前采用全部建议符号，中日文字典图标分别为 `character.book.closed.zh` / `.ja`。已逐个核对 Apple CoreGlyphs 的 tvOS 可用性记录（全部最晚 tvOS 15 可用），并在真机测试中逐个构造 UIImage 检查。

芯片取消勾号，符号始终显示；选中但未聚焦时保持青色，其他未聚焦芯片为暗色，聚焦使用原生按钮效果。图标 26pt medium、文字 29pt、图文间距 12pt，按钮 60pt / 条高 80pt 不变。右侧固定区宽 470pt，保证新增排序符号后文字不省略。选中语义使用 accessibility selected trait；真机测试比较芯片未聚焦时的选中/未选中宽度，确保状态切换不会改布局。
