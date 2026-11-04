# Swift 6 维护验收（2026-11-02）

- 环境：Xcode 27.2 (27B52)，Apple Swift 6.4.2，专用 Simulator `FSPagerView-Tests`
  （iPhone 18 Pro / iOS 27.2，`236F0F96-0862-45A3-AAE6-B1C11B0B475F`）。
- 发布要求：Swift tools 6.0、Swift 6 语言模式、最低 iOS 16。
- 基线：upstream `f90ab7d`。只把 manifest 改为 Swift 6 后直接编译（`SWIFT_STRICT_CONCURRENCY=complete`）：
  1 个错误（`FSPagerViewCell` 非隔离 deinit 访问非 Sendable 的 KVO context），约 60 条并发警告，
  集中在 Transformer、LayoutAttributes、两个 deinit 和 `UIControl.State` 扩展。
  数字只描述该次编译输出，不是独立缺陷数量。

## 结果

- `scripts/test-ios.sh … SWIFT_STRICT_CONCURRENCY=complete`：17 项 XCTest，0 failures。
  覆盖有限／无限 section、单 item 去循环、空数据、`scrollToItem` 与 `currentIndex`、选择回调
  的逻辑下标、9 种 transformer × 横竖方向、transformer 默认值、LayoutAttributes 相等与拷贝、
  PageControl 指示器创建／颜色／透明度／单页隐藏、`UIControl.State` 字典键、Cell 字体变化重排，
  以及生命周期：定时器随窗口与拖拽启停、定时器在主 RunLoop 重复触发、未上屏 pager 不被定时器
  持有且释放后定时器自行失效、上屏后移除可释放、Cell 释放后 KVO 失效、PageControl 在待执行
  刷新前释放。
- 隐私清单由 bundle XCTest 实际读取通过。
- `scripts/check-consumer.sh`：Swift 5、Swift 6 两个公开接口宿主均构建成功。
- 并发诊断门禁（库测试日志、两个宿主日志、demo 日志）：0 条。

## Simulator 宿主 demo

无宿主 XCTest 中带动画的 `setContentOffset` 不出帧（已用诊断测试确认手动调用同样不移动），
因此可见的自动推进由临时 UIKit 宿主 App（Swift 6、complete 并发检查、本地 package 依赖）验证：

- 全宽无限轮播，`automaticSlidingInterval = 1.5`：index 0 → 2 → 绕回 1，PageControl 同步。
- `.coverFlow` 无限轮播：3D 透视正常，手势滑动后吸附到 item。
- 图片使用 Lorem Picsum 固定 id（1015/1016/1018/1036/1043），`imageView` aspectFill 正常。
- 宿主需按 iOS 27 要求采用 Scene 生命周期，否则 UIKit 在启动时主动终止进程；与本库无关。

## 折叠／展开回归（2026-11-03）

- 环境：Xcode 27.2 (27B52)，新建专用 Simulator `FSPagerView-Tests`
  （iPhone 18 Pro / iOS 27.2，`DBEB7006-8EE4-4FDA-BA2F-B4066A3CC861`）；11-02 的设备已不存在。
- 新增 `testCollapseAndExpandKeepsCurrentPage`：横／竖方向 × 有限／无限 × 折叠到零尺寸、零宽、零高，
  停在第 2 页后折叠再展开回 320×200，断言 collectionView 确实折叠、`currentIndex` 全程为 2、
  展开后 `scrollOffset` 为 2 且第 2 页 cell 可见。
- 原假设：滚动轴方向尺寸归零时自动 itemSize 使间距为 0，`currentIndex` 会被 NaN 重置为 0。
  在未修改的库代码上单独运行：12 组中 6 组确实进入零间距（`scrollOffset` 为 NaN），
  但 `currentIndex` 仍为 2，测试通过。折叠时的 bounds 调整没有经由 `scrollViewDidScroll` 改写 index，
  因此不修改库代码，该测试作为回归防护保留。
- `scripts/test-ios.sh … SWIFT_STRICT_CONCURRENCY=complete`：18 项 XCTest，0 failures。
- `scripts/check-consumer.sh`：Swift 5、Swift 6 宿主均构建成功。
- 并发诊断门禁（库测试日志、两个宿主日志）：0 条。
- 边界：滚动轴方向折叠期间 `scrollOffset` 为 NaN，不应读取；只验证同步改 frame 的折叠，
  未验证带动画的折叠、Auto Layout／UIStackView 宿主、真机和 iPad。

## Demo UI 自动化与多设备（2026-11-03）

- 设备（均为专用 Simulator，Xcode 27.2）：
  - iPhone `FSPagerView-Tests`（iPhone 18 Pro / iOS 27.2，`DBEB7006-8EE4-4FDA-BA2F-B4066A3CC861`）
  - iPad `FSPagerView-Tests-iPad`（iPad Pro 13-inch (M5) / iOS 27.2，`D64760F1-6F24-46F6-AFE6-6DDCB0BB80EF`）
  - iPhone Duo `FSPagerView-Tests-Duo`（iOS 27.2 机型专用运行时 `iOS-27-2-iPhone19-4`，`B609F8A9-FE88-4A3E-BD86-CBC748E71395`）
