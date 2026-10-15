# 开发与测试

面向改代码的人：工程结构、构建验证命令、真机测试、调试手段和关键实现细节。站点接口见 [data-sources.md](data-sources.md)，带日期的修复与验收记录见 [changelog.md](changelog.md)。

## 工程结构

- `inHebi/`：tvOS App（SwiftUI + AVKit + 少量 UIKit）。
- `Packages/InHebiCore/`：与 UI 无关的核心模块，包含三个数据源、分页、HTTP 客户端和 SwiftData 存储。支持 iOS 18 / macOS 15 / tvOS 18，可以在 Mac 上直接 `swift test`。
- `inHebiUITests/`：在真机 Apple TV 上跑的 UI 测试。
- `script/`：工程生成、验证、真机测试、安装和取日志脚本。

唯一外部依赖是 SwiftSoup，版本以 `Package.resolved` 为准。工程不使用 WebView，也没有后端或下载功能。

## 工程文件

`inHebi.xcodeproj` 已提交，无需 XcodeGen/Tuist。添加 App Swift 文件后运行下面的命令重新生成工程：

```sh
python3 script/generate-project.py
```

生成器会覆盖 pbxproj，并同时生成 `inHebi/inHebi.entitlements`。签名团队、bundle ID、iCloud 容器、App 图标来源等配置都写在生成器里，修改这些配置时要改生成器，否则下次生成会被覆盖。

## 构建与验证

在仓库根目录运行：

