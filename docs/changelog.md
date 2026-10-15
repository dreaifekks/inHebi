# 修复与验收记录

按时间倒序记录带日期的修复、合并和真机验收。逐轮过程和失败后的定向修正见仓库根目录的 `progress.md`。

文中的 `artifacts/...` 是本地测试产物目录，已被 gitignore，不在仓库里。

## 2026-10-14 漫画历史显示修复（build 30）

用户报告的“漫画没有 history”已在真实 SwiftData + CloudKit 库复现。记录和页码实际已经保存：独立 ModelContext 和“我的”页查询均有 3 条漫画，但在两个视频分区之后的漫画 LazyVGrid 尚未创建屏幕外卡片，遥控器无法进入该分区。修复前 UI 查询只有 4 张视频卡片、0 张漫画卡片；修复后可导航到全部 3 张漫画卡片。

“我的”页的分区网格现在预先创建行和焦点卡片，保持四列/五列、卡片比例、来源分区和排序；网络浏览页仍使用 LazyVGrid。播放/暂停快捷键处理位于卡片长按菜单外层。所有漫画入口（详情开始/继续/预览页、列表快开、“我的”页快开）原本都通过 recordVisit 显式保存，视频共用 PlayerScreen 的保存入口；此次没有添加重复保存、修改模型或重置真实库。

新增两项核心测试验证混合视频/漫画记录在关闭磁盘容器后重开仍保留，以及定向清理测试条目不会删除其他历史/收藏。常规漫画历史 UI 用例通过 `--ui-mixed-history` 在独立内存库预置两个视频分区，覆盖此前遗漏的布局。真实库用例 `testPersistentComicDetailHistory` 和 `testPersistentComicQuickHistory` 只挑选库中不存在的条目；验证阅读、历史可达、从历史续读、重启后页码及 CloudKit 导出，结束后仅清理自己新增的条目并等待清理导出。用 `TEST_RUNNER_INHEBI_CLOUD_TEST=1` 显式运行，沿用 `--ui-cloud-library`；不清空用户历史或收藏。

本轮离线 42 通过 / 3 联网跳过，verify.sh generic tvOS 编译通过；最终受影响真机 7/7 通过。真实库清理后历史/漫画数量恢复原值，应用已退出。证据：`artifacts/comic-history-query-probe.log`（修复前）、`artifacts/comic-history-acceptance.log`、`artifacts/comic-history-final-focus.txt`、`artifacts/comic-history-final-verify.log`。正常签名安装回执为 `artifacts/comic-history-install.log`。

## 2026-10-14 合并验收

已合并阅读器/AVKit 分支 `97403c2` 与改名/iCloud 分支 `09f18c0`。本轮内部改名后，离线 40 项通过（3 项联网跳过）、联网 43 项全部通过、generic tvOS 编译通过；本机没有 tvOS 模拟器运行时。

真机常规 34 项全部取得通过结果：完整首轮 32 通过 / 2 失败；焦点日志显示网格焦点正确但 Menu 返回未执行，疑似普通网格卡片的空 contextMenu 偶发截获 Menu（合并前同样代码的另一轮完整测试里这两项通过，未确证）。限定只有收藏/历史可移除卡片创建菜单后，5 项定向回归全部通过。真实 CloudKit 专用验收另有 1/1 通过，新增和清理收藏均导出成功。日志为 `artifacts/full-device.log`、`artifacts/menu-fix-device.log`、`artifacts/final-cloudkit.log`；正常签名交付回执为 `artifacts/final-install.log`。

新增 `testReaderClosingBurstDoesNotReopen` 覆盖上下两个方向收起后的 100/300/600ms 连发及静默后重开；按钮行 Up 断言具体当前页 1、17、双页起始 23。`testMenuDismissesWhilePlayingBothSources` 不先暂停，在两源静音播放几秒后直接按 Menu 逐层退出，检查播放器消失、停止状态与停止时间稳定。自动化按键/时间注入不等同于 Siri Remote 指腹滑动。

## 2026-10-14 改名与 iCloud：真机验收

常规 29 项全部取得通过结果：首轮 23 通过 / 6 失败，修正原生 Select 长按、稀疏列表焦点分区、管理窗口关闭后的焦点恢复及测试定位/输入时序后，定向重跑补齐。主屏 inHebi 图标可见且可聚焦，旧应用保留。正常启动真实 SwiftData/CloudKit 容器成功。

真实 CloudKit 专用用例 1/1 通过，设置显示“已登录 iCloud”；新增收藏后取消，测试新建的空默认夹也已删除。清理后的日志：`2026-10-14T10:53:00.220 kind=code cloudkit kind=export completed=true success=true error=none`。证据在 `artifacts/inhebi-cloudkit-focus.txt`，这里只确认 Apple TV 的真实导入/导出，不代替未来 Mac/iOS 双端同步验收。

## 2026-10-14 Xcode 账号自动签名

清除三个 API 密钥环境变量后，Xcode 已登录账号自动 provisioning 成功。已核对签名产物和 profile 均包含 `com.dreaife.inhebi`、`iCloud.com.dreaife.inhebi`、CloudKit 和开发推送权限；无需手动创建或关联容器。旧 App Store Connect API 密钥方式同日返回 `Authentication failed`，暂不使用。

新应用全新安装，不迁移旧应用的数据或 Keychain。旧 `com.dreaife.shelf` 当时保留在电视上；新 iwara 登录由用户输入并确认。

## 2026-10-14 阅读器面板交互验收（合并前阅读器分支 build 18）

离线 28 通过 / 3 联网跳过，`verify.sh` generic 编译通过，10 个受影响真机用例最终通过。较后页覆盖第 17 页、双页起始第 23 页及从第 21 页续读后首次呼出；基线第 17 页测试没有复现“回到第一页”，因此修订采用显式可见性赋焦，并保留实体操作验证边界。真机测试记录及失败后定向修正过程见 `progress.md`。

## 2026-10-14 网格尺寸回调（build 17）

恢复整列宽及原始比例，保留 32pt 标题间距。离线 28 通过 / 3 联网跳过，`verify.sh` 和 generic 编译通过，受影响真机网格/焦点 5 项全部通过。两行分别聚焦检查，横版实测间隙约 20.75pt、Hanime1 竖版和漫画均 12pt；不以完整两行可见作为验收条件，阅读器保持不变。

## 2026-10-14 阅读器/卡片修订（build 16）

新增 3 项 ReaderLayout 测试后，离线 28 通过 / 3 联网跳过，联网 31 通过；generic 编译通过。受影响真机 8 项均取得通过结果（首轮 7/8，新按钮测试定位修正后 1/1），未重跑无关播放用例。只读取 UI 元素 frame，没有打开封面截图；测试结束已确认旧应用进程退出。正常签名安装版本 build 16。

## 2026-10-14 首版最终验收

核心离线及联网测试通过（联网 28 项），真机完整 19 项通过，加分类图标后筛选条相关 9 项重跑通过，generic tvOS 编译通过。39 张命名截图已逐张检查，筛选条末尾、返回和分类搜索截图在最后导出后再次复核。结果见 `progress.md`，截图在 `artifacts/screenshots/`。
