# 主分支维护与上游升级

本库是独立维护、可用于不同项目的通用 UIKit 轮播库。

## 分支与远端

| 名称 | 职责 |
| --- | --- |
| `origin/master` | 自有 fork 的正式维护和默认分支 |
| `feature/*`、`fix/*` | 从当前 master 创建，完成验证后合并的任务分支 |
| `upstream/master` | 原作者仓库的远端跟踪分支，用于审查候选更新 |

`origin` 为 `https://github.com/KahnLi-lyc/FSPagerView.git`，
`upstream` 为 `https://github.com/WenchaoD/FSPagerView.git`。
日常检出本地 `master`，从它创建任务分支；验证后切回 master 并合并任务分支。
将自有 master 推送到 origin，不将任务修改直接推往 upstream。

## 日常修复

```sh
git switch master
git fetch origin master
git merge --ff-only origin/master
git switch -c fix/some-issue
# 完成当前任务后，在专用且已启动的 iOS Simulator 上验证。
scripts/test-ios.sh <专用Simulator-UUID> <DerivedData> -- SWIFT_STRICT_CONCURRENCY=complete
scripts/check-consumer.sh <新的输出目录>
git diff --check
git add <当前任务文件>
git commit -m "fix: 修复当前任务问题"
git switch master
git merge --no-ff fix/some-issue -m "merge: 合入已验证修复"
# 对合并后的 master 再执行相同回归。
scripts/test-ios.sh <专用Simulator-UUID> <DerivedData> -- SWIFT_STRICT_CONCURRENCY=complete
git push origin master
```

若 master 已前进，执行普通合并并重新验证；冲突时逐项审查，不能强推覆盖远端。
任务结束并确认提交已由 master 持有、无本地文件遗漏后，再删除自己的临时分支。
消费者固定完整 commit revision；master 前进不会自动升级已锁定的项目。

## 上游升级

```sh
git fetch upstream
git log --oneline <UPSTREAM_REVIEW.md 中的已采纳基线>..upstream/master
```

在独立 `feature/upstream-<日期>` 分支逐项审查、选择性移植并回归，完成后在
[上游审查记录](UPSTREAM_REVIEW.md) 追加已采纳补丁、验证结果与新基线。
部分移植不能记为整体升级到该上游 revision。