```sh
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

Generic 编译不需要 tvOS 模拟器运行时，构建产物在 `artifacts/DerivedDataSimulator/Build/Products/Debug-appletvsimulator/inHebi.app`。`artifacts/`、`DerivedData` 和 SwiftPM `.build` 均不入 git，可按需删除释放磁盘。

联网测试（`INHEBI_LIVE_TESTS=1`）会实际请求三个站点，每次重新获取地址，不使用旧 fixture 链接。

## 签名

- Bundle ID 为 `com.dreaife.inhebi`，UI 测试为 `com.dreaife.inhebi.uitests`，iCloud 容器为 `iCloud.com.dreaife.inhebi`。都使用自动签名，默认团队写在 `script/generate-project.py` 里，是作者的团队。
- 签名优先使用 Xcode → Settings → Apple Accounts 里登录的账号。脚本在 `xcodebuild` 上加了 `-allowProvisioningUpdates -allowProvisioningDeviceRegistration`。
- 脚本也支持 App Store Connect API 密钥：设置 `INHEBI_AUTH_KEY_PATH`、`INHEBI_AUTH_KEY_ID`、`INHEBI_AUTH_KEY_ISSUER` 后改用密钥签名。只在显式设置密钥路径时才传密钥参数。想用 Xcode 账号时先清掉这三个变量：

  ```sh
  unset INHEBI_AUTH_KEY_PATH INHEBI_AUTH_KEY_ID INHEBI_AUTH_KEY_ISSUER
  ```

- 密钥只按本机路径引用，不复制内容；密钥内容、Key ID/Issuer ID 和设备标识不要写进仓库。
- 开发签名（Debug）使用 CloudKit Development 环境，Release 使用 Production。

参考：[运行到设备](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[Device Hub 配对](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)、[SwiftData 同步要求](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)、[启用 App 能力](https://developer.apple.com/help/account/identifiers/enable-app-capabilities)。

## 真机测试与安装

开发和验证都在真机 Apple TV 上做（Apple TV 4K 第三代，tvOS 27），没有用 tvOS 模拟器。`INHEBI_DEVICE_ID` 是已配对 Apple TV 的设备标识。

```sh
./script/test-device.sh "$INHEBI_DEVICE_ID"
# 只重跑受影响路径，例如：
./script/test-device.sh "$INHEBI_DEVICE_ID" -only-testing:inHebiUITests/InHebiUITests/testReaderJumpResumeAndSpread
# 测试通过并提交之后，留下正常签名的 App：
./script/install-device.sh "$INHEBI_DEVICE_ID"
```

- 真机 DerivedData 在 `artifacts/DerivedDataDevice`。结果保存到 `artifacts/device-ui-*.xcresult`；截图导出到 `artifacts/screenshots/`，含英文页面名及 `index.json`。也可单独运行 `python3 script/export-screenshots.py RESULT.xcresult`。
- 安装脚本在 Info.plist 写入 `InHebiCommit`，build number 为 git commit 数量，便于核对版本；安装后不自动播放。
- 截图里会有站点封面。只核对版式时，裁剪顶部标签栏和筛选条区域或缩成马赛克再看。

### UI 测试覆盖

`inHebiUITests` target 使用 `XCUIRemote.shared` 操作真实遥控器焦点，覆盖返回保留/分页、筛选/搜索、横竖网格、两个源播放/停止、播放结束/信息面板、阅读跳页续读与双向排列。选取实时列表首项，不绑定视频或相册 ID。测试结束（包括失败）退出 App。

- `testFocusedGridTitlesAndAspectRatios` 使用元素 frame 验证横版、Hanime1 竖版、漫画的整列宽、原始宽高比、未聚焦时与标题左缘对齐，以及聚焦封面不与标题相交（首行和第二行分别检查）；不查看封面原图。
- `testReaderBottomRowDownClosesControls` 逐一检查底部六个按钮按下关闭面板及页码位置。阅读跳页/续读/方向用例同时验证奇偶起页、每次两页、加载后的双页图像 frame 同高无缝居中。
- `testReaderClosingBurstDoesNotReopen` 覆盖上下两个方向收起后的连发及静默后重开。`testMenuDismissesWhilePlayingBothSources` 在两源静音播放几秒后直接按 Menu 逐层退出。
- `testSingleUpdateStripEntry` 在三个源选中非首项，分别从顶栏和网格左侧进入筛选条，断言原生焦点更新计数只增加 1；计数仅 UI 测试模式可见。
- `testHomeScreenIcon` 在退出应用后检查系统主屏上的 inHebi 图标存在、可见且已聚焦，并保留截图。
- 筛选条用例逐次检查左右一个芯片、全部分类可达且末尾完整可见、四种状态下的顶部入口、三页连续加载和 Menu 回顶部。
- XCUIRemote 单次调用约 0.5 秒。仅测试模式的 `--ui-fast-focus` 注入 100ms 焦点变化，验证真实视图防抖到真实请求的链路。自动化按键和时间注入都不能代表 Siri Remote 触控面的指腹滑动和轻触，这部分需要实体遥控器确认。

### 测试启动参数

测试参数只在 Debug 构建带 `--ui-testing` 启动时生效，Release 不启用。下表是常用的几个，完整列表可以在 `inHebi/` 里搜索 `--ui-`。

| 参数 | 作用 |
| --- | --- |
| `--ui-testing --mute-playback` | 静音播放，显示供测试读取的 AVPlayer 状态和播放时间 |
| `--ui-test-controls-probe` | 把媒体限制在约 3 秒后暂停 |
| `--ui-fast-focus` | 注入 100ms 的焦点变化 |
| `--ui-mixed-history` | 在内存库预置两个视频分区的历史 |
| `--ui-reset-preferences` | 清空测试专用的偏好存储 |
| `--ui-cloud-library` | 让该用例使用真实 SwiftData + CloudKit 库 |

常规 UI 测试使用独立偏好存储和内存 ModelContainer，不覆盖正常偏好、历史或收藏，也不写入 iCloud，因此不能证明同步。

### 真实 CloudKit 用例

`testCloudKitExport`、`testPersistentComicDetailHistory`、`testPersistentComicQuickHistory` 只在设置 `TEST_RUNNER_INHEBI_CLOUD_TEST=1` 时运行，通过 `--ui-cloud-library` 使用真实库。

- `testCloudKitExport` 检查 iCloud 状态，选择尚未加入默认收藏的条目，收藏后取消，并等待新增和清理的导出。默认收藏夹若为测试新建，也会删除空夹。
- 两个漫画历史用例只挑选库中不存在的条目，验证阅读、历史可达、从历史续读、重启后页码及 CloudKit 导出，结束后只清理自己新增的条目。
- 这些用例都不清空用户已有的历史或收藏。取焦点记录核对 `kind=export completed=true success=true`。

```sh
TEST_RUNNER_INHEBI_CLOUD_TEST=1 ./script/test-device.sh "$INHEBI_DEVICE_ID" \
  -only-testing:inHebiUITests/InHebiUITests/testCloudKitExport \
  "CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD)" "INHEBI_COMMIT=$(git rev-parse --short HEAD)"