- 新增 `Fixtures/DemoApp`（UIKit 宿主，Swift 6 + complete 并发检查，iOS 16）和 `scripts/test-demo-ui.sh`。
  XCUITest 共 3 项：
  - 动画折叠／展开：Auto Layout 约束与 UIStackView `isHidden` × 宽／高 × 横／竖 × 有限／无限，共 16 种配置；
  - 横竖屏旋转；
  - 无障碍审计（`performAccessibilityAudit`）。
- 自动化发现并修复的 3 个库问题（每个都先写出失败的无宿主测试，修复后转绿）：
  1. 动画尺寸变化（旋转）：layout 原样采用 UIKit 提议的偏移，横屏落到别的页，转回竖屏偏 8pt。
     修复：覆写 `targetContentOffset(forProposedContentOffset:)`。
  2. 无动画尺寸变化（RocketSim 在 Duo 上切到最大无障碍字号时发现）：`UICollectionView.setFrame`
     按比例改写偏移，`currentIndex` 从 2 变成 3。修复：改 frame 期间不推算 index，尺寸变化后按原 index 重新居中。
  3. `textLabel` 不随 Dynamic Type 变化，打开后放大字号会被截断。修复：开启
     `adjustsFontForContentSizeCategory`，字号类别变化时 cell 重新布局。
- 结果（三台设备分别执行）：
  - `scripts/test-ios.sh … SWIFT_STRICT_CONCURRENCY=complete`：21 项 XCTest，0 failures；
  - `scripts/test-demo-ui.sh`：3 项 UI 测试，0 failures。
  另外 `scripts/check-consumer.sh` 两个宿主均构建成功；全部日志的并发诊断为 0 条。
- RocketSim 交互验收（iPhone Duo，开启 live preview）：翻到第 2 页 → UIStackView 宽度折叠／展开
  → 左转横屏再转回 → 最大无障碍字号再恢复。每步截图核对，Page 2 都居中、两侧不露邻页，
  index 保持为 2。截图保存在任务证据目录 `rocketsim/`。

## Swift 示例升级与只保留 SwiftPM（2026-11-03）

- 删除 Objective-C 示例、Objective-C 兼容层、Carthage 工程和 podspec；`Package.swift` 去掉对应的 exclude。
- `FSPageViewExample-Swift` 改用 XcodeGen 生成：Swift 6、complete 并发检查、iOS 16、Scene 生命周期，
  通过本地 package 依赖本库，不带签名团队。`FSPagerViewExamples.xcworkspace` 包含它和 `Fixtures/DemoApp`。
  三个示例 VC 只加了 `import FSPagerView` 就通过了 Swift 6 编译。
- 新增 `scripts/test-swift-example.sh`，从 workspace 构建（与在 Xcode 里打开 workspace 运行的路径一致）。
  UI 冒烟测试会每次重新启动 App，依次进入三个示例并滑动轮播。这里不点返回按钮，因为 iPhone Duo 把返回按钮
  画在右侧传感器条里，导航栏中找不到它。
- 结果（iPhone、iPad、iPhone Duo 三台专用 Simulator 分别执行）：
  - `test-ios.sh`：21 项，0 failures；
  - `test-demo-ui.sh`：3 项，0 failures；
  - `test-swift-example.sh`：1 项，0 failures。
  另外 `check-consumer.sh` 两个宿主均构建成功，全部日志并发诊断 0 条。
  iPad 上 XCUITest 每一步都要等满 60 秒才能确认 SpringBoard 空闲，所以耗时明显更长，不影响结果。
- RocketSim 在 iPhone Duo 上走查（用独立的 live preview，与其他任务并行）：
  - Banner：图片铺满，滑动和自动轮播正常；
  - Transformer：linear、ferris wheel 两种效果的相邻页排布正确；
  - PageControl：滑到第 2 页后指示点同步，横屏下仍停在第 2 页且对齐。
  截图保存在任务证据目录 `rocketsim/`。

## 边界

- 未验证最低 Swift 6.0 编译器、iOS 16 运行时和真机（已连接的 iPhone 12 Pro Max 留待后续）。
- VoiceOver 只做了自动化无障碍审计和无障碍树检查；XCUITest 不能开启 VoiceOver，也不能模拟它的手势，
  未做朗读与手势实测。`FSPageControl` 的指示点不是无障碍元素，审计没有标记，按现状保留。
- iPhone Duo 的机身折叠／展开姿态没有覆盖：`simctl` 与 RocketSim 都没有切换入口，只能在
  Simulator 图形界面里切换。
- Demo 在最大无障碍字号下按钮会换行、轮播被挤窄，这是 Demo 布局本身的样子，用来测试窄宽度，不是库的问题。
- Xcode test sysroot 诊断（`-Wincompatible-sysroot`）为工具链提示，独立记录。
- 托管 GitHub Actions 配置已加入；本地验证不代表远端 runner 已执行成功。
- 本轮没有接入任何消费者（club-circle-ios 另起任务）。
