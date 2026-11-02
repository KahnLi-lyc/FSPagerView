# 上游变更审查记录

## 当前已采纳基线

- 官方仓库：https://github.com/WenchaoD/FSPagerView
- 已采纳官方基线：`f90ab7d2ee6847823708a0a4e11e87c3ee4e6e48`（upstream `master`，2025-01-02，
  “Merge pull request #379 from esikmalazman/swift-5”）。
- 最后一个官方 tag：`0.8.3` → `13669bf75af92b9528d62ac083c7d2d23814a703`。它没有 `Package.swift`；
  与基线相比，`Sources/` 只差 `FSPageViewTransformer.swift` 两行。

## 2026-11-02 首次收归维护

- fork 时 upstream 仅有 `master` 与 `develop` 两个分支；`develop` 停在 `0.8.3`，已被基线包含。
- 基线之后上游没有新提交；没有未采纳的上游修改。
- 自有修改见 [Swift 6 迁移指南](SWIFT6_MIGRATION.md) 与 [验收记录](VALIDATION.md)。

后续升级必须以本记录中的真实已采纳基线为起点审查差异，再在独立升级分支
选择性移植并回归；完成后在本文件追加已采纳补丁、验证结果与新基线。