```

## DEBUG 焦点记录

Debug 构建无论正常启动还是 UI 测试，都会把最近 500 行焦点记录保存到应用容器 `Library/Caches/inHebi/FocusTrace.txt`。记录 UTC 时间、原生方向、前后视图及层级、逻辑元素标识、SwiftUI FocusState、当前分类、条目数和加载状态；代码主动请求焦点会单独标记原因。文件异步写入，不联网、不改变界面、不记录密码或 token；Release 不记录。

记录还包括：

- 阅读面板的呼出方向、当前页、可见缩略图赋焦及被忽略的边缘事件。
- AVKit 公开控制栏显隐和退出回调。
- `cloudkit kind=import/export/setup completed=... success=... error=domain:code`，不记录云端条目内容。

遇到焦点问题时先停止操作，在已配对的 Mac 上取回记录再改代码：

```sh
./script/fetch-focus-trace.sh "$INHEBI_DEVICE_ID"
# 等价命令：
xcrun devicectl device copy from --device "$INHEBI_DEVICE_ID" \
  --domain-type appDataContainer --domain-identifier com.dreaife.inhebi \
  --source Library/Caches/inHebi/FocusTrace.txt \
  --destination artifacts/FocusTrace.txt
```

同时记下当时的数据源、是否刚切分类，以及最后几次是点按还是滑动。日志跨启动保留尾部，但后续操作会覆盖旧行；tvOS 缓存也可能被系统清理。

## 实现细节

### 网格与卡片

横版四列、竖版五列，只有封面参与系统 `.card` 焦点放大，文字在外；封面与标题间留 32pt，保留原生放大幅度。封面占满整列并与标题左缘对齐，横版为 16:9、Hanime1 竖版为 2:3、漫画为 3:4；不按视口高度压缩封面，允许竖版第二行仅部分露出。靠近底部自动加载下一页。列数、间距、字体和解码上限集中在 `inHebi/Layout.swift`。

详情返回保留内容、滚动位置和原卡片焦点。网格里 Menu 先回顶部并聚焦选中芯片，再按 Menu 回系统 Tab；从系统 Tab 按下一次进入选中芯片。Menu 和切 Tab 不重新请求已有列表。

“我的”页的分区网格预先创建行和焦点卡片，网络浏览页仍使用 LazyVGrid。原因是懒加载网格不创建屏幕外的卡片，排在下面的分区焦点进不去。只有收藏/历史这类可移除的卡片挂 contextMenu。

### 筛选条

`inHebi/BrowseList.swift` 是视频/漫画共用的列表焦点与滚动容器。芯片条用 `inHebi/ChipStrip.swift` 中的 UIKit UIScrollView/UIStackView/UIButton，焦点矩形严格限制在 80pt 条内；按钮最小宽 220pt、间距 24pt，末端无渐变遮挡。保留系统 TabView，上下左右由原生焦点引擎按实际布局移动，列表不使用 onMoveCommand 或 focusHeading 搬焦点。

筛选条上下各有一条 10pt 的 `UIFocusGuide`，直接指向当前选中芯片；进入条内后禁用两条引导，离开后启用，判断仅依据实际焦点所在视图。Menu 通过注册在 UIKit 芯片条上的 SwiftUI `.strip` 焦点目标返回。芯片内部左右由原生引擎移动，停留 400ms 后切分类，排序/搜索仍按下生效。参见 [Apple UIFocusGuide](https://developer.apple.com/documentation/uikit/uifocusguide)。

iwara 默认趋势排第一。芯片选择只在本次运行保留，每次启动从第一个开始；右侧排序面板和分级跨启动记忆。漫画的最新、所有父类及子类按站点顺序平铺，子类显示“大类·子类”，右侧只保留搜索。搜索页带入 Hanime1 当前分类，不改原列表状态。

分页同时观察滚动位置和当前卡片是否接近末尾，每次追加后重新评估；网络请求由 Pager 持有，切换筛选时取消旧请求，滚动条件改变不会中途取消翻页请求。底部显示加载提示。核心测试覆盖取消和过期结果隔离。

`inHebi/FilterSymbols.swift` 集中维护分类/排序到 SF Symbol 的映射、固定按钮符号和图标尺寸。漫画平铺标签按最后一个 `·` 后的子类名映射；未知分类使用 `tag`。中日文字典图标分别为 `character.book.closed.zh` / `.ja`。所有符号最晚 tvOS 15 可用。芯片不显示勾号，选中但未聚焦时为青色，其他未聚焦芯片为暗色，聚焦使用原生按钮效果。图标 26pt medium、文字 29pt、图文间距 12pt，按钮 60pt / 条高 80pt。右侧固定区宽 470pt，保证排序文字不省略。选中语义使用 accessibility selected trait。

### 已验证的原生行为差异

- 筛选条采用独立固定头部，避开 safeAreaInset 在 tvOS 的焦点滚动影响。
- 芯片保持固定几何尺寸与同一种原生按钮样式，用青色填充表示选中。
- 搜索使用子页 TextField，因为 searchable 的原生键盘没有触发期望的提交。
- 阅读器使用隐藏 Tab 的导航页，避开全屏模态返回焦点问题。

### 阅读器

- 按屏幕适配完整页面。双页以两张图片的实际宽高比适配同一高度，内侧边缘无缝相接、整体居中、不裁切。跳到或续读第 N 页时配对始终为 N/N+1，不按奇偶重新对齐。双页每次前进或后退两页，记忆配对的起始页，预加载从当前可见页之后开始。
- 上键呼出面板并聚焦当前页缩略图（双页为起始页 N），缩略图条再按上收起。下键呼出并聚焦底部“继续阅读”，按钮行再按下收起，按上回到当前页缩略图。Select/播放暂停呼出时也聚焦当前页缩略图。Menu 先收面板再退出。
- 面板呼出时先滚动到当前页缩略图，等它实际可见后再请求焦点，避免 LazyHStack 尚未创建目标。
- 默认 N 在右，改为从左往右时 N 在左。页码以 22pt 小字显示在右下角；面板打开时预览页码保持右对齐、位于按钮行上方。
- 防止一次滑动连续呼出/收起：方向呼出后最初 1 秒忽略同方向的边缘关闭；随后连发事件使关闭等待至少 350ms 的同向静默期，且不缩短初始窗口。方向收起后，同方向重开需等待 350ms 静默，连续事件会延长此窗口。
- 双页模式记忆在本机，页码存进可同步的观看历史。没有离线图片缓存。

### 播放器

播放器使用 AVPlayerViewController。外层 SwiftUI 不直接处理 Menu 退出，让 AVKit 先收原生面板/控制层，再通过公开 delegate 请求退出。tvOS 27 真机实测：

| 输入 | 呼出/动作 | 再次同键及收起方式 |
| --- | --- | --- |
| 上 | 进度控制栏，初次焦点在 Audio 工具 | 再按上保留控制层；Menu 由 AVKit 逐层收起，再退出播放 |
| 下 | Info 内容面板，含 From Beginning | 再按下仍在 Info；Menu 先收 Info，再由系统处理控制栏和退出 |
| Select（触控板按下） | 暂停并显示进度控制栏 | 再按切换播放，不是面板开关；Menu 收层/退出 |
| 触控面轻触、指腹滑动 | XCUIRemote 无此输入 API，未模拟 | 保留系统手势，需用实体遥控器确认 |

系统进度栏和 Info 的显隐不是同一个状态。AVKit 没有公开原生面板的同方向关闭指令；[Apple 要求不要在播放器显示期间切换 showsPlaybackControls](https://developer.apple.com/documentation/avkit/avplayerviewcontroller/showsplaybackcontrols)，而 `playbackControlsIncludeTransportBar` / `playbackControlsIncludeInfoViews` 只控制是否允许出现，不会立即收起。项目没有用私有视图、模拟 Menu 事件或自制播放器来实现同方向收起。

### 登录

只有 iwara 的 user token 存 Keychain，access token 留在内存并按 JWT exp 刷新。换 token 返回 401/403 时清理过期会话，退回游客并在设置提示。密码提交后或离开设置即清空。

### iCloud 历史与收藏

- 模型和读写接口在 `Packages/InHebiCore/Sources/InHebiCore/LibraryStore.swift`，不依赖 tvOS UI。`SavedMediaItem` 保存来源、站点 ID、标题、封面链接、卡片方向、最近观看时间及零基阅读页码；`FavoriteFolder` 保存稳定 ID、名称和创建时间，通过可选双向多对多关系关联条目。
- 为满足 CloudKit 要求，所有持久化属性有默认值或可选，没有唯一约束。SwiftData 的 @Model 类型名和属性名不要改，改了会让已有的 iCloud 记录失联。
- 默认收藏夹 ID 为 `default`，首次收藏时创建。导入完成后合并跨设备同时创建的重复条目和默认夹，按创建时间、再按不可变记录 ID 选择保留对象，最新元数据单独合并。
- 视频开始播放、打开漫画时写入历史，同一来源与 ID 只更新时间。翻页只更新内存对象，由 SwiftData 自动保存，退出阅读器时显式保存一次。
- 历史/收藏携带列表的封面方向、封面链接与裁切规则；详情刷新仍更新标题，已存竖版不会被详情的横版播放器海报覆盖。
- 清空历史同时清除续读页码，但保留收藏；没有历史且不属于任何收藏夹的条目随移除操作删除。
- 详情星标短按切换默认收藏，长按打开带选中状态的收藏夹列表，可逐个切换或新建。实心只表示属于默认收藏夹；只在其他收藏夹时为空心，按钮文字显示所在收藏夹数量（如“收藏 · 2 个收藏夹”）。
- “我的”页右侧按钮清空历史或管理当前收藏夹（重命名/删除），删除当前收藏夹后回到“历史”。详情使用独立导航值，取消收藏移除原卡片时仍停留在详情。
- 漫画快速打开直接复用当前列表元数据，只请求页面，不为写历史额外请求详情。
- entitlements 保留 iCloud、推送和 `UIBackgroundModes = remote-notification` 配置，由生成器维护。

### tvOS 品牌资源

`inHebi/Assets.xcassets/InHebiBrand.brandassets` 包含主屏 Small（400×240 / 800×480）、App Store Large（1280×768）两个三层 image stack，以及普通/宽版 Top Shelf 的 1x/2x。图层从后到前为 Back（背景）、Middle（架板）、Front（书与播放屏）；imagestack JSON 按 Front、Middle、Back 登记。13 张 PNG 原样保留尺寸、透明边缘和不透明背景，均已纳入 git。

App Icons Source 为 `InHebiBrand`，在 `script/generate-project.py` 中维护，重新生成工程不会丢失资源或配置。三层视差手感需要用实体遥控器确认。

## 验证边界

核心离线与联网测试包括真实 fixtures、分页重入/取消、JWT 到期和无效 user token 回游客、三站列表/详情/媒体请求。真机覆盖布局、焦点、搜索实际提交、两源静音播放与停止、播放结束、阅读跳页/续读/方向。真实账号的登录流程和有声输出靠手动确认。

目前没有做：播放续播、搜索历史、正式 searchScopes、关注、排行榜、文件大小和额外评论详情。
