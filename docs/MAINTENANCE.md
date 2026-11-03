# Independent SwiftPM maintenance

- Fork: https://github.com/KahnLi-lyc/FSPagerView
- Active maintenance and default branch: `master`.
- Upstream: https://github.com/WenchaoD/FSPagerView
- Exact base: `f90ab7d2ee6847823708a0a4e11e87c3ee4e6e48` (upstream `master`, 2025-01-02).
  The last upstream tag, `0.8.3` (`13669bf`), ships no `Package.swift`; its Swift
  sources differ from the base only by two lines in `FSPageViewTransformer.swift`.
- Original MIT license, author notices, public API, source directory, examples,
  and Git history are preserved. No upstream tag is moved or replaced.

## Distribution

SwiftPM only. Swift tools 6.0, Swift 6 language mode, iOS 16. The Objective-C
compatibility header (`FSPagerViewObjcCompat.h/.m`), the podspec, the Carthage
project under `FSPagerView/`, and both example apps stay in the repository
unchanged for reference, but they are not maintained or verified. The manifest
excludes the Objective-C files, as upstream did.

## Patches

See [Swift 6 migration](SWIFT6_MIGRATION.md) for every behavior-visible change.
In short: UI protocols and the transformer are main-actor isolated, the
automatic-sliding timer no longer retains the pager, the cell's font KVO uses an
observation token, and the package ships a privacy manifest.

## Verify

Use Xcode and a dedicated booted iOS Simulator (no CocoaPods or app checkout):

```sh
scripts/test-ios.sh <simulator-uuid> <derived-data> -- SWIFT_STRICT_CONCURRENCY=complete
scripts/check-consumer.sh <fresh-output-directory>
scripts/check-concurrency-diagnostics.sh <build-log> [...]
```

Create the dedicated Simulator yourself (`xcrun simctl create FSPagerView-Tests …`)
and boot it before testing; the scripts never pick or boot a device. The package
regressions include collapsing the pager to zero width, height, or size and
expanding it again without losing `currentIndex`.

The package workspace under `.swiftpm` is selected explicitly because the
upstream `FSPagerViewExamples.xcworkspace` and `FSPagerView.xcodeproj` also
define an `FSPagerView` scheme without the package tests. Animated scrolling does
not render frames in an unhosted XCTest bundle, so the visible automatic advance
and transformer rendering are checked in a Simulator host app; see
[validation](VALIDATION.md).

## Branch maintenance

`master` is the active default branch. Work on `feature/*` or `fix/*`, run the
package regressions, and merge into `master` before updating consumers.
See [branching](BRANCHING.md) and the [upstream review ledger](UPSTREAM_REVIEW.md).
