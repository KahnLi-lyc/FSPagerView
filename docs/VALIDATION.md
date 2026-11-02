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

## 边界

- 未验证最低 Swift 6.0 编译器、iOS 16 运行时、iPad／真机、旋转和 VoiceOver。
- Xcode test sysroot 诊断（`-Wincompatible-sysroot`）为工具链提示，独立记录。
- 托管 GitHub Actions 配置已加入；本地验证不代表远端 runner 已执行成功。
- 本轮没有接入任何消费者（club-circle-ios 另起任务）。
