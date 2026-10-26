#!/bin/bash
# App Store screenshots: boots an iPhone 17 Pro Max and an iPad Pro 13" simulator, sets
# a clean status bar, and runs ScreenshotTests, taking each picture with
# `xcrun simctl io <device> screenshot` when the test asks (see ScreenshotTests.swift).
# Saves to screenshots/iphone/ and screenshots/ipad/ and checks the sizes.
# Usage: scripts/app-store-screenshots.sh [iphone|ipad]   (default: both)
set -euo pipefail
cd "$(dirname "$0")/.."

IPHONE=${IPHONE_UDID:-5CF3C145-BC49-46B4-8B3E-9B5C88478E02}   # iPhone 17 Pro Max, iOS 26.3
IPAD=${IPAD_UDID:-A9E34CBB-8A8E-44FD-B910-6BDB59E8C6CC}       # iPad Pro 13-inch (M5), iOS 26.3
DERIVED=${DERIVED_DATA:-/private/tmp/claude-501/tasquel-shots}

capture() {
    local name=$1 udid=$2 want=$3
    local out="screenshots/$name" signal
    signal=$(mktemp -d)
    mkdir -p "$out"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" override --time 9:41 --batteryLevel 100 --batteryState charged \
        --cellularBars 4 --wifiBars 3

    TEST_RUNNER_SHOT_DIR="$signal" xcodebuild -project Tasquel.xcodeproj -scheme Tasquel \
        -destination "id=$udid" -derivedDataPath "$DERIVED" -parallel-testing-enabled NO \
        -only-testing:TasquelUITests/ScreenshotTests test > "$signal/xcodebuild.log" 2>&1 &
    local test_pid=$!

    while kill -0 "$test_pid" 2>/dev/null; do
        if [[ -f "$signal/ready" ]]; then
            local shot
            shot=$(cat "$signal/ready")
            xcrun simctl io "$udid" screenshot --type=png "$out/$shot.png" >/dev/null 2>&1
            echo "  $name/$shot.png"
            rm "$signal/ready"
        fi
        sleep 0.2
    done
    if ! wait "$test_pid"; then
        grep -E "error:|failed" "$signal/xcodebuild.log" | head -20
        echo "ScreenshotTests failed on $name (log: $signal/xcodebuild.log)" >&2
        return 1
    fi

    for file in "$out"/*.png; do
        local size
        size="$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/ {print $2}' | paste -sd x -)"
        [[ "$size" == "$want" ]] && echo "  ok $size $(basename "$file")" \
            || { echo "  WRONG SIZE $size (want $want): $file" >&2; return 1; }
    done
}

which=${1:-both}
[[ $which == ipad ]] || capture iphone "$IPHONE" 1320x2868
[[ $which == iphone ]] || capture ipad "$IPAD" 2064x2752
