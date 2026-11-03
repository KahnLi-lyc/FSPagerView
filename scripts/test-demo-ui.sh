#!/bin/bash
set -euo pipefail
# Supply a dedicated, booted Simulator UUID; this script never selects others.
SIMULATOR_ID="${1:?Usage: scripts/test-demo-ui.sh <dedicated-simulator-uuid> [derived-data-path] [--] [xcodebuild arguments...]}"
shift
DERIVED_DATA="${TMPDIR:-/tmp}/FSPagerView-Demo-DerivedData"
if [[ $# -gt 0 && "$1" != -* && "$1" != *=* ]]; then
  DERIVED_DATA="$1"
  shift
fi
if [[ "${1:-}" == -- ]]; then shift; fi
cd "$(dirname "$0")/../Fixtures/DemoApp"
# The generated project is committed; regenerate it with xcodegen after editing project.yml.
xcodebuild -project FSPagerViewDemo.xcodeproj -scheme FSPagerViewDemo \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -jobs "${XCODEBUILD_JOBS:-2}" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  "$@" test
