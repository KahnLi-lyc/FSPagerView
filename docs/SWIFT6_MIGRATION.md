# Swift 6 迁移指南

本次维护将 SPM 分发提升至 Swift tools 6.0、Swift 6 语言模式，最低系统 iOS 16。
模块与 product 名仍为 `FSPagerView`，公开类型、方法名、参数标签和默认值不变；
不承诺 ABI 兼容。Swift 5 模式宿主仍可用现代工具链接入，旧工具链不能解析新 manifest。

## 主线程约定

- `FSPagerViewDataSource`、`FSPagerViewDelegate` 显式 `@MainActor`。宿主的 `UIViewController`
  可直接遵循；独立 NSObject 数据源建议同样声明 `@MainActor`。
- `FSPagerViewTransformer` 显式 `@MainActor`，必须在主线程创建；子类覆写
  `applyTransform(to:)` / `proposedInteritemSpacing()` 继承该隔离。
- `FSPagerView`、`FSPagerViewCell`、`FSPageControl`、`FSPagerViewLayoutAttributes`
  继承 UIKit 的主 Actor 隔离。后台只产生数据，在 `await MainActor.run { ... }` 中
  更新并 `reloadData()`。
- `FSPagerViewLayoutAttributes.isEqual(_:)` 是 Foundation 的非隔离入口，内部以
  `MainActor.assumeIsolated` 比较 `position`；与 UIKit 一致，只能在主线程比较。
- 没有使用 `@unchecked Sendable`、`nonisolated(unsafe)` 或 `@preconcurrency` 绕过检查。

## 行为差异

| 位置 | 上游 | 本 fork |
| --- | --- | --- |
| 自动轮播定时器 | `target: self` 强持有 pager；未上屏但设置了间隔时 pager 无法释放 | block 定时器弱引用 pager；pager 释放后下一次触发自行 `invalidate`。上屏启动、离屏停止、拖拽暂停、`.common` 模式均不变 |
| `FSPagerView.deinit` | 在 deinit 中清空 collectionView 的 dataSource/delegate | 移除。iOS 16 上二者为 weak，且 Swift 6 不允许在非隔离 deinit 中访问 UIKit |
| `FSPagerViewCell` 字体 KVO | `addObserver` + context 指针 + 覆写 `observeValue` | `NSKeyValueObservation` token，随 cell 释放自动失效；不再覆写 `observeValue`（子类覆写仍可编译，`super` 落到 NSObject） |
| `FSPageControl` 延迟刷新 | `DispatchQueue.main.async` 强捕获 self | 弱捕获，控件先释放时不再执行 |
| `UIControl.State: Hashable` | 自定义 `hashValue` | `@retroactive Hashable`，`hash(into:)` 使用 `rawValue`。公开一致性保留，哈希值不同（不应持久化） |
| 隐私清单 | 无 | `PrivacyInfo.xcprivacy`（无追踪、无 Required Reason API） |

## 不再维护

Objective-C 兼容层、podspec、Carthage 工程和两个示例 App 原样保留，不维护、不验证。

## 验证

```sh
scripts/test-ios.sh <dedicated-simulator-uuid> <DerivedData> -- SWIFT_STRICT_CONCURRENCY=complete
scripts/check-consumer.sh <fresh-output-directory>
scripts/check-concurrency-diagnostics.sh <build-log> [...]
```

`Fixtures/Consumer` 用公开 import 构建独立的 Swift 5、Swift 6 宿主 target（数据源／代理、
Cell 与 Transformer 子类、PageControl、async 刷新），库本身保持 Swift 6。
不要全局覆盖 SWIFT_VERSION 来伪造宿主兼容测试。实际结果见 [VALIDATION.md](VALIDATION.md)。
