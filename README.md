# inHebi

![inHebi](inHebi/Assets.xcassets/InHebiBrand.brandassets/Top%20Shelf%20Image%20Wide.imageset/top-shelf-wide@1x.png)

在 Apple TV 上用遥控器浏览 iwara、Hanime1 的视频和 wnacg 的漫画的原生 tvOS 应用。观看历史、阅读进度和收藏通过 iCloud 同步。

这是个人自用项目，与上述站点无关，也不会上架 App Store。需要自己用 Xcode 签名后装到 Apple TV 上。

> 三个站点的内容主要面向成年人，请确认你所在地区的法律允许访问。

## 功能

- **iwara**：按排序（趋势、最新、热门、播放、喜欢）和分级（全部、一般、成人）浏览，支持搜索。可选登录账号，不登录以游客身份浏览。
- **Hanime1**：按分类和排序浏览，支持搜索，详情页有同作者和相关视频。
- **wnacg 漫画**：按最新和全部分类浏览，支持搜索。阅读器支持单页和双页、缩略图跳页、可切换翻页方向。
- **播放**：使用系统播放器 AVKit，自动选最高清晰度。
- **详情页**：显示作者、标签、日期、时长等信息，作者和标签可以点进去看相关内容。
- **我的**：观看历史和多个收藏夹，按来源分区，可以从历史接着看或续读。
- **iCloud 同步**：历史、阅读页码和收藏夹存在你自己的 iCloud 私有数据库里。

应用没有后端，不下载、不缓存视频或漫画图片，所有内容都直接从站点实时请求。

## 系统要求

- Apple TV，tvOS 18 或更高版本。
- 一台装有 Xcode 的 Mac。项目用 Xcode 27 开发，工程按 Xcode 27 生成。
- 一个 Apple Developer Program 付费账号。应用用到了 iCloud（CloudKit）和推送能力，免费的个人开发团队签不了这些能力。

## 构建与安装

### 1. 换成你自己的标识

工程里的签名团队、bundle ID 和 iCloud 容器都是作者的，需要换成你自己的才能签名。这些配置集中在工程生成脚本里，改完重新生成工程：

1. 在 `script/generate-project.py` 里修改：
   - `DEVELOPMENT_TEAM`：换成你的团队 ID，App 和 UI 测试两个 target 各有一处。
   - `PRODUCT_BUNDLE_IDENTIFIER`：例如改成 `com.example.inhebi` 和 `com.example.inhebi.uitests`。
   - `icloud-container-identifiers`：改成 `iCloud.` 加你的 bundle ID。
2. 把 `Packages/InHebiCore/Sources/InHebiCore/LibraryStore.swift` 里的 `cloudContainer` 改成同一个 iCloud 容器 ID。
3. 在仓库根目录重新生成工程和 entitlements：

   ```sh
   python3 script/generate-project.py
   ```

也可以直接在 Xcode 的 Signing & Capabilities 里改团队和 bundle ID。注意以后再运行生成脚本会覆盖这些修改。

### 2. 配对 Apple TV

1. Apple TV 和 Mac 连到同一个局域网。
2. 在 Apple TV 上打开“设置 → 遥控器与设备 → 遥控 App 与设备”，进入配对界面。
3. 在 Xcode 里打开 Device Hub（Xcode → Open Developer Tool → Device Hub，或运行目标菜单里的 Manage Devices），添加这台 Apple TV，输入电视上显示的配对码。

Apple 的说明：[运行到设备](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[配对设备](https://developer.apple.com/documentation/xcode/pairing-your-devices-with-your-mac)。

### 3. 构建并安装

在 Xcode 的 Settings → Apple Accounts 里登录你的开发者账号，然后任选一种方式：

- **用 Xcode**：打开 `inHebi.xcodeproj`，选择 **inHebi** scheme，运行目标选这台 Apple TV，点 Run。Xcode 会自动注册设备、生成 provisioning profile 并开通 iCloud 容器。
- **用脚本**：传入 Apple TV 的设备标识。脚本使用 Xcode 登录的账号自动签名，构建后安装到电视上。

  ```sh
  ./script/install-device.sh <Apple TV 设备标识>
  ```

开发证书签出的应用有有效期，过期后重新构建安装一次即可。

## 使用

顶部标签栏有五页：iwara、Hanime1、漫画、我的、设置。

**浏览**

- 列表上方是筛选条，左侧是分类芯片，右侧固定排序（iwara 还有分级）和搜索按钮。
- 焦点在芯片上停留约 0.4 秒就会切换内容，不用按确认；快速划过不会触发请求。
- 列表滚到底部附近会自动加载下一页。
- 在列表里按 Menu 先回到筛选条，再按一次回到顶部标签栏。

**卡片和详情**

- 按 Select 进详情页，按播放/暂停键直接播放视频或打开漫画。
- 详情页里，星标短按切换默认收藏夹，长按可以选择或新建其他收藏夹。

**搜索**

- 点筛选条右端的放大镜进入搜索页，用系统键盘输入后按搜索键提交。Hanime1 会带上当前分类。

**阅读漫画**

- 默认按日漫习惯从右往左翻页，左键是下一页。翻页方向可以在设置里改。
- 按上键呼出缩略图条，可以跳页；按下键呼出底部按钮，可以切换单页和双页。同方向再按一次收起。
- 按 Menu 先收起面板，再按一次退出阅读器。
- 页码会记进历史，下次从详情页或“我的”页可以接着读。

**我的**

- 上方芯片在历史和各个收藏夹之间切换，内容按来源分区。
- 长按卡片可以从当前列表移除。右侧按钮可以清空历史，或重命名、删除当前收藏夹。

**设置**

- 登录 iwara 账号，切换漫画翻页方向，查看 iCloud 账号状态。

## iCloud 同步

- 同步的内容是观看历史、漫画阅读页码和收藏夹，用的是你自己 iCloud 账号的私有数据库，作者看不到。
- Apple TV 没登录 iCloud 时，数据只保存在本机。
- 排序和分级偏好、翻页方向、双页模式只保存在本机，不同步。
- iwara 账号只在本机钥匙串里保存登录凭证，不保存密码，也不同步。
- 用 Debug 配置构建（Xcode Run 和安装脚本都是）时连接的是 CloudKit 的开发环境，和 Release 构建的数据不互通。

## 已知限制

- 站点改版或接口变化会导致对应的源失效，需要更新解析代码。
- 视频没有续播，每次从头开始。
- iwara 不能播放外站嵌入的视频，iwara 详情页没有相关视频栏。
- 站点的视频和图片链接有时效。漫画读到一半链接过期时，返回详情页重新打开即可。
- 系统播放器的进度栏和信息面板不能用同一个方向键收起，只能按 Menu 逐层退出。这是 AVKit 公开接口的限制。
- 目前只有 tvOS 客户端。核心模块支持 iOS 和 macOS，但还没有对应的 App。

## 开发与测试

工程结构、测试命令、真机 UI 测试和调试方法见 [docs/development.md](docs/development.md)。站点接口和易变位置见 [docs/data-sources.md](docs/data-sources.md)，修复与验收记录见 [docs/changelog.md](docs/changelog.md)。

## 免责声明

本项目仅供个人学习和自用，是非官方客户端，与 iwara、Hanime1、wnacg 没有任何关联。所有内容都来自这些站点，版权归原作者和站点所有。应用不提供下载，也不保存任何内容。

第三方站点的页面结构和接口随时可能变化，应用可能随时无法使用。使用者需要自行遵守所在地区的法律和各站点的使用条款。
